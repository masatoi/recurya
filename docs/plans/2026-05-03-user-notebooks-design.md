# ユーザー作成ノートブック機能 設計

- 起票: 2026-05-03
- ブランチ: `feat/sicp-notebook-mvp`（現状）→ 新ブランチ `feat/user-notebooks` を切る想定
- ステータス: ブレスト承認済み、実装計画作成へ
- 関連: ブログ投稿機能 (`models/post.lisp`, `db/posts.lisp`, `web/ui/post-form.lisp`, `web/ui/posts.lisp`, `web/routes.lisp`)、SICPノートブック (`game/notebook.lisp`, `game/notebooks/*`, `web/ui/notebook.lisp`, `models/learn-progress.lisp` 他)

## 1. 背景と目的

現状、SICPノートブック（56個）はコンパイル時にハードコードされ、運営側のみが追加できる。学習者が「**自分で教材を組み立てて公開し、他のユーザーが学習できる**」状態を作るのが本機能のゴール。

ブログ投稿機能と同型の「draft / published」ライフサイクルを採用し、SICPと並ぶ独立した「公開ノートブック」セクションを追加する。

## 2. スコープ

### MVPに含む

1. 自分のノートブック管理 `/notebooks/me`
2. 新規・編集フォーム `/notebooks/new`, `/notebooks/:id/edit`
3. HTMXによる draft/published トグル `/notebooks/:id/toggle-status`
4. HTMX削除（確認モーダル付き）`/notebooks/:id/confirm-delete`, `/notebooks/:id/delete`
5. 公開一覧 `/notebooks`（ページネーション）
6. 公開単体 `/n/:slug`（既存のcell実行UIを再利用）
7. cell実行 `/n/:slug/run-cell`（学習進捗連動）
8. ヘッダーへのリンク追加
9. Markdownパース（3bmd）+ XSSサニタイズ
10. テスト一式（パーサ単体、DB CRUD、ハンドラ統合、進捗連動）

### MVPに含めない（次フェーズ）

- コメント、いいね、スター、ランキング
- 検索、タグ、カテゴリ
- 画像アップロード（外部URLのみ許可）
- 数式（KaTeX）対応
- 他人のNBをforkして自分版を作る機能
- リッチエディタ（HTMXでcellを動的に追加・並び替え）への移行
- TOC的な章/節構造（最初のNBは「単一画面の縦長ノート」想定）
- CSRFトークン（既存post系と挙動を揃え、別タスクで全体に追加する場合に同時対応）

## 3. アーキテクチャ概要

新規追加するモジュール（少数）:

```
新規:
  models/user-notebook.lisp           (deftable user_notebook)
  db/user-notebooks.lisp              (CRUD)
  game/notebook-parser.lisp           (Markdown ↔ cell配列の双方向変換)
  web/ui/user-notebook-form.lisp      (新規/編集フォーム)
  web/ui/user-notebooks.lisp          (自分のNB一覧)
  web/ui/notebook-list.lisp           (公開一覧)
  db/migrations/YYYYMMDD-user-notebooks.{up,down}.sql

修正:
  recurya.asd                         (新モジュール登録、3bmd 依存追加)
  qlfile / qlfile.lock                (3bmd 追加)
  web/routes.lisp                     (新ハンドラ + ルート登録)
  web/ui/layout.lisp                  (ヘッダーに "Notebooks" リンク)
  web/ui/notebook.lisp                (render に :sidebar-notebooks 引数追加、デフォは現挙動)
  game/notebook.lisp                  (notebook/cell の id 型を (or null keyword string) に緩和)
  db/schema.sql                       (Mito CLIで自動更新)

再利用 (修正なし):
  web/ui/notebook.lisp                cell実行UI・HTMXフラグメント生成
  game/notebook.lisp の run-cell       cell実行ロジック
  models/learn-{progress,cell-code,submission}  学習進捗テーブル
  web/ui/post-form.lisp                CSS/構造の参考
```

ポイント:

- **cell実行ロジックは1行も書き換えない**: `run-cell` は notebook + cell-index + codes列を受け取る純関数。SICP NBか公開NBかに依存しない
- **学習進捗テーブルもそのまま**: `learn_progress.notebook_id` は `VARCHAR(64)`、UUID文字列が入れば良い
- **post→user-notebookへの差分**: post.body→`title`+`summary`+`body_md`(Markdown)+`cells`(JSONB)、それ以外（slug/status/owner/draft/published/timestamps）は完全に同型

