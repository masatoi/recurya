# 公式コンテンツ汎用シード機構 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** SICP 固有だったシード処理を「宣言的レジストリ＋汎用シーダ」へ作り替え、`:recurya` システムの一部として起動時に冪等自動シードする。SICP はレジストリの最初の1エントリ。

**Architecture:** `recurya/game/notebook-jsonb`（セル↔JSONB変換をweb層から移設）と `recurya/seed/official-content`（`official-course` struct のレジストリ＋ find-or-create-or-correct な汎用シーダ）を新設。`docker-entrypoint.sh` が `db/core:start!` → `seed-official-content!` → `web/server:start!` の順でブートする。

**Tech Stack:** Common Lisp / SBCL + qlot、Mito ORM + cl-dbi (PostgreSQL)、Ningle/Clack、Spinneret、Rove。新規依存なし。

**Reference:** 設計 [`docs/plans/2026-06-26-official-content-seeding-design.md`](./2026-06-26-official-content-seeding-design.md)。

---

## 規約・前提

- **Lispツール規約:** すべての `.lisp`/`.asd` 操作は cl-mcp ツール（`lisp-edit-form`/`lisp-patch-form`/`lisp-read-file`/`lisp-check-parens`/`repl-eval`/`load-system`/`run-tests`）。Read/Edit/Write/Grep/Glob を Lisp ファイルに使わない。Markdown/SQL/YAML/シェルスクリプトは通常の Write/Edit 可。
- **初期セットアップ:** 各セッション冒頭で `mcp__cl-mcp__fs-set-project-root path=.`。
- **DB前提:** DB 連動テスト（`tests/web/notebook-routes`, `tests/integration/sicp-seed`）は PostgreSQL がローカル 15434 で起動している必要がある（`docker compose up -d`）。非DBテスト（`tests/game/*`, natural-ordering）は不要。
- **ブランチ:** `feat/official-content-seeding`（作成済み）。
- **コミット方針:** 1タスク1コミット。プレフィックス `feat:`/`refactor:`/`test:`/`chore:`。各コミットに末尾トレーラ `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>` を付ける（2つ目の `-m` で付与）。

## ファイル構成

| ファイル | 役割 | 区分 |
|---------|------|------|
| `game/notebook-jsonb.lisp` | セル struct ↔ JSONB ハッシュ変換（web 非依存の共有層） | 新規 |
| `seed/official-content.lisp` | `official-course` struct・レジストリ・汎用シーダ | 新規 |
| `scripts/seed-official-content.lisp` | 手動実行ラッパ（CI/ad-hoc） | 新規 |
| `tests/fixtures/official-course/demo-2.md`, `demo-10.md` | 汎用シードテスト用フィクスチャ | 新規 |
| `recurya.asd` | 新モジュール2つをメインシステムに登録 | 変更 |
| `web/routes.lisp` | converter を import に変更し定義削除（`+sicp-author-handle+` は維持） | 変更 |
| `docker-entrypoint.sh` | 起動時自動シード1行追加 | 変更 |
| `tests/integration/sicp-seed.lisp` | 新モジュール対象に全面書き換え＋汎用テスト追加 | 変更 |
| `scripts/seed-sicp.lisp` | 撤去 | 削除 |

---

## Task 1: セル↔JSONB変換を `recurya/game/notebook-jsonb` へ移設

**Files:**
- Create: `game/notebook-jsonb.lisp`
- Modify: `recurya.asd`（メインシステム depends-on）
- Modify: `web/routes.lisp`（defpackage に import 追加、2 defun 削除）

- [ ] **Step 1: 新モジュールファイルを作成**

`fs-write-file path="game/notebook-jsonb.lisp"` で以下を書き込む（内容は web/routes の既存定義をそのまま移設し、`make-cell`/`make-test-case` を import 参照に変更）:

