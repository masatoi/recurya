# コース機能と SICP の Notebook 化 設計

- 起票: 2026-05-03
- ブランチ: `feat/courses-and-sicp-migration`（新規）
- ステータス: ブレスト承認済み、実装計画作成へ
- 関連:
  - 直前の機能 [`docs/plans/2026-05-03-user-notebooks-design.md`](./2026-05-03-user-notebooks-design.md) — `user_notebook` テーブルとパーサ
  - SICP 既存実装: `game/notebooks/*`, `game/notebook.lisp`, `web/routes-wardlisp.lisp`, `web/ui/learn-home.lisp`

## 1. 背景と目的

現状ふたつの並行系統がある:

| 系統 | コンテンツ | 編集方法 | データ層 |
|------|------------|----------|----------|
| SICP | 56 ノートブック (defstruct) | コンパイル時に Lisp で記述 | なし（ハードコード） |
| ユーザー Notebook | 任意（user_notebook） | Web フォームから markdown | DB (PostgreSQL JSONB) |

これを **単一の Notebook 抽象**に統合し、さらに「Notebook をまとめて学習コースとして公開する」エンティティ `course` を追加する。

ゴール:
1. 学習者の継続率を上げる: コースは「次に何をやるか」と「全体の進捗（X/Y）」を可視化する基本単位
2. SICP も「コミュニティが改善できる教材」になる（ブランチ運営からコンテンツ運営へ）
3. 設計のクリーンアップ: 二系統に伴う分岐コード（`%coerce-notebook-id` / `(or null keyword string)` の id 型 / breadcrumb・sidebar 専用ハック / `web/routes-wardlisp.lisp` の SICP 専用ハンドラ群）を全て削除

## 2. スコープ

### このフェーズに含む

1. **`===solution===` セル種別**を notebook-parser に追加（公開ビューでは hide、grading 回帰テストで使用）
2. **`course` テーブル**と `course_notebook` 結合（m:n、position 付き）
3. **Course CRUD ハンドラ + UI**: `/courses` 公開一覧、`/c/:slug` コース単体、`/courses/me` 管理、フォーム
4. **Notebook viewer のコース連動**: コースから入った時の prev/next ナビ、サイドバーをコースの Notebook リストに
5. **SICP 56 本を user_notebook 行に移行**するスクリプト
6. **既存 SICP テストを新形式に書き換え**（structure テスト + canonical-answer grading テスト）
7. **`web/routes-wardlisp.lisp` の SICP 専用ルート削除**（`/wardlisp/learn/...` → `/c/sicp` と `/n/:slug` への 301 redirect）
8. **学習進捗 (`learn_*` テーブル) の notebook_id マイグレーション**（旧 `"sicp-1-1-1"` → 新 UUID 文字列）

### このフェーズに含めない

- Notebook fork / change-request（PR 機能。次フェーズ）
- コース内の section（中間階層）。タイトル接頭辞ベースで UI が折りたたむのみ
- ドラッグ&ドロップによるコース内 Notebook 並び替え（最初は前後ボタンで position 移動）
- コースのレーティング・コメント
- コース内 Notebook の依存関係（前提条件チェーン）

## 3. データモデル

### 3.1 新規テーブル

```sql
CREATE TABLE course (
  id           UUID PRIMARY KEY,
  slug         VARCHAR(255) NOT NULL UNIQUE,
  title        VARCHAR(255) NOT NULL,
  summary      VARCHAR(500),
  status       VARCHAR(32)  NOT NULL DEFAULT 'draft',
  published_at TIMESTAMPTZ,
  author_id    UUID NOT NULL REFERENCES users(id),
  created_at   TIMESTAMPTZ,
  updated_at   TIMESTAMPTZ
);
CREATE INDEX  ON course (status, created_at);
CREATE INDEX  ON course (author_id, created_at);

CREATE TABLE course_notebook (
  id          BIGSERIAL PRIMARY KEY,
  course_id   UUID NOT NULL REFERENCES course(id)         ON DELETE CASCADE,
  notebook_id UUID NOT NULL REFERENCES user_notebook(id)  ON DELETE CASCADE,
  position    INTEGER NOT NULL,
  UNIQUE(course_id, notebook_id)
);
CREATE INDEX ON course_notebook (course_id, position);
```