## 4. データモデル

### `user_notebook` テーブル

| カラム | 型 | 制約 | 備考 |
|---|---|---|---|
| `id` | UUID | PK | アプリ生成、`learn_progress.notebook_id`にもこのUUID（文字列化）が入る |
| `slug` | VARCHAR(255) | UNIQUE NOT NULL | 公開URL `/n/:slug`、自動生成 or 手動 |
| `title` | VARCHAR(255) | NOT NULL | NBタイトル |
| `summary` | VARCHAR(500) | NULL可 | 一覧カード用要約 |
| `body_md` | TEXT | NOT NULL | 編集の正本（区切り記号付きMarkdown） |
| `cells` | JSONB | NOT NULL | `body_md`をパースしたcell配列。各cellに永続UUIDの`cell_id`付与 |
| `status` | VARCHAR(32) | NOT NULL DEFAULT 'draft' | `draft` / `published` |
| `published_at` | TIMESTAMPTZ | NULL可 | publish時にセット |
| `author_id` | UUID | NOT NULL FK→users.id | 削除はusersのCASCADE方針に追従 |
| `created_at` | TIMESTAMPTZ | | Mito標準 |
| `updated_at` | TIMESTAMPTZ | | Mito標準 |

インデックス:
- `UNIQUE(slug)`
- `(status, created_at DESC)` 公開一覧
- `(author_id, created_at DESC)` 自分のNB一覧

### `cells` JSONB の形

```json
[
  {"cell_id": "0192f4b0-...", "kind": "prose",        "body_md": "Lispプログラムは…"},
  {"cell_id": "0192f4b1-...", "kind": "code-eval",     "body": "(+ 137 349)"},
  {"cell_id": "0192f4b2-...", "kind": "code-exercise", "description": "三項の和", "body": "; ここに",
   "test_cases": [{"input": "", "expected": "508", "description": "三項の和"}]}
]
```

- `cell_id` は新規セルへ採番、既存セルは保持
- 編集サイクル: DBの`body_md`をフォームに表示 → ユーザー編集 → サーバでパース → 既存`cells`の`cell_id`を「(kind, body, description)の三つ組一致」で引き継ぎ → 新規cellにUUID採番 → JSONB更新

### ID型の緩和

`game/notebook.lisp` の `defstruct`:

```lisp
(defstruct notebook
  (id nil :type (or null keyword string))   ; ← keyword から拡張
  ...)
(defstruct cell
  (id nil :type (or null keyword string))   ; ← keyword から拡張
  ...)
```

SICP既存ファイルは `:sicp-1-1-1` のキーワードを渡しているので影響なし。ユーザー作成NBは `"<uuid>"` 文字列を渡す。`run-cell` は最終的に `learn_*` テーブルへのキーを文字列化するため、両対応。

## 5. パーサ仕様

### 区切り記号フォーマット

```
===prose===
Lispプログラムは **式** を書いて評価することで動きます。

===eval===
(+ 137 349)

===eval===
(- 1000 334)
(* 5 99)

===exercise: 三項の和===
; ここに式を書く

===expect: 三項の和===
508

===exercise: ゼロ判定===
(define (zero? x) ???)

===expect===
input: (zero? 0)
output: t

===expect===
input: (zero? 5)
output: nil
```

規則:

- ヘッダ3種: `===prose===` / `===eval===` / `===exercise: <description>===`
- `===expect[: <description>]===` は直前のexerciseに紐づく
  - 本文に `input: ...` / `output: ...` の対があれば test-case の入力・期待値
  - 行が1行だけなら inputは空、その行をexpectedとする省略形
- 区切り行と区切り行のあいだの本文がそのcellのbody（先頭末尾の空行はトリム）
- title / summary はフォームの別フィールドで取る（フロントマターは使わない）

### `body-md` → `cells` パーサ

```
parse-notebook-body (body-md existing-cells) → (values cells errors)
```

- 状態機械: トップレベル → ヘッダ行検出 → セクション収集 → cell構築
- 既存cell引き継ぎ: `(kind, body, description)`の三つ組で `existing-cells` を順に走査し、一致すれば`cell_id`再利用。残りは新規UUID
- バリデーションエラー: 行番号付きで `errors` に収集
  - `===expect===` がexerciseに先行
  - `===exercise===` の description 欠落
  - 不明ヘッダ
  - 1セルもない