```lisp
;;;; game/notebook-jsonb.lisp --- Cell <-> JSONB hash-table conversion.
;;;;
;;;; Pure conversion between notebook cell structs and the hash-table
;;;; shape stored in the notebook.cells JSONB column. Lives at the game
;;;; layer (no web dependency) so both web/routes and the official-content
;;;; seeder can share it.

(defpackage #:recurya/game/notebook-jsonb
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:cell-id
                #:cell-kind
                #:cell-body
                #:cell-description
                #:cell-test-cases
                #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case
                #:test-case-input
                #:test-case-expected
                #:test-case-description)
  (:export #:cell->jsonb-form
           #:jsonb-hash->cell))

(in-package #:recurya/game/notebook-jsonb)

(defun cell->jsonb-form (cell)
  "Convert a cell struct into a hash-table that jzon serializes as a JSON
object. Pairs with `jsonb-hash->cell' to round-trip cells through the
JSONB column while preserving stable cell ids across edits."
  (let ((h (make-hash-table :test 'equal)))
    (setf (gethash "cell-id"     h) (or (cell-id cell) "")
          (gethash "kind"        h) (string-downcase (symbol-name (cell-kind cell)))
          (gethash "body"        h) (or (cell-body cell) "")
          (gethash "description" h) (cell-description cell)
          (gethash "test-cases"  h)
          (mapcar (lambda (tc)
                    (let ((th (make-hash-table :test 'equal)))
                      (setf (gethash "input"       th) (test-case-input tc)
                            (gethash "expected"    th) (test-case-expected tc)
                            (gethash "description" th) (test-case-description tc))
                      th))
                  (cell-test-cases cell)))
    h))

(defun jsonb-hash->cell (h)
  "Reconstruct a cell struct from a JSONB hash-table produced by
`cell->jsonb-form'. Used to seed parse-notebook-body's existing-cells
so cell ids stay stable across edits."
  (let ((kind-str (gethash "kind" h ""))
        (raw-tcs  (gethash "test-cases" h #())))
    (make-cell
     :id (or (gethash "cell-id" h "") "")
     :kind (if (and kind-str (plusp (length kind-str)))
               (intern (string-upcase kind-str) :keyword)
               :prose)
     :body (or (gethash "body" h "") "")
     :description (or (gethash "description" h "") "")
     :test-cases (mapcar
                  (lambda (th)
                    (make-test-case
                     :input       (or (gethash "input" th "") "")
                     :expected    (or (gethash "expected" th "") "")
                     :description (or (gethash "description" th "") "")))
                  (coerce raw-tcs 'list)))))
```

- [ ] **Step 2: パーサ健全性を確認**

`lisp-check-parens path="game/notebook-jsonb.lisp"`
Expected: バランスOK（エラーなし）。

- [ ] **Step 3: メインシステムに登録**

`lisp-patch-form` で `recurya.asd` の `defsystem "recurya"` を編集。`"recurya/game/notebook-parser"` の行の直後に新モジュールを追加:

- form_type: `defsystem`, form_name: `recurya`
- old_text:
```
               "recurya/game/notebook-parser"
```
- new_text:
```
               "recurya/game/notebook-parser"
               "recurya/game/notebook-jsonb"
```

- [ ] **Step 4: 新モジュールをロード**

`load-system system="recurya/game/notebook-jsonb"`
Expected: `loaded successfully`、警告なし。

- [ ] **Step 5: web/routes の defpackage に import を追加**

`lisp-patch-form` で `web/routes.lisp` の `defpackage` を編集。`recurya/game/notebook` の import ブロックの直後に新しい import を追加:

- form_type: `defpackage`, form_name: `recurya/web/routes`
- old_text:
```
  (:import-from #:recurya/web/ui/notebook)
```
- new_text:
```
  (:import-from #:recurya/web/ui/notebook)
  (:import-from #:recurya/game/notebook-jsonb
                #:cell->jsonb-form
                #:jsonb-hash->cell)
```

- [ ] **Step 6: web/routes の2つの defun を削除**

`lisp-edit-form file_path="web/routes.lisp" form_type="defun" form_name="cell->jsonb-form" operation="delete"`
続けて `lisp-edit-form file_path="web/routes.lisp" form_type="defun" form_name="jsonb-hash->cell" operation="delete"`

（注: web/routes 内の `cell->jsonb-form`/`jsonb-hash->cell` 呼び出しは import により新モジュールのシンボルへ解決される。残った `cell-id` 等の import は未使用になっても無害なのでそのまま残す。）

- [ ] **Step 7: メインシステムを再ロード**

`load-system system="recurya" force=true`
Expected: `loaded successfully`、`cell->jsonb-form` の重複定義や name-conflict が出ないこと。

- [ ] **Step 8: 変換のスモーク確認（repl-eval）**

`repl-eval package="CL-USER"`:
```lisp
(let* ((nb (recurya/game/notebook-parser:parse-notebook-body
            (format nil "===prose===~%hi")))
       (h  (recurya/game/notebook-jsonb:cell->jsonb-form (first nb)))
       (c  (recurya/game/notebook-jsonb:jsonb-hash->cell h)))
  (list (gethash "kind" h)
        (recurya/game/notebook:cell-kind c)))
```
Expected: `("prose" :PROSE)`。

- [ ] **Step 9: 既存テストで回帰がないことを確認**

`run-tests system="recurya/tests/web/notebook-routes"`（PostgreSQL 必要）
Expected: 全 PASS（`recurya/web/routes::cell->jsonb-form` 参照が import 経由で解決）。
併せて `run-tests system="recurya/tests/game/notebook-parser"`（非DB）も PASS。

- [ ] **Step 10: コミット**

```bash
git add game/notebook-jsonb.lisp recurya.asd web/routes.lisp
git commit -m "refactor: move cell<->jsonb converters to recurya/game/notebook-jsonb" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: `recurya/seed/official-content` モジュール骨組み（struct・レジストリ・スタブ）

**Files:**
- Create: `seed/official-content.lisp`
- Modify: `recurya.asd`

- [ ] **Step 1: モジュール骨組みを作成**

`fs-write-file path="seed/official-content.lisp"`:

```lisp
;;;; seed/official-content.lisp --- Generic, idempotent seeding of
;;;; first-party ("official") courses from a declarative registry.
;;;;
;;;; Each entry in *official-courses* describes one official course: its
;;;; canonical author, course metadata, and a directory of markdown
;;;; notebook fixtures. seed-official-content! walks the registry and,
;;;; for each course, ensures the author user, the published-public
;;;; course, and the ordered notebooks all exist (find-or-create-or-
;;;; correct). It is idempotent and safe to run on every boot.
;;;;
;;;; SICP is simply the first registry entry. Adding a new official
;;;; course = add an official-course entry + drop its markdown directory.

(defpackage #:recurya/seed/official-content
  (:use #:cl)
  (:import-from #:recurya/db/users
                #:get-user-by-email
                #:get-user-by-handle
                #:create-user!)
  (:import-from #:recurya/models/users
                #:users-id
                #:users-handle)
  (:import-from #:recurya/db/courses
                #:create-course!
                #:get-course-by-slug)
  (:import-from #:recurya/models/course
                #:course-id
                #:course-slug
                #:course-status
                #:course-visibility
                #:course-published-at
                #:course-author)
  (:import-from #:recurya/db/notebooks
                #:create-notebook!
                #:get-notebook-by-slug)
  (:import-from #:recurya/models/notebook
                #:notebook-id
                #:notebook-author)
  (:import-from #:recurya/db/course-notebooks
                #:add-notebook-to-course!
                #:list-course-notebooks)
  (:import-from #:recurya/models/course-notebook
                #:course-notebook-notebook
                #:course-notebook-position)
  (:import-from #:recurya/game/notebook-parser
                #:parse-notebook-body)
  (:import-from #:recurya/game/notebook-jsonb
                #:cell->jsonb-form)
  (:import-from #:mito
                #:save-dao)
  (:export #:official-course
           #:make-official-course
           #:official-course-author-handle
           #:official-course-author-email
           #:official-course-author-display-name
           #:official-course-slug
           #:official-course-title
           #:official-course-summary
           #:official-course-content-dir
           #:official-course-order
           #:official-course-notebook-title-fn
           #:*official-courses*
           #:ensure-official-author
           #:ensure-official-course
           #:ensure-notebooks-attached
           #:seed-course!
           #:seed-official-content!))

(in-package #:recurya/seed/official-content)

;;;----------------------------------------------------------------------
;;; Data model
;;;----------------------------------------------------------------------

(defstruct official-course
  "Declarative description of one first-party (official) course."
  author-handle author-email author-display-name
  slug title summary
  content-dir                              ; system-relative pathname
  (order :natural)                         ; :natural | list of slugs
  (notebook-title-fn (lambda (slug) slug)))

;;;----------------------------------------------------------------------
;;; Registry
;;;----------------------------------------------------------------------

(defparameter *official-courses*
  (list
   (make-official-course
    :author-handle "recurya"
    :author-email "recurya+sicp@example.invalid"
    :author-display-name "Recurya"
    :slug "sicp"
    :title "SICP"
    :summary "Structure and Interpretation of Computer Programs (Japanese, ported to WardLisp)"
    :content-dir #P"docs/sicp/"
    :order :natural
    :notebook-title-fn (lambda (slug) (format nil "SICP ~A" slug))))
  "Registry of official courses. SICP is the first entry. Add a new
   official course by appending an OFFICIAL-COURSE here and placing its
   markdown notebooks under its content-dir.

   NOTE: the SICP entry's author-handle MUST stay in sync with
   RECURYA/WEB/ROUTES:+SICP-AUTHOR-HANDLE+ (the wardlisp redirect target
   /c/@recurya/sicp). A drift-guard test asserts this.")

;;;----------------------------------------------------------------------
;;; Stubs (implemented in later tasks)
;;;----------------------------------------------------------------------

(defun natural-string< (a b)
  (declare (ignore a b))
  (error "not implemented"))

(defun ensure-official-author (spec)
  (declare (ignore spec))
  (error "not implemented"))

(defun ensure-official-course (spec author)
  (declare (ignore spec author))
  (error "not implemented"))

(defun ensure-notebooks-attached (spec course author)
  (declare (ignore spec course author))
  (error "not implemented"))

(defun seed-course! (spec &key (attach-notebooks t))
  (declare (ignore spec attach-notebooks))
  (error "not implemented"))

(defun seed-official-content! (&key (courses *official-courses*))
  (declare (ignore courses))
  (error "not implemented"))
```

- [ ] **Step 2: パーサ健全性を確認**

`lisp-check-parens path="seed/official-content.lisp"`
Expected: バランスOK。

- [ ] **Step 3: メインシステムに登録**

`lisp-patch-form` で `recurya.asd` の `defsystem "recurya"` を編集。最後のエントリ `"recurya/web/server"` の直後（閉じ括弧の前）に Seed セクションを追加:

- form_type: `defsystem`, form_name: `recurya`
- old_text:
```
               "recurya/web/server")
```
- new_text:
```
               "recurya/web/server"
               ;; Seed / bootstrap
               "recurya/seed/official-content")
```

- [ ] **Step 4: ロード確認**

`load-system system="recurya/seed/official-content"`
Expected: `loaded successfully`、警告なし。

- [ ] **Step 5: コミット**

```bash
git add seed/official-content.lisp recurya.asd
git commit -m "feat: scaffold recurya/seed/official-content registry and stubs" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: `natural-string<` を TDD で実装

**Files:**
- Modify: `tests/integration/sicp-seed.lisp`（このタスクで新規骨組みに置換）
- Modify: `seed/official-content.lisp`

- [ ] **Step 1: テストファイルを新モジュール対象の骨組みに置換（非DBテストのみ先に）**

`fs-write-file path="tests/integration/sicp-seed.lisp"`（後続タスクで DB テストを追記する。まずは非DBの ordering テストのみ）:

```lisp
;;;; tests/integration/sicp-seed.lisp --- Integration tests for the
;;;; generic official-content seeder (recurya/seed/official-content).
;;;;
;;;; SICP is the first registry entry. These tests cover:
;;;;   * natural-string< ordering (non-DB)
;;;;   * drift guard between the SICP spec and the wardlisp redirect (non-DB)
;;;;   * SICP author/course seeding + idempotency (DB)
;;;;   * generic notebook attachment + natural ordering via fixtures (DB)
;;;;
;;;; The SICP author uses an @example.invalid email which is NOT swept by
;;;; cleanup-all-test-data (only @example.com); DB tests delete it in an
;;;; unwind-protect. The generic fixture author uses @example.com so it is
;;;; cleaned automatically. with-test-db wipes all course/notebook rows.

(defpackage #:recurya/tests/integration/sicp-seed
  (:use #:cl #:rove)
  (:import-from #:recurya/tests/support/db
                #:with-test-db)
  (:import-from #:recurya/db/users
                #:get-user-by-handle
                #:delete-user!)
  (:import-from #:recurya/models/users
                #:users-handle
                #:users-display-name
                #:users-email)
  (:import-from #:recurya/db/courses
                #:get-course-by-slug)
  (:import-from #:recurya/models/course
                #:course-id
                #:course-slug
                #:course-status
                #:course-visibility
                #:course-author)
  (:import-from #:recurya/db/course-notebooks
                #:count-course-notebooks
                #:list-course-notebooks)
  (:import-from #:recurya/models/course-notebook
                #:course-notebook-notebook
                #:course-notebook-position)
  (:import-from #:recurya/models/notebook
                #:notebook-slug)
  (:import-from #:recurya/seed/official-content
                #:*official-courses*
                #:make-official-course
                #:official-course-slug
                #:official-course-author-handle
                #:official-course-author-email
                #:seed-course!)
  (:import-from #:recurya/web/routes
                #:+sicp-author-handle+))

(in-package #:recurya/tests/integration/sicp-seed)

(defun sicp-spec ()
  "The SICP entry from the official-content registry."
  (find "sicp" *official-courses*
        :key #'official-course-slug :test #'string=))

;;;----------------------------------------------------------------------
;;; Non-DB tests
;;;----------------------------------------------------------------------

(deftest natural-string<-orders-numerically
  (testing "embedded digit runs compare numerically, not lexically"
    (ok (recurya/seed/official-content::natural-string< "demo-2" "demo-10"))
    (ok (not (recurya/seed/official-content::natural-string< "demo-10" "demo-2")))
    (ok (recurya/seed/official-content::natural-string< "sicp-1-2-1" "sicp-1-10-1"))
    (ok (recurya/seed/official-content::natural-string< "sicp-1-1-1" "sicp-1-1-2"))))

(deftest sicp-spec-matches-redirect-handle
  (testing "SICP registry entry stays in sync with the wardlisp redirect"
    (let ((spec (sicp-spec)))
      (ok spec "SICP must be present in *official-courses*")
      (ok (string= "sicp" (official-course-slug spec)))
      (ok (string= +sicp-author-handle+ (official-course-author-handle spec))
          "spec author-handle must equal +sicp-author-handle+ so
           /c/@recurya/sicp resolves"))))
```

- [ ] **Step 2: テスト実行 — natural-string< が失敗することを確認**

`run-tests system="recurya/tests/integration/sicp-seed" test="recurya/tests/integration/sicp-seed::natural-string<-orders-numerically"`
Expected: FAIL（`error "not implemented"`）。
（`sicp-spec-matches-redirect-handle` は既に PASS する想定。）

- [ ] **Step 3: `%split-natural` を `natural-string<` の直前に挿入**

`lisp-edit-form file_path="seed/official-content.lisp" form_type="defun" form_name="natural-string<" operation="insert_before"` content:

```lisp
(defun %split-natural (s)
  "Split S into alternating non-digit strings and integers.
   E.g. \"sicp-1-10\" -> (\"sicp-\" 1 \"-\" 10)."
  (let ((runs nil) (i 0) (n (length s)))
    (loop while (< i n) do
      (let ((digitp (and (digit-char-p (char s i)) t))
            (j i))
        (loop while (and (< j n)
                         (eq (and (digit-char-p (char s j)) t) digitp))
              do (incf j))
        (let ((chunk (subseq s i j)))
          (push (if digitp (parse-integer chunk) chunk) runs))
        (setf i j)))
    (nreverse runs)))
```

- [ ] **Step 4: `natural-string<` スタブを実装で置換**

`lisp-edit-form file_path="seed/official-content.lisp" form_type="defun" form_name="natural-string<" operation="replace"` content:

```lisp
(defun natural-string< (a b)
  "Total order over strings comparing embedded digit runs numerically,
   so \"x-2\" < \"x-10\". Ties break by overall string length."
  (loop for ra in (%split-natural a)
        for rb in (%split-natural b)
        do (cond
             ((and (integerp ra) (integerp rb))
              (when (< ra rb) (return-from natural-string< t))
              (when (> ra rb) (return-from natural-string< nil)))
             ((and (stringp ra) (stringp rb))
              (when (string< ra rb) (return-from natural-string< t))
              (when (string> ra rb) (return-from natural-string< nil)))
             ;; Different types at same position: integers sort first.
             (t (return-from natural-string< (integerp ra))))
        finally (return (< (length a) (length b)))))
```

- [ ] **Step 5: 再ロードしてテスト実行 — PASS**

`load-system system="recurya/seed/official-content" force=true` の後
`run-tests system="recurya/tests/integration/sicp-seed"`
Expected: `natural-string<-orders-numerically` と `sicp-spec-matches-redirect-handle` が PASS。

- [ ] **Step 6: コミット**

```bash
git add seed/official-content.lisp tests/integration/sicp-seed.lisp
git commit -m "feat: implement natural-string< ordering for official-content seeder" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: 汎用シードエンジン実装（DB統合テスト先行）

**Files:**
- Create: `tests/fixtures/official-course/demo-2.md`, `tests/fixtures/official-course/demo-10.md`
- Modify: `tests/integration/sicp-seed.lisp`（DBテスト追記）
- Modify: `seed/official-content.lisp`（エンジン実装）

- [ ] **Step 1: フィクスチャ2本を作成**

`Write path="tests/fixtures/official-course/demo-2.md"`（Markdown なので通常 Write 可）:
```
===prose===
Demo notebook two.
```
`Write path="tests/fixtures/official-course/demo-10.md"`:
```
===prose===
Demo notebook ten.
```

- [ ] **Step 2: DBテストをテストファイルに追記**

`lisp-edit-form file_path="tests/integration/sicp-seed.lisp" form_type="deftest" form_name="sicp-spec-matches-redirect-handle" operation="insert_after"` content（複数 deftest を1フォームに入れられないため、3つに分けて順に insert_after する。まず1つ目を insert_after し、以降は直前の deftest 名を form_name にして続ける）:

1つ目（SICP author/course）:
```lisp
(deftest seed-creates-recurya-author-and-published-public-course
  (testing "seeding the SICP spec creates the canonical recurya user and
            a published-public sicp course under it"
    (with-test-db
      (let ((spec (sicp-spec)))
        (unwind-protect
             (progn
               (seed-course! spec :attach-notebooks nil)
               (let ((u (get-user-by-handle +sicp-author-handle+)))
                 (ok u "recurya user must exist after seeding")
                 (ok (string= "Recurya" (users-display-name u)))
                 (ok (search "@example.invalid" (users-email u))
                     "seed user uses the .invalid TLD"))
               (let ((c (get-course-by-slug "sicp")))
                 (ok c "sicp course must exist")
                 (ok (string= "published" (course-status c)))
                 (ok (string= "public" (course-visibility c)))
                 (ok (string= +sicp-author-handle+
                              (users-handle (course-author c)))
                     "course author must be recurya")))
          (delete-user! (official-course-author-email spec)))))))
```

2つ目（冪等性）— form_name に1つ目の名前を指定して insert_after:
```lisp
(deftest seed-is-idempotent
  (testing "running seed-course! twice resolves to the same user/course
            rows (no duplicate inserts)"
    (with-test-db
      (let ((spec (sicp-spec)))
        (unwind-protect
             (let* ((r1 (seed-course! spec :attach-notebooks nil))
                    (r2 (seed-course! spec :attach-notebooks nil)))
               (ok (string= (getf r1 :user-id) (getf r2 :user-id))
                   "user UUID stable across runs")
               (ok (string= (getf r1 :course-id) (getf r2 :course-id))
                   "course UUID stable across runs")
               (ok (get-user-by-handle +sicp-author-handle+))
               (ok (get-course-by-slug "sicp")))
          (delete-user! (official-course-author-email spec)))))))
```

3つ目（汎用：順序付き添付）— form_name に2つ目の名前を指定して insert_after:
```lisp
(deftest generic-seed-attaches-notebooks-in-natural-order
  (testing "a non-SICP spec seeds author+course+ordered notebooks from a
            fixture dir, idempotently, with natural (numeric) ordering"
    (with-test-db
      ;; @example.com author is auto-cleaned by cleanup-all-test-data;
      ;; with-test-db wipes course/notebook rows. No unwind-protect needed.
      (let ((spec (make-official-course
                   :author-handle "demo-official"
                   :author-email "demo-official@example.com"
                   :author-display-name "Demo Official"
                   :slug "demo-course"
                   :title "Demo Course"
                   :summary "fixture"
                   :content-dir #P"tests/fixtures/official-course/"
                   :order :natural
                   :notebook-title-fn (lambda (slug) (format nil "Demo ~A" slug)))))
        (seed-course! spec)
        (seed-course! spec)                ; second run must be a no-op
        (let* ((c (get-course-by-slug "demo-course"))
               (rows (list-course-notebooks (course-id c)))
               (slugs (mapcar (lambda (cn)
                                (notebook-slug (course-notebook-notebook cn)))
                              rows)))
          (ok c "demo course must exist")
          (ok (= 2 (count-course-notebooks (course-id c)))
              "exactly two notebooks attached (idempotent across two runs)")
          (ok (equal '("demo-2" "demo-10") slugs)
              "notebooks attached in natural order (demo-2 before demo-10)")
          (ok (equal '(0 1) (mapcar #'course-notebook-position rows))
              "positions assigned 0,1 in order"))))))
```

- [ ] **Step 3: テスト実行 — DBテストが失敗することを確認**

`run-tests system="recurya/tests/integration/sicp-seed"`（PostgreSQL 必要）
Expected: 3つの DB テストが FAIL（`seed-course!` が `error "not implemented"`）。非DBの2つは PASS。

- [ ] **Step 4: エンジンの内部ヘルパを実装（スタブ置換の前に挿入）**

以下の各ヘルパ `defun` を、**それぞれ個別の** `lisp-edit-form file_path="seed/official-content.lisp" form_type="defun" form_name="ensure-official-author" operation="insert_before"` 呼び出しで挿入する（`lisp-edit-form` の `content` は1フォームのみ。同一ターゲットへの連続 insert_before は挿入順を保持するが、関数間に前方参照があっても CL では問題ないため順序は不問）。挿入する8つのヘルパ:

```lisp
(defun %same-user-p (a b)
  "T iff USER DAOs A and B denote the same row by id."
  (and a b (equal (princ-to-string (users-id a))
                  (princ-to-string (users-id b)))))

(defun %resolve-content-dir (content-dir)
  "Resolve CONTENT-DIR (system-relative pathname) against the recurya
   system root so seeding is independent of the process CWD."
  (asdf:system-relative-pathname :recurya content-dir))

(defun %content-markdown-files (content-dir order)
  "Return the *.md pathnames under CONTENT-DIR ordered by ORDER.
   ORDER is :natural (natural-string< by basename) or an explicit list
   of slugs (basenames without extension)."
  (let ((files (directory (merge-pathnames
                           "*.md" (%resolve-content-dir content-dir)))))
    (etypecase order
      (symbol
       (sort (copy-list files) #'natural-string< :key #'pathname-name))
      (list
       (let ((by-name (make-hash-table :test 'equal)))
         (dolist (f files) (setf (gethash (pathname-name f) by-name) f))
         (loop for slug in order
               for f = (gethash slug by-name)
               when f collect f))))))

(defun %read-file-string (path)
  "Read PATH into a UTF-8 string."
  (with-open-file (s path :direction :input :external-format :utf-8)
    (with-output-to-string (out)
      (loop for line = (read-line s nil nil)
            while line do (write-line line out)))))

(defun %correct-course-state! (course author)
  "Bring an existing COURSE to the canonical published-public-under-AUTHOR
   state if drifted. Returns COURSE."
  (let ((dirty nil))
    (unless (%same-user-p (course-author course) author)
      (setf (course-author course) author dirty t))
    (unless (string= (course-status course) "published")
      (setf (course-status course) "published" dirty t))
    (unless (string= (course-visibility course) "public")
      (setf (course-visibility course) "public" dirty t))
    (unless (course-published-at course)
      (setf (course-published-at course) (local-time:now) dirty t))
    (when dirty (save-dao course))
    course))

(defun %already-attached-p (course-id-uuid notebook-id-uuid)
  "T when (course, notebook) is already in course_notebook."
  (let ((target (princ-to-string notebook-id-uuid)))
    (some (lambda (cn)
            (let ((nb (course-notebook-notebook cn)))
              (and nb (string= (princ-to-string (notebook-id nb)) target))))
          (list-course-notebooks course-id-uuid))))

(defun %next-position (course-id-uuid)
  "Next free position (one past the current max) for COURSE-ID-UUID."
  (let ((rows (list-course-notebooks course-id-uuid)))
    (if rows
        (1+ (reduce #'max rows :key #'course-notebook-position))
        0)))

(defun %ensure-notebook-row (slug body-md title author)
  "Find or create a published-public notebook keyed by SLUG, owned by
   AUTHOR. Returns (values NB CREATED-P CORRECTED-P)."
  (let ((existing (get-notebook-by-slug slug)))
    (cond
      ((and existing (%same-user-p (notebook-author existing) author))
       (values existing nil nil))
      (existing
       (setf (notebook-author existing) author)
       (save-dao existing)
       (values existing nil t))
      (t
       (multiple-value-bind (cells parse-errors) (parse-notebook-body body-md)
         (when parse-errors
           (error "official-content: parse errors in ~A: ~S" slug parse-errors))
         (values (create-notebook!
                  :title title :slug slug :body-md body-md
                  :cells (mapcar #'cell->jsonb-form cells)
                  :author author :status "published" :visibility "public"
                  :published-at (local-time:now))
                 t nil))))))
```

- [ ] **Step 5: `ensure-official-author` を実装**

`lisp-edit-form ... form_name="ensure-official-author" operation="replace"`:
```lisp
(defun ensure-official-author (spec)
  "Ensure the author user for SPEC exists; return the USER DAO.
   Lookup by handle, then by email (warn if handle differs), else create."
  (or (get-user-by-handle (official-course-author-handle spec))
      (let ((by-email (get-user-by-email (official-course-author-email spec))))
        (cond
          (by-email
           (warn "ensure-official-author: a user with email ~A exists but ~
                  its handle is ~S (expected ~S); leaving it alone."
                 (official-course-author-email spec)
                 (users-handle by-email)
                 (official-course-author-handle spec))
           by-email)
          (t
           (create-user! :email (official-course-author-email spec)
                         :handle (official-course-author-handle spec)
                         :display-name (official-course-author-display-name spec)
                         :role "user"))))))
```

- [ ] **Step 6: `ensure-official-course` を実装**

`lisp-edit-form ... form_name="ensure-official-course" operation="replace"`:
```lisp
(defun ensure-official-course (spec author)
  "Return the canonical course for SPEC, creating it if missing and
   correcting its state if it already exists."
  (let ((existing (get-course-by-slug (official-course-slug spec))))
    (if existing
        (%correct-course-state! existing author)
        (create-course! :title (official-course-title spec)
                        :slug (official-course-slug spec)
                        :summary (official-course-summary spec)
                        :status "published"
                        :visibility "public"
                        :published-at (local-time:now)
                        :author author))))
```

- [ ] **Step 7: `ensure-notebooks-attached` を実装**

`lisp-edit-form ... form_name="ensure-notebooks-attached" operation="replace"`:
```lisp
(defun ensure-notebooks-attached (spec course author)
  "Ensure every markdown file under SPEC's content-dir is a published-
   public notebook owned by AUTHOR and attached to COURSE in order.
   Returns a summary plist."
  (let ((course-id-uuid (course-id course))
        (imported nil) (corrected nil) (skipped nil)
        (attached nil) (already nil))
    (dolist (path (%content-markdown-files (official-course-content-dir spec)
                                           (official-course-order spec)))
      (let* ((slug (pathname-name path))
             (body-md (%read-file-string path))
             (title (funcall (official-course-notebook-title-fn spec) slug)))
        (multiple-value-bind (nb created-p corrected-p)
            (%ensure-notebook-row slug body-md title author)
          (cond (created-p   (push slug imported))
                (corrected-p (push slug corrected))
                (t           (push slug skipped)))
          (let ((nb-uuid (notebook-id nb)))
            (if (%already-attached-p course-id-uuid nb-uuid)
                (push slug already)
                (progn
                  (add-notebook-to-course! course-id-uuid nb-uuid
                                           :position (%next-position course-id-uuid))
                  (push slug attached)))))))
    (list :imported (nreverse imported)
          :corrected (nreverse corrected)
          :skipped (nreverse skipped)
          :attached (nreverse attached)
          :already-attached (nreverse already))))
```

- [ ] **Step 8: `seed-course!` を実装**

`lisp-edit-form ... form_name="seed-course!" operation="replace"`:
```lisp
(defun seed-course! (spec &key (attach-notebooks t))
  "Idempotently seed one official course described by SPEC.
   Returns a summary plist."
  (let* ((author (ensure-official-author spec))
         (course (ensure-official-course spec author))
         (nb-summary (when attach-notebooks
                       (ensure-notebooks-attached spec course author))))
    (list :slug (official-course-slug spec)
          :user-handle (users-handle author)
          :user-id (princ-to-string (users-id author))
          :course-id (princ-to-string (course-id course))
          :notebooks nb-summary)))
```

- [ ] **Step 9: `seed-official-content!` を実装**

`lisp-edit-form ... form_name="seed-official-content!" operation="replace"`:
```lisp
(defun seed-official-content! (&key (courses *official-courses*))
  "Idempotently seed every official course in COURSES (default
   *official-courses*). Each course is isolated: a failure in one is
   logged and the rest continue. Returns per-course summaries."
  (loop for spec in courses
        collect (handler-case (seed-course! spec)
                  (error (e)
                    (format t "~&[official-content] WARN: course ~A failed: ~A~%"
                            (official-course-slug spec) e)
                    (list :slug (official-course-slug spec)
                          :error (princ-to-string e))))))
```

- [ ] **Step 10: 再ロードしてテスト実行 — 全 PASS**

`load-system system="recurya/seed/official-content" force=true` の後
`run-tests system="recurya/tests/integration/sicp-seed"`（PostgreSQL 必要）
Expected: 非DB 2件 + DB 3件すべて PASS。失敗時は root cause を調べて修正（テストやワークアラウンドで誤魔化さない）。

- [ ] **Step 11: コミット**

```bash
git add seed/official-content.lisp tests/integration/sicp-seed.lisp tests/fixtures/official-course/
git commit -m "feat: implement generic official-content seeding engine with tests" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: 起動時自動シードの結線・手動ラッパ・旧スクリプト撤去

**Files:**
- Modify: `docker-entrypoint.sh`
- Create: `scripts/seed-official-content.lisp`
- Delete: `scripts/seed-sicp.lisp`

- [ ] **Step 1: entrypoint に自動シードを追加**

`Edit path="docker-entrypoint.sh"`（シェルスクリプトなので通常 Edit 可）。`(recurya/db/core:start!)` とその直後の "Database connection established" ブロックの後、`(recurya/web/server:start! :port 3000)` の前に挿入。

old_string:
```
    --eval "(recurya/db/core:start!)" \
    --eval "(format t \"Database connection established~%\")" \
    --eval "(force-output)" \
    --eval "(recurya/web/server:start! :port 3000)" \
```
new_string:
```
    --eval "(recurya/db/core:start!)" \
    --eval "(format t \"Database connection established~%\")" \
    --eval "(force-output)" \
    --eval "(handler-case (recurya/seed/official-content:seed-official-content!) (error (e) (format t \"~&[seed] WARN: ~A~%\" e)))" \
    --eval "(format t \"Official content seeded~%\")" \
    --eval "(force-output)" \
    --eval "(recurya/web/server:start! :port 3000)" \
```

- [ ] **Step 2: 手動実行ラッパを作成**

`fs-write-file path="scripts/seed-official-content.lisp"`:
```lisp
;;;; scripts/seed-official-content.lisp --- Manual one-shot runner for the
;;;; official-content seeder. Auto-seed normally runs at boot via
;;;; docker-entrypoint.sh; use this for ad-hoc / CI runs.
;;;;
;;;; Usage (from project root, DB reachable):
;;;;   $ qlot exec ros run \
;;;;       -e '(asdf:load-system :recurya)' \
;;;;       -e '(load "scripts/seed-official-content.lisp")' \
;;;;       -q
;;;;
;;;; or from a connected REPL:
;;;;   (load "scripts/seed-official-content.lisp")

(asdf:load-system :recurya)
(unless (recurya/db/core:datasource)
  (recurya/db/core:start!))
(format t "~&~S~%" (recurya/seed/official-content:seed-official-content!))
```

- [ ] **Step 3: パーサ健全性を確認**

`lisp-check-parens path="scripts/seed-official-content.lisp"`
Expected: バランスOK。

- [ ] **Step 4: 旧シードスクリプトを削除**

```bash
git rm scripts/seed-sicp.lisp
```
（参照していた `tests/integration/sicp-seed.lisp` は Task 3/4 で新モジュール対象に書き換え済み。他の参照は `docs/plans/` のみ。）

- [ ] **Step 5: フルロードで健全性確認**

`load-system system="recurya" force=true`
Expected: `loaded successfully`、警告・name-conflict なし。`recurya/seed/official-content` が `:recurya` 経由でロードされること。

- [ ] **Step 6: コミット**

```bash
git add docker-entrypoint.sh scripts/seed-official-content.lisp
git commit -m "feat: auto-seed official content at boot; replace seed-sicp script" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: 全スイート通し ＋ 手動スモーク検証

**Files:** なし（検証のみ）

- [ ] **Step 1: 関連システムを強制コンパイルして警告を洗い出す**

`repl-eval code="(asdf:compile-system :recurya :force t)" timeout_seconds=300`
Expected: エラーなし。新規 style-warning が出たら修正。

- [ ] **Step 2: 全テストスイート実行（PostgreSQL 必要）**

```bash
.qlot/bin/rove recurya.asd
```
Expected: 全 PASS、exit code 0。特に `recurya/tests/integration/sicp-seed`、`recurya/tests/integration/sicp-canonical-solutions`、`recurya/tests/web/notebook-routes` が PASS。

- [ ] **Step 3: 開発環境で手動シードを実行し DB を確認**

接続中の REPL（`recurya/db/core:start!` 済み）で:
`repl-eval code="(recurya/seed/official-content:seed-official-content!)" timeout_seconds=120`
Expected: SICP コースのサマリ（`:attached` に56 slug、再実行時は `:already-attached` に56）。

確認クエリ（repl-eval）:
```lisp
(let ((c (recurya/db/courses:get-course-by-slug "sicp")))
  (list :status (recurya/models/course:course-status c)
        :visibility (recurya/models/course:course-visibility c)
        :count (recurya/db/course-notebooks:count-course-notebooks
                (recurya/models/course:course-id c))))
```
Expected: `(:status "published" :visibility "public" :count 56)`。

- [ ] **Step 4: 公開ページの手動スモーク**

ブラウザ/curl で（サーバ起動中）:
- `GET /c/@recurya/sicp` → 200、56 ノートブックが並ぶ
- `GET /courses` → SICP が一覧に出る
- `GET /wardlisp/learn` → 301 → `/c/@recurya/sicp`
- `GET /@recurya/sicp-1-1-1` → 200（公開ノートブック）

- [ ] **Step 5: 冪等性の最終確認**

`repl-eval code="(recurya/seed/official-content:seed-official-content!)"` を再実行し、コース/ノートブック数が増えない（重複なし）ことを Step 3 のクエリで確認。

- [ ] **Step 6: ブランチ完了処理**

REQUIRED SUB-SKILL: superpowers:finishing-a-development-branch を使い、マージ/PR/クリーンアップの方針をユーザーに確認する。

---

## 完了基準

- [ ] 全テスト（既存＋新規）PASS、`compile-system :force t` 警告なし
- [ ] `recurya/seed/official-content` が `:recurya` の一部としてロードされ、起動時に自動シードされる
- [ ] `seed-official-content!` 冪等（再実行で重複ゼロ）
- [ ] SICP が `/c/@recurya/sicp`（56本）・`/courses` に出る、旧 `/wardlisp/learn` が 301
- [ ] 汎用テスト（合成フィクスチャ）で SICP 非依存・自然順序が検証される
- [ ] `scripts/seed-sicp.lisp` 撤去、`scripts/seed-official-content.lisp` で手動実行可

## 自己レビュー結果（spec カバレッジ）

- 設計 §1 新モジュール → Task 2 ✓
- 設計 §2 データモデル/レジストリ → Task 2 ✓
- 設計 §3 汎用エンジン → Task 3（ordering）+ Task 4（author/course/notebook/entry）✓
- 設計 §4 converter 移設 → Task 1 ✓
- 設計 §5 起動時自動シード → Task 5 ✓
- 設計 §6 スクリプト撤去・テスト書き換え（drift guard・汎用テスト含む）→ Task 3/4/5 ✓
- 設計 §8 検証 → Task 6 ✓
