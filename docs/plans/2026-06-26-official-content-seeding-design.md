# 公式コンテンツの汎用シード機構 設計

> 作成日: 2026-06-26 / ブランチ: `feat/official-content-seeding`

## Goal

SICP を「公式コース」の1つとして公開する。ただし **SICP に特化しすぎず**、今後増える公式コンテンツ（コース）を汎用的に扱える仕組みとして実装する。具体的には、SICP 固有定数にハードコードされた `scripts/seed-sicp.lisp` を、**「コース定義＝宣言的データ、汎用シーダが冪等に投入」** の形へリファクタし、`:recurya` システムの一部としてロード可能なモジュールにする。SICP はレジストリの最初の1エントリになる。さらに、起動時に冪等な自動シードを行い、新規 DB でも公式コンテンツが自動復元されるようにする。

## 背景 / 現状

コース機能と SICP 移行はほぼ完成している：

- `course` / `course_notebook` モデル、`db/courses` / `db/course-notebooks` CRUD、公開 UI（`/courses` 一覧、`/c/@:handle/:slug` コースページ）はすべて実装・ルート登録済み。
- 旧 `/wardlisp/learn` 系は `/c/@recurya/sicp`・`/@recurya/:slug` への 301/308 リダイレクトに置換済み（`web/routes.lisp`）。リダイレクト先は正規著者ハンドル `recurya`（`recurya/web/routes:+sicp-author-handle+`）に依存。
- SICP 本文は `docs/sicp/sicp-X-Y-Z.md` 56 本の素の `===...===` マークダウン。
- 冪等なシードスクリプト `scripts/seed-sicp.lisp`（`scripts/seed-sicp:seed-sicp!`）が存在し、recurya ユーザー＋ published+public な `sicp` コース＋56 ノートブックを find-or-create-or-correct で投入できる。

**しかし未解決:**

- シードはどこからも自動実行されておらず（`docker-entrypoint.sh` は呼ばない）、**現在の開発 DB には recurya ユーザー・sicp コース・ノートブックがまだ存在しない**（公開されていない）。
- シードロジックが SICP 専用にハードコードされている（著者ハンドル/メール/表示名、コーススラッグ/タイトル/サマリ、`docs/sicp/`、`sicp-X-Y-Z` 前提の章節番号ソート、`"SICP <slug>"` タイトル生成）。汎用化しないと公式コースを増やすたびにコード分岐が増える。
- 「公式 (official)」という独立した概念（バッジ・特別な扱い）はコードに存在しない。コースは「公開ユーザーの公開コース」が `/courses` に同列に並ぶだけで、SICP の「公式」性は正規ユーザー `recurya` が著者であるという慣習で表現される。

## 要件（ブレインストーミングで確定）

1. **最小スコープ**: official/featured バッジや専用 UI などの新概念は作らない。既存の「published+public な recurya 著者コース」として公開する。
2. **起動時自動シード**: 冪等シードをブート時に実行し、DB リセット後も自動復元する。
3. **SICP 非依存の汎用機構**: コース定義をデータ化し、汎用シーダが処理する。SICP は最初の1エントリ。将来のコース追加はエントリ追加＋コンテンツ配置のみ。
4. アプローチは **Lisp データレジストリ方式**（採択）。

## アーキテクチャ概要

```
*official-courses*  (宣言データ: official-course の list)
        |
        v
seed-official-content!  ── seed-course! ──┬─ ensure-official-author
   (冪等・全エントリを処理)               ├─ ensure-official-course
                                          └─ ensure-notebooks-attached
        ^
        |  (起動時に1回)
docker-entrypoint.sh:  db/core:start! → seed-official-content! → web/server:start!
```

すべて find-or-create-or-correct セマンティクスのため、毎起動で呼んでも安全。

## 詳細設計

### 1. 新モジュール `recurya/seed/official-content`

- ファイル: `seed/official-content.lisp`、パッケージ `#:recurya/seed/official-content`。
- `recurya.asd` のメインシステム `depends-on` に追加（web/routes より後。converter 移設後の `recurya/game/notebook-jsonb` に依存）。
- エクスポート: `*official-courses*`、`official-course`（struct とアクセサ）、`make-official-course`、`seed-official-content!`、`seed-course!`。

### 2. コース定義データモデル（レジストリ）