`course_notebook` の position は course 内ユニークではない（並び替え時の一時状態を許容）が、表示時に order by position する。 m:n を採用する理由: 教材 Notebook が複数コースで共有されるユースケース（例: 「Lisp 入門」と「SICP」両方に同じ pair 操作の Notebook が含まれる）に対応。

### 3.2 user_notebook の変更（互換性のため最小）

カラム追加なし。`chapter` フィールドは元々無いので何も変えない。`status` の意味も同じ。

### 3.3 cell の新種別: `:code-solution`

JSONB cells の `kind` フィールドの取り得る値が増える:

| kind          | 説明                                       | 公開ビュー  | grading への参加 |
|---------------|--------------------------------------------|-------------|------------------|
| `:prose`      | 説明文（markdown）                         | 表示         | 無              |
| `:code-eval`  | 評価結果を見せるコード                     | 実行可        | 無              |
| `:code-exercise` | 学習者が穴埋めするコード（`???` 入り）    | 実行可        | 有              |
| `:code-solution` | 教師側の正解コード（**新規**）            | **hide**     | 回帰テストのみ   |

cell の `description` フィールドで exercise / expect / solution の3つを紐付ける。同じ `description` の組が一塊。

## 4. パーサ拡張 (`game/notebook-parser.lisp`)

新ヘッダ `===solution: <description>===` を追加。`parse-fence-header` が `:code-solution` kind を返し、その body は次のヘッダまでの行を結合した文字列。

例:
```
===exercise: my-square===
(define (my-square x) ???)

===expect===
input: (my-square 3)
output: 9

===solution: my-square===
(define (my-square x) (* x x))
```

`cells->body-md` の逆変換も対応。

cell-id の安定化（既存の `take-matching-cell-id`）は kind ごとに独立して動作する。description が一致する exercise/expect/solution の組は、それぞれ別の cell として独立した id を持つ（紐付けは description 文字列のみ）。

## 5. ルート / UI

### 5.1 新ルート

| メソッド | パス                         | ハンドラ                              |
|----------|------------------------------|---------------------------------------|
| GET      | `/courses`                   | 公開一覧（published のみ）            |
| GET      | `/c/:slug`                   | コース単体（メタ + Notebook リスト）  |
| GET      | `/courses/me`                | 自分のコース管理（admin）             |
| GET      | `/courses/new`               | 新規フォーム                          |
| POST     | `/courses`                   | 作成                                  |
| GET      | `/courses/:id/edit`          | 編集フォーム                          |
| POST     | `/courses/:id`               | 更新（メタ）                          |
| POST     | `/courses/:id/notebooks`     | コースに Notebook を追加              |
| POST     | `/courses/:id/notebooks/:cn-id/up`   | position を 1 つ上に移動      |
| POST     | `/courses/:id/notebooks/:cn-id/down` | position を 1 つ下に移動      |
| POST     | `/courses/:id/notebooks/:cn-id/remove` | コースから外す（HTMX OOB swap）|
| POST     | `/courses/:id/toggle-status` | draft ⇄ published                     |
| GET      | `/courses/:id/confirm-delete`| 削除確認モーダル                      |
| POST     | `/courses/:id/delete`        | 削除                                  |

### 5.2 SICP 旧ルートの取り扱い（後方互換）

| 旧パス                       | 新パス                       | 方法           |
|------------------------------|------------------------------|----------------|
| `/wardlisp/learn`            | `/c/sicp`                    | 301 redirect   |
| `/wardlisp/learn/:id`        | `/n/:slug`                   | 301 redirect (id == slug) |
| `/wardlisp/learn/:id/cells/:i/run` | `/n/:slug/cells/:i/run` | 301 redirect (POST も) |
| `/wardlisp/learn/sync`       | `/learn/sync`                | 301 redirect。`learn-sync-handler` を `web/routes.lisp` に移植 |

301 redirect で1〜2リリース運用したのち削除する想定。

### 5.3 Notebook viewer のコース連動

