# コース機能と SICP の Notebook 化 実装計画

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** SICP の 56 ノートブックを `user_notebook` テーブルに移行し、`course` エンティティで組織化する。二系統だった notebook 抽象を一本化し、SICP 専用の分岐コード（`web/routes-wardlisp.lisp` の SICP ハンドラ群、`(or null keyword string)` の id 型分岐、`*chapter-titles*` 等）を削除する。

**Architecture:** `course` と `course_notebook` (m:n、position 付き) を新設。パーサに新セル種別 `===solution===` を追加し canonical answer を body-md に持たせる。SICP 移行スクリプトで `game/notebooks/sicp-*` 56 本を markdown へ変換し `user_notebook` 行に書き込む。既存 SICP ルートは 1〜2 リリース 301 redirect で運用してから削除。

**Tech Stack:** Common Lisp / SBCL + qlot, Mito ORM + cl-dbi (PostgreSQL), Ningle + Clack/Hunchentoot, Spinneret HTML, HTMX, Rove tests, 既存依存（`3bmd`, `plump`, `cl-ppcre`, `uuid`）。新規依存なし。

**Reference:** 設計ドキュメント [`docs/plans/2026-05-03-courses-and-sicp-migration-design.md`](./2026-05-03-courses-and-sicp-migration-design.md) を必ず参照。

**Lispツール規約:** すべての `.lisp`/`.asd` 操作は cl-mcp ツール（`lisp-edit-form`/`lisp-patch-form`/`lisp-read-file`/`repl-eval`/`load-system`/`run-tests` 等）。Read/Edit/Write/Grep/Glob はLispファイルに使わない。Markdown/SQL/YAML 等は通常の Write/Edit 可。

**初期セットアップ:** 各セッション冒頭で `mcp__cl-mcp__fs-set-project-root path=/home/wiz/recurya` を呼ぶ。

**コミット方針:** 各タスクを「テスト→失敗確認→実装→成功確認→コミット」で 1 タスク 1 コミット。コミットメッセージは `feat:` `test:` `refactor:` `chore:` プレフィックス + 既存スタイル（命令法、末尾 `Co-Authored-By:` 行）。

**ブランチ:** `feat/courses-and-sicp-migration` を `main` から切って作業。

---

## Phase 0: 事前調査

### Task 1: SICP の prose body にある DSL 要素の調査

**Files:** なし（オフライン作業）

**Step 1: SICP セルで使われている全 Spinneret タグを抽出**

```
clgrep-search pattern="\\(:[a-z]+" path="game/notebooks"
```

**Step 2: ユニーク化して `docs/sicp-migration-dsl-survey.md` にリストアップ**

期待: `:p`, `:strong`, `:em`, `:code`, `:a`, `:ul`, `:li`, `:ol`, `:h2`〜`:h6`, `:blockquote`, `:img`, `:br`, `:pre` あたりが想定。これら以外（標準 markdown に落ちないもの）が出たら設計の想定外として議論。

**Step 3: `:img` の使用例を確認**

`:src` 属性にローカルパスが入っているか外部 URL かを確認。サニタイザ要件の決定に使う。

**Step 4: 結果を design に追記してコミット**

```bash
git add docs/sicp-migration-dsl-survey.md
git commit -m "docs: catalog SICP prose DSL elements for markdown migration"
```

---

## Phase 1: パーサに `===solution===` 追加

### Task 2: `===solution===` ヘッダ認識テストを書く（失敗）

**Files:**
- Modify: `tests/game/notebook-parser.lisp`

**Step 1: 失敗テスト追加**

`lisp-edit-form` で `single-exercise-with-expect` の直後に挿入:

```lisp
(deftest single-solution-cell
  (let ((body "===solution: my-square===
(define (my-square x) (* x x))"))
    (multiple-value-bind (cells errors) (parse-notebook-body body)
      (ok (null errors))
      (ok (= 1 (length cells)))
      (let ((c (first cells)))
        (ok (eq :code-solution (cell-kind c)))
        (ok (string= "my-square" (cell-description c)))
        (ok (search "(* x x)" (cell-body c)))))))
```

**Step 2: テスト実行 — 失敗確認**

```
mcp__cl-mcp__run-tests system="recurya/tests/game/notebook-parser" test="recurya/tests/game/notebook-parser::single-solution-cell"
```

期待: 「unknown header」エラーで FAIL（現在の `===banana===` 系扱い）。

**Step 3: コミット失敗テスト**

```bash
git commit -am "test: add failing test for ===solution=== cell parsing"
```

---

### Task 3: `===solution===` パーサ実装

**Files:**
- Modify: `game/notebook-parser.lisp`

**Step 1: ヘッダ認識を追加**

`+exercise-header-regex+` の直後に `+solution-header-regex+` を `defparameter`:

```lisp
(defparameter +solution-header-regex+
  (cl-ppcre:create-scanner "^===solution: (.+)===$")
  "Scanner for `===solution: <description>===' fence headers.")