```lisp
(defstruct official-course
  author-handle            ; 例 "recurya"（単一の真実源は +sicp-author-handle+ を import）
  author-email             ; 例 "recurya+sicp@example.invalid"（.invalid TLD）
  author-display-name      ; 例 "Recurya"
  slug                     ; 例 "sicp"
  title                    ; 例 "SICP"
  summary                  ; 例 "Structure and Interpretation ..."
  content-dir              ; 例 #P"docs/sicp/"（system-relative)
  (order :natural)         ; :natural | (slug の明示リスト)
  notebook-title-fn)       ; (lambda (slug) ...) -> タイトル文字列
```

`*official-courses*` はこの struct のリスト。**SICP は1エントリ**で、`author-handle="recurya"` 等を直接記述する。`recurya/web/routes:+sicp-author-handle+`（リダイレクト用）との一致は **drift guard テスト**で保証し、シードモジュールが web 層に依存しないようにする（§4 と整合）。`notebook-title-fn` は現状維持の `(lambda (slug) (format nil "SICP ~A" slug))`（タイトル品質改善はスコープ外）。

著者モデルは「コースごとに著者指定」。当面は全部 recurya でも、別の公式著者を後から追加可能。

### 3. 汎用シードエンジン（`scripts/seed-sicp.lisp` の各関数を汎用化）

- `ensure-official-author (spec)` → handle で検索／なければ email 検索（別 handle なら warn してそのまま返す）／なければ `create-user!` で作成。
- `ensure-official-course (spec author)` → slug で検索し、author / status / visibility / published-at を **published+public+spec著者** に補正（dirty 時のみ save-dao）。なければ作成。
- `ensure-notebooks-attached (spec course author)` → `content-dir` を `order` 順に走査し、各 md を published+public ノートブック（著者=spec著者）として find-or-create（既存の別著者行は spec 著者へ repoint）、`course_notebook` に未紐付けなら順番に追加。
- ヘルパ:
  - `%content-markdown-files (dir order)` — `dir` 内 `*.md` を `order` で整列して返す。`order=:natural` のとき `natural-string<` でソート、リストのときはその順。
  - `natural-string<` — 文字列を「数字の連続」と「非数字の連続」に分割し、数字部分は数値比較する汎用ナチュラルソート。`sicp-1-2` < `sicp-1-10` を正しく扱い、任意 slug に対応（既存の `%sicp-slug<` の汎用版）。
  - `%ensure-notebook-row` / `%course-notebook-already-attached-p` / `%next-course-position` — slug 前提を外して汎用化。
- `seed-course! (spec)` → 上記3つを順に呼び、サマリ plist を返す。
- `seed-official-content! (&key (courses *official-courses*))` → `courses` を map し、コース単位 `handler-case` で隔離（1コースの失敗が他を止めない）。サマリ list を返す。

冪等性・別著者行の repoint など既存セマンティクスをそのまま継承する。

### 4. セル→JSONB 変換の移設（承認済み: 推奨方式）

`create-notebook! :cells ...` には「JSONB 化前の Lisp データ（ハッシュテーブル）」が必要で、その変換 `cell->jsonb-form` / `jsonb-hash->cell` は現状 web/routes 内部関数。

- 新モジュール `recurya/game/notebook-jsonb`（`game/notebook-jsonb.lisp`）を作り、両関数を移設（依存は `game/notebook` + `game/puzzle` のみ）。
- `web/routes.lisp` は両関数の `defun` を削除し `:import-from #:recurya/game/notebook-jsonb` で取り込む。web/routes 内の無修飾呼び出しは import シンボルへ解決。テストの `recurya/web/routes::cell->jsonb-form` 参照も **import により同一シンボルへ解決するため変更不要**。
- シーダは `recurya/game/notebook-jsonb` から import → **web 層への依存ゼロ**。
- `recurya.asd` に `recurya/game/notebook-jsonb` を登録（notebook 系の近く、web/routes より前）。

### 5. 起動時自動シードの結線

`docker-entrypoint.sh` の `--eval "(recurya/db/core:start!)"` の**直後・web 起動の直前**に追加:

```
--eval "(handler-case (recurya/seed/official-content:seed-official-content!) (error (e) (format t \"~&[seed] WARN: ~A~%\" e)))"
```

- `web/server:start!` は変更せず純粋に保つ（start! を呼ぶテストに副作用を出さない）。`db/core:start!` が既に entrypoint にある流儀に合わせ、ブート手順を1箇所に集約。
- 冪等なので新規 DB でも自動復元。コンテンツ不正は warn してブート継続（コース単位 handler-case ＋ entrypoint 側でも保険）。
- `seed-official-content!` は REPL / CI からの手動実行も可。