`/n/:slug?course=<course-slug>` でコース文脈を渡すと:
- breadcrumb: `Notebooks > <Course Title> > <Notebook Title>`
- sidebar: そのコースの Notebook 一覧（位置順）
- 下部に prev / next リンク

`?course=` 無しでも単独表示可能（現状の挙動）。

`web/ui/notebook:render` の `:sidebar-notebooks` をコースの notebook リスト（position 順）で渡す。`:run-cell-base` も既存どおり `/n/<slug>` のまま。

### 5.4 新規 UI ファイル

```
web/ui/courses.lisp           — 自分のコース管理一覧
web/ui/course-form.lisp       — 新規 / 編集フォーム + Notebook 追加 UI
web/ui/course-list.lisp       — 公開一覧
web/ui/course.lisp            — コース単体ビュー（Notebook カード並び）
```

`web/ui/notebook-list.lisp`（既存）は user-notebook の公開一覧用。Course の公開一覧 `/courses` は別ファイルにして混乱を避ける。

### 5.5 削除されるファイル

- `web/ui/learn-home.lisp` （`/c/sicp` で代替）
- `game/notebooks/registry.lisp`
- `game/notebooks/sicp-1-1-1.lisp` 〜 `sicp-3-5-5.lisp`（56 ファイル）
- `web/routes-wardlisp.lisp` の SICP 専用ハンドラ群（`learn-home-handler`, `notebook-page-handler`, `notebook-cell-run-handler`, `%coerce-notebook-id`, `%maybe-persist-cell-run`）
- `web/ui/notebook.lisp` の `*chapter-titles*` / `*section-titles*` / `%chapter-prefix` / `%section-prefix` / `render-sidebar` のチャプター/セクション専用ロジック → 汎用 `render-course-sidebar` に置換

## 6. SICP 移行戦略

### 6.1 移行スクリプト `scripts/migrate-sicp-to-notebooks.lisp`

ロードして `(migrate-sicp!)` を呼ぶ one-shot スクリプト。実行内容:

1. 管理者 user を `(or (sb-ext:posix-getenv "ADMIN_OAUTH_EMAIL") "admin@example.com")` で取得
2. course "SICP" を作成（`slug "sicp"`、`status "published"`、author = admin）
3. 各 `(get-notebook :sicp-X-Y-Z)` から:
   - cells (defstruct cell list) を順に走査し markdown を組み立て
     - `:prose` body (Spinneret DSL) → markdown 文字列に変換（`spinneret-tree->markdown` ヘルパ）
     - `:code-eval` body → `===eval===\n<code>`
     - `:code-exercise` body + description + test-cases → `===exercise: <desc>===\n<code>\n\n===expect: <desc>===\n...`
     - 必要に応じて canonical-answer の `===solution: <desc>===` を**手動で追加**（後述）
   - `user_notebook` 行を作成（slug = 旧 ID 文字列 e.g. "sicp-1-1-1"、author = admin、status = published）
   - `course_notebook` 行で SICP コースに position 付き紐付け
4. `learn_*` テーブルの `notebook_id` を旧文字列 → 新 UUID 文字列に UPDATE

### 6.2 canonical-answer の出所

現状、SICP の正解コードは `tests/game/notebooks/sicp-X-Y-Z.lisp` の `(deftest sicp-X-Y-Z-foo-passes ...)` 内に `(let ((code "(define (...) ...)"))` の形で散在している。

移行時は手作業で:
1. 各 SICP テストファイルから canonical answer の文字列を抽出
2. 該当 exercise の直後に `===solution: <desc>===\n<answer>` として挿入
3. 移行後の Markdown を user_notebook.body_md に書き込む

これは 56 本 × 平均 2-3 exercise = ~150 箇所の手作業。スクリプトで半自動化は試みるが、最終チェックは人間。

### 6.3 Spinneret DSL → markdown 変換

簡易マッパー（移行スクリプト専用、汎用ライブラリにしない）:

| Spinneret DSL                | Markdown      |
|------------------------------|---------------|
| `(:p "...")`                 | `...\n`       |
| `(:strong "x")` / `(:b "x")` | `**x**`       |
| `(:em "x")` / `(:i "x")`     | `*x*`         |
| `(:code "x")`                | `` `x` ``     |
| `(:a :href "u" "x")`         | `[x](u)`      |
| `(:ul (:li "a") (:li "b"))`  | `- a\n- b\n`  |
| `(:ol ...)`                  | `1. ...`      |
| `(:h1 "x")` 〜 `(:h6 "x")`    | `# x` 〜      |
| `(:blockquote "x")`          | `> x`         |
| `(:img :src "u" :alt "a")`   | `![a](u)`     |
| その他                        | エラー → 手動修正 |

事前に SICP 56 本を grep して「その他」に該当する DSL 要素がどれだけあるかリスト化（オフライン作業として Phase 0 で実施）。

### 6.4 学習進捗のマイグレーション

`learn_cell_code`, `learn_progress`, `learn_submission` の `notebook_id VARCHAR(64)` には現在 `"sicp-1-1-1"` 等が入っている。SICP 移行で対応する `user_notebook.id` (UUID) を作ったあと、SQL で更新:

```sql
UPDATE learn_cell_code lcc
   SET notebook_id = un.id::text
  FROM user_notebook un
 WHERE un.slug = lcc.notebook_id;
-- 同様に learn_progress, learn_submission
```

cell-id は既存 SICP 時代も string で保存されている（cell-id の型緩和は前フェーズで完了済み）ので影響なし。

## 7. テスト戦略

### 7.1 既存 SICP テストの書き換え

`tests/game/notebooks/sicp-X-Y-Z.lisp` 56 ファイルは廃止。代わりに DB ベースの統合テスト 1 ファイルにまとめる:

```
tests/integration/sicp-notebooks.lisp
  (deftest sicp-all-notebooks-grade-canonical-solutions
    (with-test-db
      (load-sicp-fixtures!)              ; SICP body_md を 56 行 INSERT
      (dolist (slug (all-sicp-slugs))    ; "sicp-1-1-1" など
        (let* ((nb (get-user-notebook-by-slug slug))
               (cells (parse-notebook-body (user-notebook-body-md nb)))
               (exercises (collect-exercises cells))
               (solutions (collect-solutions cells)))
          (dolist (ex exercises)
            (let ((sol (find-solution-for-exercise ex solutions)))
              (when sol
                (let ((result (run-exercise-with-solution nb ex sol)))
                  (ok (eq :pass (notebook-cell-result-status result))
                      (format nil "~A / ~A" slug (cell-description ex)))))))))))
```

`load-sicp-fixtures!` は SICP 移行で生成された markdown ファイル群（`docs/sicp/sicp-X-Y-Z.md`）を読んで DB に書き込む。これらの md ファイルは git にコミットして source of truth とする（DB は実行時状態、md ファイルが master）。

### 7.2 パーサテスト

`tests/game/notebook-parser.lisp` に `===solution===` の round-trip + cell-id 安定化テストを追加。

### 7.3 Course テスト

```
tests/db/courses.lisp                — CRUD（create, get-by-slug, list, count, add/remove notebook, reorder）
tests/web/course-routes.lisp         — ハンドラ統合テスト
```

## 8. フェーズ分けと優先順位

実装は以下の順で進める。各フェーズはコミット可能な状態で完結させる:

| Phase | 内容                                                        | 既存への影響 |
|-------|-------------------------------------------------------------|--------------|
| 0     | SICP 既存 cell の Spinneret DSL を grep して手動変換が要る要素を洗い出す（オフライン作業） | なし |
| 1     | パーサに `===solution===` 追加 + テスト                     | なし          |
| 2     | `course` / `course_notebook` Mito モデル + マイグレーション  | なし          |
| 3     | `db/courses.lisp` CRUD + テスト                             | なし          |
| 4     | Course の admin UI + ルート + テスト                        | なし          |
| 5     | Course の公開 UI（`/courses`, `/c/:slug`）                  | なし          |
| 6     | Notebook viewer のコース文脈サポート（`?course=` で sidebar/breadcrumb 切替） | 微小（既存 `/n/:slug` 互換）|
| 7     | SICP 移行スクリプト作成 + ローカル環境で実行 + 検証         | DB データ追加 |
| 8     | 旧 `web/routes-wardlisp.lisp` SICP ハンドラ削除 + 301 redirect 設置 | URL 変更       |
| 9     | 旧 SICP 関連ファイル削除（`game/notebooks/*`, `game/notebook.lisp` の SICP 専用部分、`web/ui/learn-home.lisp`） | 大量削除       |
| 10    | SICP テスト書き換え（56 ファイル → 1 統合テスト）            | テスト構造変更 |
| 11    | ヘッダーリンクに Courses 追加 + 全テスト + 手動確認         | UX 微小       |