### 逆方向 `cells->body-md`

- 各cellをヘッダ＋本文で出力
- exerciseは `description` をヘッダに、test-cases を `===expect===` 連で書く
- 編集フォーム表示時に使用（DBの`body_md`をそのまま表示でもよいが、保存時に正規化済みbody_mdを保存することで往復一致を保証）

### 往復不変条件

`(parse → cells->body-md → parse)` が固定点に収束する。プロパティテストで検証。

### proseのMarkdown→HTML

- 3bmd でMarkdown→HTMLに変換
- HTMLサニタイズ（§7参照）後に `(:raw ...)` で埋め込む

## 6. ルーティング

| メソッド | パス | ハンドラ | 認可 |
|---|---|---|---|
| GET | `/notebooks/me` | `user-notebooks-handler` | 要ログイン |
| GET | `/notebooks/new` | `user-notebook-new-handler` | 要ログイン |
| POST | `/notebooks` | `user-notebook-create-handler` | 要ログイン |
| GET | `/notebooks/:id/edit` | `user-notebook-edit-handler` | owner |
| POST | `/notebooks/:id` | `user-notebook-update-handler` | owner |
| POST | `/notebooks/:id/toggle-status` | `user-notebook-toggle-status-handler` | owner |
| GET | `/notebooks/:id/confirm-delete` | `user-notebook-confirm-delete-handler` | owner |
| POST | `/notebooks/:id/delete` | `user-notebook-delete-handler` | owner |
| GET | `/notebooks` | `notebook-list-handler` | 公開 |
| GET | `/n/:slug` | `public-notebook-handler` | 公開（draftは404、ownerのみ200） |
| POST | `/n/:slug/run-cell` | `public-notebook-run-cell-handler` | 公開（保存はログイン時のみ） |

ルートIDはUUID文字列のみ（`me`/`new` のような英単語IDとの衝突を構造的に回避）。

## 7. 認可・バリデーション・XSSサニタイズ

### 認可マトリクス（要点）

- 公開ページは未ログインでも閲覧可
- draft の `/n/:slug` は **owner以外は404**（存在を漏らさない）
- 編集系は owner 以外は **403**
- post の `post-author-id` 比較ロジックを流用

### サーバ側バリデーション

| フィールド | ルール |
|---|---|
| `title` | 必須、1〜255文字 |
| `slug` | 任意、空ならtitleから`slugify`、`^[a-z0-9][a-z0-9-]{0,254}$`、UNIQUE違反時は明示エラー |
| `summary` | 任意、max 500文字 |
| `body` | 必須、パース可能、最低1cell以上 |
| `status` | `draft` または `published` のみ |

`body` は保存前にパースを実行し、エラーが1件でもあれば400 + フォーム再表示（行番号付き）。

### XSSサニタイズ — proseのMarkdown→HTML

ホワイトリスト方式:
- 許可タグ: `p`, `strong`, `em`, `code`, `pre`, `a`, `ul`, `ol`, `li`, `blockquote`, `h1`〜`h6`, `br`, `hr`, `img`
- 許可属性: `a@href`（`http(s):`/相対のみ、`javascript:`は拒否）、`img@src`/`@alt`（`http(s):`のみ）、`@class`（許可リストのみ）
- それ以外のタグ・属性は除去
- 実装: Plump（HTMLパーサ）+ ホワイトリスト走査で 50〜100行程度
- 生HTML埋込み（3bmdが許す raw HTML）は全面拒否（タグ単位で剥がされる）

### コード実行の安全性

cell実行は WardLisp サンドボックス（fuel/cons/depth/output/timeout 制限）を通る既存経路。追加対策不要。

### CSRF

既存post系と挙動を揃え、本MVPでは導入しない。

## 8. UIコンポーネント

### 一覧 `/notebooks/me`

`web/ui/posts.lisp` をベースに翻案。`+ New Notebook`、テーブル列 (Title / Status pill / Published / Created / Actions)、HTMX削除モーダル、ステータスpillトグル。

### 一覧 `/notebooks`

`web/ui/blog.lisp` 相当の公開カード一覧。title / summary / 著者名 / 公開日 / 「学習する →」リンク。ページネーション5件/ページ。