### 6. 既存スクリプト・テストの更新（承認済み）

- `scripts/seed-sicp.lisp` を撤去し、薄い手動実行ラッパ `scripts/seed-official-content.lisp`（recurya をロードして `seed-official-content!` を呼ぶだけ）に置換。
- `tests/integration/sicp-seed.lisp` を新モジュール対象に書き換え:
  - `scripts/seed-sicp.lisp` の遅延 load をやめ、`recurya/seed/official-content` を直接 import（`recurya.asd` のテスト依存に追加済みのため）。
  - 既存アサーション維持: recurya ユーザー生成・SICP が published+public・著者=recurya・冪等（同一 UUID）。
  - SICP 著者メール等はレジストリの SICP spec から取得（`*official-courses*` を参照）。
  - **SICP 非依存を証明する汎用テスト追加**: 合成フィクスチャ `tests/fixtures/official-course/*.md`（2本）から成る一時 spec で、著者＋コース＋順序付きノートブックが冪等に作られ、`order=:natural` が正しく効くことを検証。
- `+sicp-author-handle+` はリダイレクトハンドラ用に web/routes に残す。SICP レジストリエントリは `author-handle="recurya"` を直接記述し、**両者の一致を drift guard テストで保証**（`/c/@recurya/sicp` の解決を担保）。これによりシードモジュールは web 層に依存しない。

### 7. 影響ファイル

- 新規:
  - `seed/official-content.lisp`
  - `game/notebook-jsonb.lisp`
  - `scripts/seed-official-content.lisp`（手動実行ラッパ）
  - `tests/fixtures/official-course/*.md`（汎用テスト用フィクスチャ 2本）
- 変更:
  - `recurya.asd`（`recurya/game/notebook-jsonb`・`recurya/seed/official-content` をメインに、テスト系は既存 `recurya/tests/integration/sicp-seed` を維持）
  - `web/routes.lisp`（converter を import に変更、`defun` 削除。`+sicp-author-handle+` は維持）
  - `docker-entrypoint.sh`（自動シード 1 行追加）
  - `tests/integration/sicp-seed.lisp`（新モジュール対象に書き換え＋汎用テスト追加）
- 撤去:
  - `scripts/seed-sicp.lisp`

## 順序戦略（ナチュラルソート）

`natural-string<` は文字列を数字 run と非数字 run に分割し、対応する run を「数字 run は数値」「非数字 run は文字列」で比較する。これにより:

- `sicp-1-1-1` < `sicp-1-1-2` < ... < `sicp-1-10-1`（既存の章節番号順を維持）
- 任意 slug にも破綻なく適用（数字を含まない slug は通常の文字列比較に帰着）

明示順が必要なコースは spec の `order` に slug リストを渡して上書きできる。

## エラーハンドリング

- `seed-official-content!`: コース単位 `handler-case`。1コースの失敗（content-dir 不在・md パースエラー等）は warn してスキップ、他コースは継続。
- `content-dir` 不在 → warn + そのコースをスキップ。
- md パースエラー → ファイル名付きで warn（既存挙動を踏襲）。
- entrypoint 側でも `handler-case` で包み、シード失敗が web 起動を妨げないようにする。

## テスト戦略

- 既存 `tests/integration/sicp-canonical-solutions`（`docs/sicp/` + `load-sicp-fixtures!` 依存）は無影響。
- 書き換え後 `tests/integration/sicp-seed`（DB-backed, Postgres 必要）: SICP シードの正当性＋冪等性。
- 新汎用テスト（合成フィクスチャ）: SICP 非依存の汎用シードが機能し順序が正しいこと。
- 全スイート通し（`recurya/tests`）。
- 手動スモーク: ブート → `/c/@recurya/sicp` に 56 本表示 → `/courses` に SICP 掲載 → `/wardlisp/learn` が 301 でコースへ。

## スコープ外 (YAGNI)

- official/featured バッジ、`/courses` やトップでの公式コース優先表示などの新 UI/概念。
- ノートブックタイトルの品質改善（`"SICP <slug>"` のまま維持）。
- ファイルマニフェスト方式（アプローチ B）やコンテンツルートの再配置。
- 本番デプロイ運用（対象は現状の開発/コンテナ起動経路）。

## 開かれた疑問

なし（④ converter 移設・⑥ スクリプト撤去はユーザー承認済み）。