Phase 1〜6 は SICP に触れないので、間違っても既存環境を壊さない。Phase 7 以降は本番影響あり。

## 9. 既存機能への後方互換

| 既存                                       | 維持/変更                                              |
|--------------------------------------------|---------------------------------------------------------|
| user_notebook 一覧 `/notebooks`            | 維持                                                    |
| user_notebook 単体 `/n/:slug`              | 維持。`?course=<slug>` でコース文脈を追加可能に拡張    |
| user_notebook の admin `/notebooks/me`     | 維持                                                    |
| user_notebook の create/update/delete      | 維持                                                    |
| HTMX status toggle / delete                | 維持                                                    |
| ブログ系 `/posts`, `/blog`                 | 維持                                                    |
| account / auth / oauth                     | 維持                                                    |
| `/wardlisp/learn`, `/wardlisp/learn/:id`   | 301 redirect → `/c/sicp`, `/n/:slug`                    |
| `/wardlisp/learn/sync`                     | 301 redirect → `/learn/sync`                            |
| ブラウザの localStorage に SICP 進捗が残るユーザー | redirect で `/learn/sync` にマージ。学習進捗 DB は migration で notebook_id 更新済み |
| ヘッダーの "Notebooks" / "My Notebooks" リンク | 維持。"Courses" / "My Courses" を追加                  |

## 10. 開かれた疑問

1. **SICP の prose 本文に Spinneret DSL の特殊要素**（数式・画像・コード以外の構造）がどれだけあるか。Phase 0 で grep して数値化する。多ければ手動変換コストが想定より大きい。

2. **course_notebook の m:n vs 1:n**: m:n を提案しているが、UX 上「この Notebook はこのコース専用」と扱う方が学習者には分かりやすい。MVP では m:n で実装し、UI は1コース所属を前提に表示する妥協案を取る。

3. **コース内 Notebook の進捗集約**: 学習者の進捗は cell 単位（`learn_progress`）。コースの進捗 X/Y は「このコースの Notebook のうち、全 exercise を pass した Notebook 数」とするのか「pass した cell の総数 / 全 cell 数」とするのか。前者が単純で UX として「次にやる Notebook」が明確になる。MVP は前者。

4. **SICP の course slug を `"sicp"` で確定**してよいか。将来「SICP-Scheme」「SICP-Python」のように複数バージョンが出てくる可能性。今は `"sicp"` 一本で進めて衝突時に rename する。

5. **`web/routes-wardlisp.lisp` 自体の取り扱い**: SICP 専用ハンドラ削除後、`puzzle`, `arena`, `playground`, `reference` 等の wardlisp 系ルートが残る。ファイル名は維持。

6. **Course 削除時の user_notebook の扱い**: `course_notebook` を ON DELETE CASCADE で消すだけ、Notebook 自体は残す。これで OK。

## 11. 想定される反論と対応

- **「SICP を DB に置くと git で diff が見えなくなる」**: source of truth は `docs/sicp/*.md` ファイルで、git 管理。DB は実行時状態。
- **「移行スクリプトが本番で失敗したら？」**: トランザクションでラップ。失敗時はロールバック。本番投入前に staging で full migration を完走させる。
- **「301 redirect の運用期間は？」**: 1 リリース（〜2週間）後にログを見て 0 アクセスなら削除。
- **「m:n は YAGNI では？」**: 1:n から m:n への schema migration は痛い（既存の course_id を notebook に付けてから join 表に移す）が、m:n から 1:n は単に UNIQUE 追加で済む。安全側に振る。