### 編集フォーム

`web/ui/post-form.lisp` をベースに翻案。フィールド: Title / Slug / Summary / Body (textarea, min-height 600px, 等幅, 折り返し有効) / Status。区切り記号チートシートをフォーム下部に表示。バリデーションエラーは行番号付きで上部に表示。

### 公開単体 `/n/:slug`

既存 `recurya/web/ui/notebook:render` を再利用。`render` 関数に `:sidebar-notebooks` keyword引数を追加し、`nil`ならサイドバーを描画しない（公開NB単体ページではnilを渡す）。SICP既存呼び出しは現状の挙動を維持（all-notebooks をデフォルトで使う）。

### cell実行エンドポイント

既存SICPのJSON/HTMX応答形式 (`recurya/web/ui/notebook:render-cell-result`) と同型。違いは notebook を SICP registry ではなく `user_notebook` テーブルから引くだけ。

## 9. テスト戦略

### 単体テスト（DB不要）

`tests/game/notebook-parser.lisp`:
- 正常系: prose / eval / exercise / 複数cell / 連続expect
- バリデーション: expect先行 / 不明ヘッダ / description欠落 / 0セル
- cell引き継ぎ: 三つ組一致での `cell_id` 再利用、新規UUID採番
- 逆方向 `cells->body-md`
- 往復不変条件（property test相当）
- proseの Markdown→HTML サニタイズ: `<script>` `onclick=` `javascript:href` `<iframe>` が剥がされる

### DBテスト

`tests/db/user-notebooks.lisp`:
- CRUD全操作
- 部分更新（cells JSONB含む）
- フィルタ（status / author-id / pagination）
- count
- slugify post と同等挙動

### 統合テスト

`tests/web/user-notebook-routes.lisp`:
- 認可マトリクス全網羅
- draft `/n/:slug` が他人には404、ownerには200
- ステータストグルで `published_at` セット
- 削除モーダル断片
- バリデーションエラー時のフォーム再表示
- パーサエラーの行番号表示

### 進捗連動テスト

`tests/web/user-notebook-learn.lisp`:
- 公開NBでcellを実行 → `learn_cell_code` 保存
- exercise成功 → `learn_progress` 保存
- ログアウト時は実行のみ、保存スキップ
- NB所有者がcell IDを安定させた状態で編集 → 学習者の保存コードが残る
- cellを並び替え → cell_id追跡で進捗が壊れない

### 既存回帰

- SICP NB既存56テスト全パス
- post関連テスト影響なし
- auth/oauthテスト影響なし

### JSONB往復

Mitoの`(:col-type :jsonb)` + `recurya/db/jsonb` を経由した list of plist と PostgreSQL JSONB 配列の往復一致。

## 10. 実装順序の提案

writing-plansスキルで詳細化するが、目安:

1. **基礎レイヤ**: 3bmd依存追加 → サニタイザ → パーサ単体（テストファースト）
2. **モデル/DB**: `user_notebook` deftable / migration / db-CRUD / DBテスト
3. **id型の緩和**: `game/notebook.lisp` defstruct 緩和、SICPテスト全パス確認
4. **管理UI**: フォーム / 一覧 / ハンドラ（new, create, edit, update）→ 統合テスト
5. **HTMX**: toggle-status / confirm-delete / delete
6. **公開UI**: `/notebooks` 一覧、`/n/:slug` 単体、`render`への`:sidebar-notebooks`引数追加
7. **進捗連動**: `/n/:slug/run-cell` ハンドラ → 既存`learn_*` への保存確認
8. **ヘッダー**: layoutのリンク追加
9. **総合確認**: 既存テスト全パス、ブラウザでの一連のフロー手動確認

## 11. 未解決・将来検討

- サニタイザ実装の正確性は別途レビュー（XSS対策は厚めに）
- `user_notebook` 削除時の関連 `learn_*` の扱い: 現MVPでは「削除されたNBへの過去進捗は残置」（FKなし、参照不能になるだけ）。将来: cleanup ジョブを別タスクで
- スパム対策（無限ノートブック作成）: 現MVPは無し。将来: 1ユーザー上限を環境変数で
- 検索・タグ・コメントは MVP 後の別タスク
- リッチエディタへの移行は、JSONB cells 構造化保存により後でも可能