```

**Step 2: `parse-fence-header` を拡張**

solution 用の case を追加し `(values :code-solution description)` を返す。

**Step 3: parser 状態機械の cond に `:code-solution` 分岐を追加**

`flush` 時に `current-kind = :code-solution` なら通常 cell として作成（test-cases なし）。description は header から取得。

**Step 4: テスト実行 — PASS**

```
mcp__cl-mcp__run-tests system="recurya/tests/game/notebook-parser" test="recurya/tests/game/notebook-parser::single-solution-cell"
```

期待: PASS。

**Step 5: コミット**

```bash
git commit -am "feat: parse ===solution=== cells as :code-solution kind"
```

---

### Task 4: solution の round-trip + cell-id 安定化テスト

**Files:**
- Modify: `tests/game/notebook-parser.lisp`
- Modify: `game/notebook-parser.lisp`

**Step 1: 失敗テスト追加**

```lisp
(deftest roundtrip-with-solution
  (let* ((body "===exercise: square===
(define (square x) ???)

===expect: square===
4

===solution: square===
(define (square x) (* x x))")
         (cells1 (parse-notebook-body body))
         (md     (cells->body-md cells1))
         (cells2 (parse-notebook-body md)))
    (ok (= (length cells1) (length cells2)))
    (loop for c1 in cells1 for c2 in cells2 do
          (ok (eq      (cell-kind c1) (cell-kind c2)))
          (ok (string= (cell-body c1) (cell-body c2))))))

(deftest preserves-solution-cell-id
  (let* ((body "===solution: foo===
(define foo 1)")
         (existing (list (make-cell :id "STABLE-SOL" :kind :code-solution
                                    :body "(define foo 1)"
                                    :description "foo"))))
    (multiple-value-bind (cells errors) (parse-notebook-body body existing)
      (ok (null errors))
      (ok (string= "STABLE-SOL" (cell-id (first cells)))))))
```

**Step 2: テスト実行 — 失敗確認**

`cells->body-md` がまだ `:code-solution` を render しないので片方は失敗するはず。

**Step 3: `render-cell` (内部関数) に solution 分岐追加**

`===solution: <desc>===` ヘッダを出力。

**Step 4: テスト実行 — PASS**

**Step 5: コミット**

```bash
git commit -am "feat: render :code-solution cells back to body markdown"
```

---

## Phase 2: course / course_notebook テーブル

### Task 5: `course` モデル定義

**Files:**
- Create: `models/course.lisp`
- Modify: `recurya.asd`（主システムに `"recurya/models/course"`）

**Step 1: モデル定義**

`fs-write-file` で:

```lisp
;;;; models/course.lisp --- Course (collection of user_notebook).

(defpackage #:recurya/models/course
  (:use #:cl #:mito)
  (:import-from #:recurya/models/users #:users #:users-id)
  (:export #:course
           #:course-id
           #:course-slug
           #:course-title
           #:course-summary
           #:course-status
           #:course-published-at
           #:course-author
           #:course-author-id
           #:course-created-at
           #:course-updated-at))

(in-package #:recurya/models/course)

(deftable course ()
  ((id :col-type :uuid :initarg :id :accessor %course-id :primary-key t)
   (slug :col-type (:varchar 255) :initarg :slug :accessor course-slug)
   (title :col-type (:varchar 255) :initarg :title :accessor course-title)
   (summary :col-type (or (:varchar 500) :null)
            :initarg :summary :initform nil :accessor course-summary)
   (status :col-type (:varchar 32) :initarg :status :initform "draft"
           :accessor course-status)
   (published-at :col-type (or :timestamptz :null)
                 :initarg :published-at :initform nil
                 :accessor course-published-at)
   (author :col-type users :initarg :author :accessor course-author))
  (:auto-pk nil)
  (:unique-keys slug)
  (:keys (status :created_at) (author_id :created_at))
  (:documentation "A learning course bundling user_notebook items in order."))

(defun course-id (c) (%course-id c))

(defun course-author-id (c)
  (let ((u (course-author c))) (when u (users-id u))))

(defun course-created-at (c) (mito:object-created-at c))
(defun course-updated-at (c) (mito:object-updated-at c))
```

**Step 2: ASDF 登録**

`lisp-patch-form` で `"recurya/models/user-notebook"` の直後に `"recurya/models/course"` を追加。

**Step 3: load 確認**

```
mcp__cl-mcp__load-system system="recurya/models/course"
```

**Step 4: コミット**

```bash
git add models/course.lisp recurya.asd
git commit -m "feat: add course Mito model"
```

---

### Task 6: `course_notebook` 結合モデル

**Files:**
- Create: `models/course-notebook.lisp`
- Modify: `recurya.asd`

**Step 1: モデル定義**

```lisp
;;;; models/course-notebook.lisp --- Many-to-many join: course <-> user_notebook.

(defpackage #:recurya/models/course-notebook
  (:use #:cl #:mito)
  (:import-from #:recurya/models/course #:course #:course-id)
  (:import-from #:recurya/models/user-notebook #:user-notebook #:user-notebook-id)
  (:export #:course-notebook
           #:course-notebook-id
           #:course-notebook-course
           #:course-notebook-course-id
           #:course-notebook-notebook
           #:course-notebook-notebook-id
           #:course-notebook-position))

(in-package #:recurya/models/course-notebook)

(deftable course-notebook ()
  ((course :col-type course :initarg :course :accessor course-notebook-course)
   (notebook :col-type user-notebook :initarg :notebook
             :accessor course-notebook-notebook)
   (position :col-type :integer :initarg :position
             :accessor course-notebook-position))
  (:unique-keys (course_id notebook_id))
  (:keys (course_id position))
  (:documentation "Join row mapping a notebook to a course at a given position."))

(defun course-notebook-id (cn) (mito:object-id cn))

(defun course-notebook-course-id (cn)
  (let ((c (course-notebook-course cn))) (when c (course-id c))))

(defun course-notebook-notebook-id (cn)
  (let ((n (course-notebook-notebook cn))) (when n (user-notebook-id n))))
```

**Step 2: ASDF 登録**

course の直後に `"recurya/models/course-notebook"`。

**Step 3: load 確認、コミット**

```bash
git commit -am "feat: add course_notebook join model"
```

---

### Task 7: マイグレーション生成と適用

**Files:**
- Create: `db/migrations/<timestamp>-courses.up.sql`（Mito CLI 生成）
- Create: `db/migrations/<timestamp>-courses.down.sql`
- Modify: `db/schema.sql`（自動更新）

**Step 1: マイグレーション生成**

```bash
.qlot/bin/mito generate-migrations -t postgres -H localhost -P 15434 \
  -d recurya -u postgres -p postgres -s recurya -D db/
```

**Step 2: 出力 SQL レビュー**

期待: `CREATE TABLE "course"` と `CREATE TABLE "course_notebook"`。drift があれば設計ドキュメントと照らして判断。

**Step 3: マイグレーション適用**

```bash
.qlot/bin/mito migrate -t postgres -H localhost -P 15434 \
  -d recurya -u postgres -p postgres -s recurya -D db/
```

**Step 4: スキーマ確認**

```bash
PGPASSWORD=postgres psql -h localhost -p 15434 -U postgres -d recurya \
  -c '\d course' -c '\d course_notebook'
```

期待: 全カラムと index、FK が見える。

**Step 5: コミット**

```bash
git add db/migrations/ db/schema.sql
git commit -m "feat: add course and course_notebook tables"
```

---

## Phase 3: db CRUD

### Task 8: course CRUD - create / get-by-id / get-by-slug（テスト先行）

**Files:**
- Create: `db/courses.lisp`
- Create: `tests/db/courses.lisp`
- Modify: `recurya.asd`、`tests/all.lisp`、`tests/support/db.lisp`

**Step 1: テスト雛形（既存 `tests/db/user-notebooks.lisp` 参照）**

最初のテスト:

```lisp
(deftest create-and-get-course-by-id
  (with-test-db
    (let* ((u (create-test-user))
           (c (create-course! :title "C1" :author u))
           (id (course-id c)))
      (let ((found (get-course-by-id id)))
        (ok found)
        (ok (string= "C1" (course-title found)))
        (ok (string= "c1" (course-slug found)))
        (ok (string= "draft" (course-status found)))))))
```

**Step 2: `tests/support/db.lisp` の cleanup に course 系を追加**

`cleanup-all-test-data` の `DELETE FROM user_notebook` の前に:

```lisp
(execute! "DELETE FROM course_notebook")
(execute! "DELETE FROM course")
```

（FK 順序を考慮）

**Step 3: stub と ASDF 登録**

```lisp
(defpackage #:recurya/db/courses
  (:use #:cl)
  (:import-from #:mito #:find-dao #:select-dao #:insert-dao #:save-dao #:delete-dao)
  (:import-from #:sxql #:where #:order-by #:limit)
  (:import-from #:recurya/db/core #:generate-uuid #:ensure-uuid)
  (:import-from #:recurya/db/posts #:slugify)
  (:import-from #:recurya/models/course
                #:course #:course-id #:course-slug #:course-title
                #:course-summary #:course-status #:course-published-at
                #:course-author #:course-author-id
                #:course-created-at #:course-updated-at)
  (:export #:course #:course-id #:course-slug #:course-title
           #:course-summary #:course-status #:course-published-at
           #:course-author #:course-author-id
           #:course-created-at #:course-updated-at
           #:create-course! #:get-course-by-id #:get-course-by-slug))

(in-package #:recurya/db/courses)

(defun create-course! (&key title summary slug status published-at author course-id)
  (declare (ignore title summary slug status published-at author course-id))
  (error "not implemented"))
(defun get-course-by-id (id)   (declare (ignore id))   (error "not implemented"))
(defun get-course-by-slug (slug) (declare (ignore slug)) (error "not implemented"))
```

主システムに `"recurya/db/courses"` を `"recurya/db/user-notebooks"` の直後。

テストシステムに `"recurya/tests/db/courses"`、`tests/all.lisp` に `:recurya/tests/db/courses`。

**Step 4: テスト実行 — 失敗確認**

```
mcp__cl-mcp__run-tests system="recurya/tests/db/courses"
```

**Step 5: 実装**

```lisp
(defun create-course! (&key title summary slug status published-at author course-id)
  (let ((id (or course-id (generate-uuid)))
        (slug (or slug (slugify title))))
    (insert-dao
     (make-instance 'course :id id :slug slug :title title :summary summary
                    :status (or status "draft") :published-at published-at
                    :author author))))

(defun get-course-by-id (id)
  (find-dao 'course :id (ensure-uuid id)))

(defun get-course-by-slug (slug)
  (find-dao 'course :slug slug))
```

**Step 6: テスト PASS、コミット**

```bash
git commit -am "feat: add course create / get-by-id / get-by-slug"
```

---

### Task 9: course CRUD - update / delete

**Files:** Task 8 と同じ 2 ファイル。

**Step 1: テスト追加** — `update-course!` で部分更新（title, status, published-at）、`delete-course!` で削除と nil 返り。

**Step 2-5: 失敗 → 実装 → PASS → コミット**

実装は `recurya/db/user-notebooks` の `update-user-notebook!` / `delete-user-notebook!` と同型。

---

### Task 10: course CRUD - list / count

**Files:** 同上。

**Step 1: テスト追加** — `list-courses` で status/author-id filter + limit/offset、`count-courses` で同条件 SQL COUNT。

**Step 2-5:** `recurya/db/user-notebooks` の `list-user-notebooks` / `count-user-notebooks` を翻案。

---

### Task 11: course-notebook 結合 CRUD

**Files:**
- Create: `db/course-notebooks.lisp`
- Create: `tests/db/course-notebooks.lisp`

**Step 1: テスト**

```lisp
(deftest add-and-list-course-notebooks
  (with-test-db
    (let* ((u (create-test-user))
           (c (create-course! :title "C" :author u))
           (nb1 (create-user-notebook! :title "N1" :body-md "===prose===\nx"
                                        :cells '() :author u))
           (nb2 (create-user-notebook! :title "N2" :body-md "===prose===\ny"
                                        :cells '() :author u)))
      (add-notebook-to-course! (course-id c) (user-notebook-id nb1) :position 0)
      (add-notebook-to-course! (course-id c) (user-notebook-id nb2) :position 1)
      (let ((items (list-course-notebooks (course-id c))))
        (ok (= 2 (length items)))
        (ok (= 0 (course-notebook-position (first items))))
        (ok (= 1 (course-notebook-position (second items))))))))

(deftest move-notebook-up-down
  ...)

(deftest remove-notebook-from-course
  ...)
```

**Step 2: stub + ASDF 登録**

エクスポート: `add-notebook-to-course!`, `remove-notebook-from-course!`, `move-notebook-up!`, `move-notebook-down!`, `list-course-notebooks`, `get-course-notebook`.

**Step 3-5: 失敗 → 実装 → PASS → コミット**

`move-up!` / `move-down!` は対象行と隣接行の position を SWAP するトランザクション処理。

---

## Phase 4: Course の admin UI

### Task 12: コース一覧 UI（`/courses/me`）

**Files:**
- Create: `web/ui/courses.lisp`
- Modify: `recurya.asd`

`web/ui/user-notebooks.lisp` を参考に翻案。テーブル列: Title / Status / Notebooks count / Created / Actions（Edit, Delete）。HTMX 削除モーダル。

スモークテスト: 空状態、1件、複数件で render してエラーが出ないこと。

---

### Task 13: コース新規/編集フォーム UI

**Files:**
- Create: `web/ui/course-form.lisp`
- Modify: `recurya.asd`

`web/ui/user-notebook-form.lisp` を参考。フィールド: title / slug / summary / status。Notebook 追加 UI は別タスク（Task 16 以降の HTMX）で。

---

### Task 14: コース管理ハンドラ + ルート登録

**Files:**
- Modify: `web/routes.lisp`
- Create: `tests/web/course-routes.lisp`

ハンドラ:
- `courses-me-handler` (GET /courses/me)
- `course-new-handler` (GET /courses/new)
- `course-create-handler` (POST /courses)
- `course-edit-handler` (GET /courses/:id/edit)
- `course-update-handler` (POST /courses/:id)

statが空白 / 重複 slug などの検証は user-notebook と同型。owner only。

統合テストで anonymous redirect、blank-title、blank-slug、persistence、404 missing、403 non-owner、owner happy path を確認。

---

### Task 15: コース HTMX toggle-status / delete

**Files:** Task 14 と同じ。

ハンドラ: `course-toggle-status-handler`, `course-confirm-delete-handler`, `course-delete-handler`。`render-status-pill` を course 用に複製または抽象化（user-notebook 側のリファクタ余地は別タスクで）。

---

### Task 16: コース内 Notebook 追加 UI + ハンドラ

**Files:** Task 13 + Task 14 のファイル。

**Step 1: 編集フォームに「Notebook を追加」エリア**

ユーザの自分の published Notebook 一覧をプルダウンに出し、選んで「Add」ボタンで HTMX POST。

**Step 2: `course-add-notebook-handler` (POST /courses/:id/notebooks)**

owner only。bodyに `notebook_id` を受け取り、`add-notebook-to-course!` を呼ぶ。重複追加（UNIQUE 違反）はハンドリングしてフラッシュメッセージ表示。

**Step 3: 編集フォームの Notebook リストを HTMX で更新**

追加直後に再描画。

---

### Task 17: コース内 Notebook 並び替え + 削除（HTMX）

**Files:** Task 16 と同じ。

**Step 1: ↑↓ボタンと Remove ボタンの行をリストに追加**

```html
<tr id="cn-row-<id>">
  <td>1</td>
  <td>Notebook Title</td>
  <td>
    <button hx-post="/courses/:cid/notebooks/:cnid/up">↑</button>
    <button hx-post="/courses/:cid/notebooks/:cnid/down">↓</button>
    <button hx-post="/courses/:cid/notebooks/:cnid/remove" hx-target="#cn-row-..." hx-swap="outerHTML">Remove</button>
  </td>
</tr>
```

**Step 2: 3 つのハンドラ**

`course-notebook-move-up-handler`, `course-notebook-move-down-handler`, `course-notebook-remove-handler`。owner only。

**Step 3: テスト**

順序が swap されること、削除後 list から消えること、非 owner 403。

---

## Phase 5: Course の公開 UI

### Task 18: コース公開単体ビュー（`/c/:slug`）

**Files:**
- Create: `web/ui/course.lisp`
- Modify: `web/routes.lisp`、`tests/web/course-routes.lisp`、`recurya.asd`

`render` keyword引数: `:course :notebooks :user :passed-by-notebook`（Notebook 単位の進捗）。

レイアウト: コースタイトル + summary + Notebook カード並び。各カードに「X cells passed / Y total」（後続タスクで実装、最初は notebook count のみ）。

ハンドラ `public-course-handler` (GET /c/:slug):
- published only。draft は owner のみ。
- not found → 404
- ownerは owner-preview として draft を見られる

テスト: published 200、draft 他人 404、draft owner 200。

---

### Task 19: コース公開一覧（`/courses`）

**Files:**
- Create: `web/ui/course-list.lisp`
- Modify: `web/routes.lisp`、`tests/web/course-routes.lisp`、`recurya.asd`

`web/ui/notebook-list.lisp` を参考。`courses-public-handler` (GET /courses) を追加。published のみ。pagination 対応。

---

## Phase 6: Notebook viewer のコース連動

### Task 20: notebook viewer の `:sidebar-notebooks` をコースに対応

**Files:**
- Modify: `web/ui/notebook.lisp`

`render-sidebar` を汎用 `render-course-sidebar` にリネームし、`%chapter-prefix` / `%section-prefix` / `*chapter-titles*` / `*section-titles*` 依存を外す。

新しい `render-course-sidebar` は `(course-title course-slug notebooks current-id)` を受け取り、フラットリストで描画する。

`web/ui/notebook:render` の `:sidebar-notebooks` の解釈を変更:
- T → 後方互換として `(all-notebooks)` を引く（廃止予定）
- nil → サイドバー無し
- list → 渡された Notebook list を `render-course-sidebar` で描画

**Step 4: SICP テスト全 PASS 確認**

リネーム前後で SICP の実テスト ‒ `recurya/tests/game/notebooks/sicp-1-1-1` 等が PASS（Phase 7 で 56 個まとめて書き換え予定だが、ここでは未実施なので実テストが残っている）。

**Step 5: コミット**

---

### Task 21: `?course=<slug>` 文脈の追加

**Files:**
- Modify: `web/routes.lisp`
- Modify: `tests/web/user-notebook-routes.lisp`

`public-user-notebook-handler` を拡張:
- query param `course` が来たら `get-course-by-slug` で課程を取得
- そのコースの Notebook 一覧を取得して `:sidebar-notebooks` に渡す
- breadcrumb は `Notebooks > <Course Title> > <Notebook Title>`（`render` に `:breadcrumb` kwarg を追加）
- prev / next ボタン（`render` に `:course-prev-url :course-next-url` kwarg）

テスト: `?course=sicp` で sidebar に Notebook が並ぶ、breadcrumb にコース名、prev/next URL が正しい。

---

## Phase 7: SICP 移行

### Task 22: SICP markdown 出力スクリプト

**Files:**
- Create: `scripts/sicp-to-markdown.lisp`
- Create: `docs/sicp/sicp-1-1-1.md`〜`docs/sicp/sicp-3-5-5.md`（自動生成）

**Step 1: スクリプト本体**

```lisp
(defpackage #:scripts/sicp-to-markdown
  (:use #:cl)
  (:export #:export-all-sicp-to-markdown!))

(defun spinneret-tree->markdown (tree)
  ;; recursive walker; map :p :strong :em :code :a :ul :ol :li :h2..h6
  ;;                     :blockquote :img :br :pre to markdown
  ...)

(defun cell->markdown (cell) ...)

(defun notebook->markdown (nb)
  (format nil "~{~A~^~%~%~}"
          (mapcar #'cell->markdown (notebook-cells nb))))

(defun export-all-sicp-to-markdown! ()
  (ensure-directories-exist "docs/sicp/")
  (dolist (nb (recurya/game/notebooks/registry:all-notebooks))
    (let ((path (format nil "docs/sicp/~A.md"
                        (string-downcase (symbol-name (notebook-id nb))))))
      (with-open-file (s path :direction :output :if-exists :supersede)
        (write-string (notebook->markdown nb) s)))))
```

**Step 2: REPL で実行**

```
mcp__cl-mcp__repl-eval code="(scripts/sicp-to-markdown:export-all-sicp-to-markdown!)"
```

**Step 3: 出力チェック**

`ls docs/sicp/` で 56 ファイル。1 ファイルを目視で確認（特に prose 部分が markdown として読めるか）。

**Step 4: canonical answer の手動挿入**

各 SICP テストファイル（`tests/game/notebooks/sicp-X-Y-Z.lisp`）の `(let ((code "..."))` を抽出して、対応する exercise の直後に `===solution: <description>===\n<code>` を追加。これは半自動スクリプト + 手動レビュー。

スクリプト `scripts/inject-sicp-solutions.lisp` で:
- 各テストファイルから cl-ppcre で正解コードを抽出
- 対応する `docs/sicp/sicp-X-Y-Z.md` に挿入

**Step 5: 全 56 ファイルの目視チェック（ある程度）**

抜け漏れ・崩れがある箇所をリストアップ → 手動修正。

**Step 6: コミット**

```bash
git add scripts/sicp-to-markdown.lisp scripts/inject-sicp-solutions.lisp docs/sicp/
git commit -m "feat: export SICP notebooks to markdown fixtures"
```

---

### Task 23: SICP 読み込みスクリプト（DB へのインポート）

**Files:**
- Create: `scripts/import-sicp-to-db.lisp`

**Step 1: スクリプト本体**

```lisp
(defun import-sicp-to-db! (&key (admin-email "admin@example.com"))
  ;; 1. find-or-create admin user
  ;; 2. create-course! :title "SICP" :slug "sicp" :status "published"
  ;; 3. for each docs/sicp/*.md:
  ;;    - read body-md
  ;;    - parse-notebook-body for cells
  ;;    - create-user-notebook! :title <derived> :slug <basename> ...
  ;;    - add-notebook-to-course! at incremental position
  ;; 4. update learn_* tables: notebook_id from old slug to new UUID string
  )
```

**Step 2: ローカルで dry-run（トランザクションで begin / rollback）**

**Step 3: ローカル DB に commit 実行**

**Step 4: 確認**

```sql
SELECT slug, title FROM user_notebook WHERE slug LIKE 'sicp-%' LIMIT 5;
SELECT cn.position, un.slug FROM course_notebook cn
  JOIN user_notebook un ON un.id = cn.notebook_id
  JOIN course c ON c.id = cn.course_id
  WHERE c.slug = 'sicp' ORDER BY cn.position LIMIT 10;
```

期待: 56 行、position 0..55。

**Step 5: 既存 `learn_*` 行のマイグレーション**

```sql
UPDATE learn_cell_code lcc SET notebook_id = un.id::text
  FROM user_notebook un WHERE un.slug = lcc.notebook_id AND un.slug LIKE 'sicp-%';
-- 同様 learn_progress, learn_submission
```

**Step 6: コミット（スクリプトのみ。DB 状態はコミットしない）**

```bash
git add scripts/import-sicp-to-db.lisp
git commit -m "feat: SICP DB import script with learn_* migration"
```

---

## Phase 8: 旧 SICP ハンドラ削除 + 301 redirect

### Task 24: 旧 `/wardlisp/learn/...` を 301 redirect に置換

**Files:**
- Modify: `web/routes.lisp`（新ハンドラ）
- Modify: `web/routes-wardlisp.lisp`（既存ハンドラ削除）
- Modify: `web/server.lisp` または `web/app.lisp`（setup-wardlisp-routes の呼び出し方による）

**Step 1: 新 redirect ハンドラ追加**

```lisp
(defun sicp-learn-redirect-handler (params)
  "GET /wardlisp/learn -> 301 /c/sicp"
  (declare (ignore params))
  (list 301 (list :location "/c/sicp") '()))

(defun sicp-notebook-redirect-handler (params)
  (let ((id (get-path-param params :id)))
    (list 301 (list :location (format nil "/n/~A" id)) '())))

(defun sicp-cell-run-redirect-handler (params)
  (let ((id (get-path-param params :id))
        (i  (get-path-param params :index)))
    (list 308 (list :location (format nil "/n/~A/cells/~A/run" id i)) '())))
```

**Step 2: 旧ルートの再設定**

`setup-wardlisp-routes` で `learn-home-handler` 等を上記 redirect ハンドラに差し替える。

**Step 3: 旧ハンドラ削除**

`web/routes-wardlisp.lisp` から `learn-home-handler`, `notebook-page-handler`, `notebook-cell-run-handler`, `%coerce-notebook-id`, `%maybe-persist-cell-run`, `learn-sync-handler` を削除。

`learn-sync-handler` は `web/routes.lisp` に移植して `/learn/sync` で動かす。`/wardlisp/learn/sync` は 308 redirect。

**Step 4: テスト追加**

```lisp
(deftest sicp-old-routes-redirect-301
  ...)
```

旧 URL が新 URL に redirect することを確認。

**Step 5: コミット**

```bash
git commit -am "refactor: redirect /wardlisp/learn/* to /c/sicp and /n/:slug"
```

---

### Task 25: `/wardlisp/learn-home.lisp` UI 削除

**Files:**
- Delete: `web/ui/learn-home.lisp`
- Modify: `recurya.asd`（depends-on から `"recurya/web/ui/learn-home"` を削除）

**Step 1: 削除**

```
mcp__cl-mcp__fs-write-file path="web/ui/learn-home.lisp" content=""
```

→ `git rm web/ui/learn-home.lisp`

**Step 2: ASDF 更新**

**Step 3: load + テスト全 PASS**

**Step 4: コミット**

```bash
git rm web/ui/learn-home.lisp
git commit -am "refactor: remove web/ui/learn-home (replaced by /c/sicp)"
```

---

## Phase 9: 旧 SICP コード削除

### Task 26: `game/notebooks/*` 56 + registry の削除

**Files:**
- Delete: `game/notebooks/sicp-1-1-1.lisp`〜`sicp-3-5-5.lisp`（56 ファイル）
- Delete: `game/notebooks/registry.lisp`
- Modify: `recurya.asd`

```bash
git rm game/notebooks/sicp-*.lisp game/notebooks/registry.lisp
```

ASDF から該当行を全削除（57 行）。

**Step 2: load + 全テスト PASS 確認**

`tests/game/notebooks/sicp-*` テストはまだ残っているのでこのタスクで失敗する可能性あり。Task 28 (Phase 10) でまとめて書き換えるので、このタスクではコメントアウトする:

`tests/all.lisp` の `:recurya/tests/game/notebooks/sicp-*` を全コメントアウト。`recurya/tests` の depends-on も同様。

**Step 3: コミット**

```bash
git commit -am "refactor: remove hardcoded SICP notebooks (replaced by DB rows)"
```

---

### Task 27: `web/ui/notebook.lisp` の SICP 専用ロジック削除

**Files:**
- Modify: `web/ui/notebook.lisp`

`*chapter-titles*`, `*section-titles*`, `%chapter-prefix`, `%section-prefix` を削除。`render-sidebar` は Task 20 で `render-course-sidebar` にリネーム済み（旧版が残っていれば削除）。

**Step 1: load + テスト確認、コミット**

---

## Phase 10: SICP テスト書き換え

### Task 28: 56 個の SICP テストを 1 統合テストに集約

**Files:**
- Create: `tests/integration/sicp-canonical-solutions.lisp`
- Delete: `tests/game/notebooks/sicp-1-1-1.lisp`〜`sicp-3-5-5.lisp`（56 ファイル）
- Modify: `recurya.asd`、`tests/all.lisp`

**Step 1: 統合テスト作成**

```lisp
(deftest sicp-all-canonical-solutions-pass
  (with-test-db
    (load-sicp-fixtures!)              ; docs/sicp/*.md を DB に書き戻す
    (let* ((course (recurya/db/courses:get-course-by-slug "sicp"))
           (cns (recurya/db/course-notebooks:list-course-notebooks
                 (course-id course))))
      (dolist (cn cns)
        (let* ((nb (course-notebook-notebook cn))
               (cells (recurya/game/notebook-parser:parse-notebook-body
                       (user-notebook-body-md nb)))
               (exercises (remove-if-not (lambda (c) (eq (cell-kind c) :code-exercise)) cells))
               (solutions (remove-if-not (lambda (c) (eq (cell-kind c) :code-solution)) cells)))
          (dolist (ex exercises)
            (let ((sol (find (cell-description ex) solutions
                             :key #'cell-description :test #'string=)))
              (when sol
                (let ((result (run-exercise-with-solution nb ex sol)))
                  (ok (eq :pass (recurya/game/notebook:notebook-cell-result-status result))
                      (format nil "~A / ~A"
                              (user-notebook-slug nb)
                              (recurya/game/notebook:cell-description ex))))))))))))
```

`load-sicp-fixtures!` は `docs/sicp/*.md` を読んで `user_notebook` + `course_notebook` を作るヘルパ。

`run-exercise-with-solution` は exercise の cell-index を計算し、solution body を codes-prefix の該当位置に流し込んで `run-cell` を呼ぶヘルパ。

**Step 2: 56 ファイル削除**

```bash
git rm tests/game/notebooks/sicp-*.lisp
```

ASDF / tests/all.lisp の `:recurya/tests/game/notebooks/sicp-*` をすべて新 `:recurya/tests/integration/sicp-canonical-solutions` に置換。

**Step 3: テスト実行 — 全 SICP exercises が PASS**

```
mcp__cl-mcp__run-tests system="recurya/tests/integration/sicp-canonical-solutions"
```

**Step 4: コミット**

```bash
git commit -am "test: rewrite 56 SICP per-notebook tests as one DB-backed integration test"
```

---

## Phase 11: 仕上げ

### Task 29: ヘッダーリンクに Courses / My Courses 追加

**Files:**
- Modify: `web/ui/layout.lisp`

`Notebooks` の前に `Courses` を追加。ログイン時のみ `My Courses` を `My Notebooks` の前に追加。

スモークテスト (REPL): anonymous / logged-in 両方でリンクが正しく出る。

```bash
git commit -am "feat: add Courses and My Courses to header nav"
```

---

### Task 30: 全テスト通し + 手動スモークテスト

**Files:** なし（検証のみ）。

**Step 1: 全テスト実行**

```bash
docker compose exec -e POSTGRES_HOST=postgres -e POSTGRES_PORT=5432 recurya bash -lc \
  '.qlot/bin/rove recurya.asd'
```

期待: 全 PASS、exitcode 0。

**Step 2: 手動スモークテスト**

1. `/login` でログイン
2. `/courses/me` で Empty 状態確認
3. `/courses/new` で新規コース作成
4. `/notebooks/new` で Notebook 作成 → published に
5. `/courses/:id/edit` で Notebook をコースに追加 → 並び替え → 削除
6. `/courses/:id/toggle-status` で published に
7. `/courses` 公開一覧に出る
8. `/c/:slug` でコース単体ページ → Notebook カード並び
9. Notebook カードクリック → `/n/:slug?course=...` でコース sidebar / breadcrumb
10. cell 実行 → 進捗保存
11. `/wardlisp/learn` を踏むと `/c/sicp` に 301 redirect
12. `/wardlisp/learn/sicp-1-1-1` → `/n/sicp-1-1-1` に redirect
13. SICP の cell を実行 → 既存ユーザーの learn_progress が引き継がれている
14. 別ユーザーログインで他人の draft コース → 404
15. ログアウト → /courses は見える、/courses/me は /login redirect

**Step 3: SICP 全 56 Notebook の canonical-solution 統合テスト確認**

```
mcp__cl-mcp__run-tests system="recurya/tests/integration/sicp-canonical-solutions"
```

期待: 全 exercise PASS。

**Step 4: 旧 SICP テスト戦略との比較**

実行時間とカバレッジが変わっていないことを確認:
- 旧: 56 ファイル × 平均 2 deftest = ~120 deftest、各 5〜200ms
- 新: 1 deftest 内で全 56 Notebook をループ、合計時間を比較

**Step 5: 必要なら修正タスクを差し込む**

---

## 完了基準

- [ ] 全テスト（既存 + 新規）PASS
- [ ] 全 SICP 56 Notebook の canonical-solution が新統合テストで PASS
- [ ] 手動スモークテスト 15 項目 PASS
- [ ] `/wardlisp/learn/...` の 301 redirect が機能
- [ ] PR 作成可能な状態（`feat/courses-and-sicp-migration` ブランチ）

## 注意事項

- **`game/notebooks/*` の削除はテストの書き換えと同じコミット**にしないと CI が壊れる時間がある。Phase 9 / 10 を 1 コミットにまとめるか、Phase 9 で `tests/all.lisp` のテストを一時的に外す
- DB データの整合性は SICP 移行 (Task 23) 後にしか確認できない。staging 環境で 1 回 full migration を完走させる
- 301 redirect の運用期間中はサーバログで `/wardlisp/learn/...` のアクセス数を観測。0 になったら Phase 12（このプランの後続）で削除
- 設計ドキュメントの「開かれた疑問」リスト（design.md §10）は Phase 0 終了時に再確認
