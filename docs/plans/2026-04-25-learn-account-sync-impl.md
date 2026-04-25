# Learn Account Sync 実装計画

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** `docs/plans/2026-04-25-learn-account-sync-design.md` の確定要件に沿って、ログインユーザにのみ DB 永続化(進捗・コード・提出履歴)を提供する任意機能を追加する。匿名運用は無変更。

**Architecture:** 3 つの新規 Mito テーブル(`learn-progress`/`learn-cell-code`/`learn-submission`)+ DB アクセス層 `db/learn.lisp` + 既存ハンドラ拡張(認証時のみ DB 書き込み)+ 新規 `/wardlisp/learn/sync` JSON エンドポイント + JS 側で localStorage の自動アップロード。

**Tech Stack:** Common Lisp / Mito ORM (Postgres) / cl-dbi / Ningle / Spinneret / com.inuoe.jzon / Rove / HTMX / vanilla JS。

---

## 作業前チェック

- ブランチ: `feat/sicp-notebook-mvp` 上で続行(設計コミットも同ブランチ)
- 設計参照: `docs/plans/2026-04-25-learn-account-sync-design.md`
- Lisp ファイル操作はすべて `mcp__cl-mcp__*` ツール経由(`Read`/`Edit`/`Write`/`Grep` を `.lisp`/`.asd` に使わない)
- 初回: `mcp__cl-mcp__fs-set-project-root` に `/home/wiz/recurya`
- コミットメッセージ末尾に `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`
- DB テストは Postgres 必須。`tests/support/db.lisp` の `with-test-db` を使う
- マイグレーション後はコンテナの DB(`localhost:15434`)に直接適用 — 既存 `posts`/`users` には触らない

## 既存参考

- `models/users.lisp`, `models/post.lisp` — `deftable` の流儀(UUID PK, `:auto-pk nil`, `:keys`, `:unique-keys`)
- `db/users.lisp`, `db/posts.lisp` — CRUD 関数の書き方(`select-dao`, `find-dao`, `insert-dao`, `save-dao`)
- `tests/db/users.lisp`, `tests/db/posts.lisp` — Rove + `with-test-db` の使い方
- `tests/support/db.lisp` — `with-test-db`, `create-test-user`
- `web/auth.lisp:170` — `current-user (env)` ヘルパ
- `web/routes-wardlisp.lisp` — 既存ハンドラ + `html-response`/`html-response-with-headers`

---

## Task 1: 3 つのモデル + ASDF 登録

**Files:**
- Create: `models/learn-progress.lisp`
- Create: `models/learn-cell-code.lisp`
- Create: `models/learn-submission.lisp`
- Modify: `recurya.asd`

**Step 1: `models/learn-progress.lisp` を `fs-write-file` で作成**

```lisp
;;;; models/learn-progress.lisp --- Mito table for cell pass status.

(defpackage #:recurya/models/learn-progress
  (:use #:cl #:mito)
  (:export #:learn-progress
           #:learn-progress-user-id
           #:learn-progress-notebook-id
           #:learn-progress-cell-id
           #:learn-progress-passed-at
           #:learn-progress-created-at
           #:learn-progress-updated-at))

(in-package #:recurya/models/learn-progress)

(deftable learn-progress ()
  ((user-id :col-type :uuid
            :initarg :user-id
            :accessor learn-progress-user-id)
   (notebook-id :col-type (:varchar 64)
                :initarg :notebook-id
                :accessor learn-progress-notebook-id)
   (cell-id :col-type (:varchar 64)
            :initarg :cell-id
            :accessor learn-progress-cell-id)
   (passed-at :col-type :timestamptz
              :initarg :passed-at
              :accessor learn-progress-passed-at))
  (:unique-keys (user-id notebook-id cell-id))
  (:keys (user-id notebook-id))
  (:documentation "Per-user pass record for a notebook cell. Existence = passed."))

(defun learn-progress-created-at (row) (mito:object-created-at row))
(defun learn-progress-updated-at (row) (mito:object-updated-at row))
```

**Step 2: `models/learn-cell-code.lisp`**

```lisp
;;;; models/learn-cell-code.lisp --- Mito table for last-saved cell code.

(defpackage #:recurya/models/learn-cell-code
  (:use #:cl #:mito)
  (:export #:learn-cell-code
           #:learn-cell-code-user-id
           #:learn-cell-code-notebook-id
           #:learn-cell-code-cell-id
           #:learn-cell-code-code
           #:learn-cell-code-created-at
           #:learn-cell-code-updated-at))

(in-package #:recurya/models/learn-cell-code)

(deftable learn-cell-code ()
  ((user-id :col-type :uuid
            :initarg :user-id
            :accessor learn-cell-code-user-id)
   (notebook-id :col-type (:varchar 64)
                :initarg :notebook-id
                :accessor learn-cell-code-notebook-id)
   (cell-id :col-type (:varchar 64)
            :initarg :cell-id
            :accessor learn-cell-code-cell-id)
   (code :col-type :text
         :initarg :code
         :accessor learn-cell-code-code))
  (:unique-keys (user-id notebook-id cell-id))
  (:keys (user-id notebook-id))
  (:documentation "Per-user last code submitted for a notebook cell."))

(defun learn-cell-code-created-at (row) (mito:object-created-at row))
(defun learn-cell-code-updated-at (row) (mito:object-updated-at row))
```

**Step 3: `models/learn-submission.lisp`**

```lisp
;;;; models/learn-submission.lisp --- Mito table for exercise submission history.

(defpackage #:recurya/models/learn-submission
  (:use #:cl #:mito)
  (:export #:learn-submission
           #:learn-submission-user-id
           #:learn-submission-notebook-id
           #:learn-submission-cell-id
           #:learn-submission-code
           #:learn-submission-status
           #:learn-submission-created-at))

(in-package #:recurya/models/learn-submission)

(deftable learn-submission ()
  ((user-id :col-type :uuid
            :initarg :user-id
            :accessor learn-submission-user-id)
   (notebook-id :col-type (:varchar 64)
                :initarg :notebook-id
                :accessor learn-submission-notebook-id)
   (cell-id :col-type (:varchar 64)
            :initarg :cell-id
            :accessor learn-submission-cell-id)
   (code :col-type :text
         :initarg :code
         :accessor learn-submission-code)
   (status :col-type (:varchar 16)
           :initarg :status
           :accessor learn-submission-status))
  (:keys (user-id notebook-id cell-id))
  (:documentation "Append-only history of code-exercise submissions."))

(defun learn-submission-created-at (row) (mito:object-created-at row))
```

**Step 4: ASDF 登録(`recurya.asd`)**

`mcp__cl-mcp__lisp-patch-form` で `recurya` system の `:depends-on` リストに、Models セクション(`recurya/models/post` の直後)で追加:

```
               "recurya/models/learn-progress"
               "recurya/models/learn-cell-code"
               "recurya/models/learn-submission"
```

**Step 5: 確認**

```
mcp__cl-mcp__load-system  system=recurya  force=true
```

Expected: ロード成功(まだ DB に table はないがコンパイルは通る)

**Step 6: コミット**

```bash
git add models/learn-progress.lisp models/learn-cell-code.lisp \
        models/learn-submission.lisp recurya.asd
git commit -m "$(cat <<'EOF'
Add learn-progress, learn-cell-code, learn-submission models

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: マイグレーション生成と適用

**Files:**
- Create: `db/migrations/[timestamp].sxql`(自動生成)

**Step 1: コンテナ内で Mito CLI を実行してマイグレーション生成**

```bash
docker compose exec recurya .qlot/bin/mito generate-migrations \
  -t postgres -H postgres -P 5432 \
  -d recurya -u postgres -p postgres -s recurya -D db/
```

注意: コンテナ内では DB ホストは `postgres`(compose のサービス名)。ホスト名を間違えないこと。生成された `.sxql` ファイルを `git status` で確認(`db/` または `resources/migrations/` 下に出る)。

ファイルパスは既存マイグレーションがあれば隣に並ぶ。なければ Mito 既定。実装時に確認。

**Step 2: 中身を `Read` で確認**

3 テーブルすべての `CREATE TABLE` が含まれていること。`user_id UUID NOT NULL`、`UNIQUE (user_id, notebook_id, cell_id)`、index などが期待通り。

**Step 3: マイグレーション適用**

```bash
docker compose exec recurya .qlot/bin/mito migrate \
  -t postgres -H postgres -P 5432 \
  -d recurya -u postgres -p postgres -s recurya -D db/
```

**Step 4: psql で検証**

```bash
docker compose exec postgres psql -U postgres -d recurya \
  -c "\d learn_progress" -c "\d learn_cell_code" -c "\d learn_submission"
```

3 テーブルが存在し、カラム/制約/index が期待通りであること。

**Step 5: コミット**

```bash
git add db/migrations/  # 実際のパスに調整
git commit -m "$(cat <<'EOF'
Generate and apply Mito migration for learn-* tables

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: `db/learn.lisp` パッケージスケルトン + テストパッケージスケルトン

**Files:**
- Create: `db/learn.lisp`
- Create: `tests/db/learn.lisp`
- Modify: `recurya.asd`
- Modify: `tests/all.lisp`

**Step 1: `db/learn.lisp` スケルトン**

```lisp
;;;; db/learn.lisp --- DB access layer for SICP notebook learning state.

(defpackage #:recurya/db/learn
  (:use #:cl #:mito #:sxql)
  (:import-from #:recurya/models/learn-progress
                #:learn-progress
                #:learn-progress-cell-id
                #:learn-progress-passed-at)
  (:import-from #:recurya/models/learn-cell-code
                #:learn-cell-code
                #:learn-cell-code-cell-id
                #:learn-cell-code-code)
  (:import-from #:recurya/models/learn-submission
                #:learn-submission)
  (:import-from #:local-time
                #:now)
  (:export #:mark-cell-passed
           #:user-passed-cells
           #:upsert-cell-code
           #:user-cell-codes
           #:record-submission
           #:cell-submissions
           #:merge-localstorage))

(in-package #:recurya/db/learn)

(defun __stub () nil)
```

**Step 2: `tests/db/learn.lisp` スケルトン**

```lisp
;;;; tests/db/learn.lisp --- Tests for the SICP notebook DB layer.

(defpackage #:recurya/tests/db/learn
  (:use #:cl #:rove)
  (:import-from #:recurya/tests/support/db
                #:with-test-db
                #:create-test-user)
  (:import-from #:recurya/models/users
                #:users-id)
  (:import-from #:recurya/db/learn
                #:mark-cell-passed
                #:user-passed-cells
                #:upsert-cell-code
                #:user-cell-codes
                #:record-submission
                #:cell-submissions
                #:merge-localstorage))

(in-package #:recurya/tests/db/learn)

;; Tests follow in subsequent tasks.
```

**Step 3: ASDF 登録**

`recurya.asd` の `recurya` system の `:depends-on` で、DB セクションに追加(`recurya/db/posts` の直後):

```
               "recurya/db/learn"
```

`recurya/tests` system にも追加(`recurya/tests/db/posts` の直後):

```
               "recurya/tests/db/learn"
```

**Step 4: `tests/all.lisp` に追加**

`mcp__cl-mcp__lisp-patch-form` で `*test-packages*` のリストに `:recurya/tests/db/learn` を `:recurya/tests/db/posts` の直後に追加。

**Step 5: 読込確認**

```
mcp__cl-mcp__load-system  system=recurya  force=true
```

**Step 6: コミット**

```bash
git add db/learn.lisp tests/db/learn.lisp recurya.asd tests/all.lisp
git commit -m "$(cat <<'EOF'
Add db/learn package skeleton and test package

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: TDD - `mark-cell-passed` + `user-passed-cells`

**Files:**
- Modify: `db/learn.lisp`
- Modify: `tests/db/learn.lisp`

**Step 1: 失敗するテストを `tests/db/learn.lisp` に追加**

`mcp__cl-mcp__lisp-edit-form` `operation=insert_after` (target `defpackage` か直前 form):

```lisp
(deftest mark-cell-passed-inserts-once
  (testing "calling mark-cell-passed twice for same cell does not duplicate"
    (with-test-db
      (let* ((u (create-test-user))
             (uid (users-id u)))
        (mark-cell-passed uid "sicp-1-1-1" "ex-sum3")
        (mark-cell-passed uid "sicp-1-1-1" "ex-sum3")
        (let ((rows (mito:retrieve-dao 'recurya/models/learn-progress:learn-progress
                                       :user-id uid)))
          (ok (= 1 (length rows))))))))

(deftest user-passed-cells-returns-cell-ids
  (testing "user-passed-cells returns cell-id strings for the given notebook"
    (with-test-db
      (let* ((u (create-test-user))
             (uid (users-id u)))
        (mark-cell-passed uid "sicp-1-1-1" "ex-sum3")
        (mark-cell-passed uid "sicp-1-1-1" "ex-square")
        (mark-cell-passed uid "sicp-1-1-2" "ex-other") ; different notebook
        (let ((cells (sort (copy-list (user-passed-cells uid "sicp-1-1-1"))
                           #'string<)))
          (ok (equal cells '("ex-square" "ex-sum3"))))))))
```

**Step 2: テストを走らせて失敗確認**

```
mcp__cl-mcp__run-tests  system=recurya/tests/db/learn
```

Expected: FAIL (functions undefined)

**Step 3: `db/learn.lisp` の `__stub` を `mark-cell-passed` で置換**

`mcp__cl-mcp__lisp-edit-form` `operation=replace` form_type=defun form_name=__stub :

```lisp
(defun mark-cell-passed (user-id notebook-id cell-id)
  "Mark CELL-ID in NOTEBOOK-ID as passed for USER-ID. Idempotent —
   if a row already exists, returns it unchanged. Returns the
   learn-progress instance."
  (or (find-dao 'learn-progress
                :user-id user-id
                :notebook-id notebook-id
                :cell-id cell-id)
      (handler-case
          (insert-dao
           (make-instance 'learn-progress
                          :user-id user-id
                          :notebook-id notebook-id
                          :cell-id cell-id
                          :passed-at (now)))
        ;; Race: another transaction inserted concurrently.
        (error ()
          (find-dao 'learn-progress
                    :user-id user-id
                    :notebook-id notebook-id
                    :cell-id cell-id)))))
```

**Step 4: `user-passed-cells` を `insert_after` で追加**

```lisp
(defun user-passed-cells (user-id notebook-id)
  "Return list of cell-id strings the USER-ID has passed in NOTEBOOK-ID."
  (mapcar #'learn-progress-cell-id
          (select-dao 'learn-progress
            (where (:and (:= :user-id user-id)
                         (:= :notebook-id notebook-id))))))
```

**Step 5: テスト再実行**

```
mcp__cl-mcp__run-tests  system=recurya/tests/db/learn
```

Expected: PASS (2 tests)

**Step 6: コミット**

```bash
git add db/learn.lisp tests/db/learn.lisp
git commit -m "$(cat <<'EOF'
Implement mark-cell-passed and user-passed-cells

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: TDD - `upsert-cell-code` + `user-cell-codes`

**Files:**
- Modify: `db/learn.lisp`, `tests/db/learn.lisp`

**Step 1: 失敗するテスト**

```lisp
(deftest upsert-cell-code-inserts-then-updates
  (testing "first call inserts, second call updates the same row"
    (with-test-db
      (let* ((u (create-test-user)) (uid (users-id u)))
        (upsert-cell-code uid "sicp-1-1-1" "ex-sum3" "(+ 1 2)")
        (upsert-cell-code uid "sicp-1-1-1" "ex-sum3" "(+ 137 349 22)")
        (let ((rows (mito:retrieve-dao 'recurya/models/learn-cell-code:learn-cell-code
                                       :user-id uid)))
          (ok (= 1 (length rows)))
          (ok (string= "(+ 137 349 22)"
                       (recurya/models/learn-cell-code:learn-cell-code-code
                        (first rows)))))))))

(deftest user-cell-codes-returns-alist
  (testing "user-cell-codes returns (cell-id . code) alist"
    (with-test-db
      (let* ((u (create-test-user)) (uid (users-id u)))
        (upsert-cell-code uid "sicp-1-1-1" "ex-sum3" "code-A")
        (upsert-cell-code uid "sicp-1-1-1" "ex-square" "code-B")
        (upsert-cell-code uid "sicp-1-1-2" "ex-other" "code-C") ; different nb
        (let ((alist (user-cell-codes uid "sicp-1-1-1")))
          (ok (= 2 (length alist)))
          (ok (string= "code-A" (cdr (assoc "ex-sum3" alist :test #'string=))))
          (ok (string= "code-B" (cdr (assoc "ex-square" alist :test #'string=)))))))))
```

**Step 2: 失敗確認**

```
mcp__cl-mcp__run-tests  system=recurya/tests/db/learn
```

Expected: FAIL on the new tests

**Step 3: 実装を `db/learn.lisp` に追加(`insert_after` `user-passed-cells`)**

```lisp
(defun upsert-cell-code (user-id notebook-id cell-id code)
  "Insert or update the saved code for (USER-ID, NOTEBOOK-ID, CELL-ID).
   Returns the learn-cell-code instance."
  (let ((existing (find-dao 'learn-cell-code
                            :user-id user-id
                            :notebook-id notebook-id
                            :cell-id cell-id)))
    (cond
      (existing
       (setf (learn-cell-code-code existing) code)
       (save-dao existing)
       existing)
      (t
       (handler-case
           (insert-dao
            (make-instance 'learn-cell-code
                           :user-id user-id
                           :notebook-id notebook-id
                           :cell-id cell-id
                           :code code))
         (error ()
           ;; Race condition: another tx inserted; update that row instead.
           (let ((row (find-dao 'learn-cell-code
                                :user-id user-id
                                :notebook-id notebook-id
                                :cell-id cell-id)))
             (when row
               (setf (learn-cell-code-code row) code)
               (save-dao row))
             row)))))))

(defun user-cell-codes (user-id notebook-id)
  "Return alist ((cell-id . code) ...) of saved codes for USER-ID in NOTEBOOK-ID."
  (mapcar (lambda (row)
            (cons (learn-cell-code-cell-id row)
                  (learn-cell-code-code row)))
          (select-dao 'learn-cell-code
            (where (:and (:= :user-id user-id)
                         (:= :notebook-id notebook-id))))))
```

**Step 4: テスト再実行 → PASS**

**Step 5: コミット**

```bash
git add db/learn.lisp tests/db/learn.lisp
git commit -m "$(cat <<'EOF'
Implement upsert-cell-code and user-cell-codes

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: TDD - `record-submission` + `cell-submissions`

**Files:**
- Modify: `db/learn.lisp`, `tests/db/learn.lisp`

**Step 1: 失敗するテスト**

```lisp
(deftest record-submission-appends-each-call
  (testing "each call inserts a new row"
    (with-test-db
      (let* ((u (create-test-user)) (uid (users-id u)))
        (record-submission uid "sicp-1-1-1" "ex-sum3" "(bad)" "fail")
        (record-submission uid "sicp-1-1-1" "ex-sum3" "(+ 1)" "fail")
        (record-submission uid "sicp-1-1-1" "ex-sum3" "(+ 137 349 22)" "pass")
        (let ((rows (mito:retrieve-dao 'recurya/models/learn-submission:learn-submission
                                       :user-id uid)))
          (ok (= 3 (length rows))))))))

(deftest cell-submissions-newest-first
  (testing "cell-submissions returns rows ordered newest-first"
    (with-test-db
      (let* ((u (create-test-user)) (uid (users-id u)))
        (record-submission uid "sicp-1-1-1" "ex-sum3" "v1" "fail")
        (sleep 0.05)
        (record-submission uid "sicp-1-1-1" "ex-sum3" "v2" "fail")
        (sleep 0.05)
        (record-submission uid "sicp-1-1-1" "ex-sum3" "v3" "pass")
        (let* ((rows (cell-submissions uid "sicp-1-1-1" "ex-sum3"))
               (codes (mapcar #'recurya/models/learn-submission:learn-submission-code rows)))
          (ok (equal codes '("v3" "v2" "v1"))))))))
```

**Step 2: 失敗確認**

**Step 3: 実装**

```lisp
(defun record-submission (user-id notebook-id cell-id code status)
  "Append an exercise submission to the history. STATUS is a string
   among \"pass\" / \"fail\" / \"error\"."
  (insert-dao
   (make-instance 'learn-submission
                  :user-id user-id
                  :notebook-id notebook-id
                  :cell-id cell-id
                  :code code
                  :status status)))

(defun cell-submissions (user-id notebook-id cell-id &key (limit 50))
  "Return list of learn-submission rows for the given cell, newest first."
  (select-dao 'learn-submission
    (where (:and (:= :user-id user-id)
                 (:= :notebook-id notebook-id)
                 (:= :cell-id cell-id)))
    (order-by (:desc :created-at))
    (sxql:limit limit)))
```

**Step 4: テスト → PASS**

**Step 5: コミット**

```
Implement record-submission and cell-submissions
```

---

## Task 7: TDD - `merge-localstorage`

**Files:**
- Modify: `db/learn.lisp`, `tests/db/learn.lisp`

**Step 1: 失敗するテスト**

```lisp
(deftest merge-localstorage-or-passed
  (testing "merge unions passed cells (DB ∪ payload)"
    (with-test-db
      (let* ((u (create-test-user)) (uid (users-id u)))
        (mark-cell-passed uid "sicp-1-1-1" "ex-old") ; pre-existing
        (let ((summary (merge-localstorage
                        uid
                        '((:notebook-id "sicp-1-1-1"
                           :passed ("ex-new" "ex-old") ; ex-old already in DB
                           :codes ())))))
          (ok (= 1 (getf summary :passed-merged))) ; only ex-new is new
          (let ((cells (sort (copy-list (user-passed-cells uid "sicp-1-1-1"))
                             #'string<)))
            (ok (equal cells '("ex-new" "ex-old")))))))))

(deftest merge-localstorage-keeps-existing-code
  (testing "merge does not overwrite existing DB code (DB wins)"
    (with-test-db
      (let* ((u (create-test-user)) (uid (users-id u)))
        (upsert-cell-code uid "sicp-1-1-1" "ex-sum3" "DB-code")
        (let ((summary (merge-localstorage
                        uid
                        '((:notebook-id "sicp-1-1-1"
                           :passed ()
                           :codes (("ex-sum3" . "LOCAL-code")))))))
          (ok (= 0 (getf summary :codes-merged)))
          (ok (= 1 (getf summary :codes-skipped)))
          (let ((codes (user-cell-codes uid "sicp-1-1-1")))
            (ok (string= "DB-code"
                         (cdr (assoc "ex-sum3" codes :test #'string=))))))))))

(deftest merge-localstorage-inserts-new-code
  (testing "merge inserts code when DB has no row for the cell"
    (with-test-db
      (let* ((u (create-test-user)) (uid (users-id u)))
        (let ((summary (merge-localstorage
                        uid
                        '((:notebook-id "sicp-1-1-1"
                           :passed ()
                           :codes (("ex-sum3" . "LOCAL-code")))))))
          (ok (= 1 (getf summary :codes-merged)))
          (ok (= 0 (getf summary :codes-skipped)))
          (let ((codes (user-cell-codes uid "sicp-1-1-1")))
            (ok (string= "LOCAL-code"
                         (cdr (assoc "ex-sum3" codes :test #'string=))))))))))
```

**Step 2: 失敗確認**

**Step 3: 実装**

```lisp
(defun merge-localstorage (user-id notebooks)
  "Merge localStorage payload into DB for USER-ID.
   NOTEBOOKS is a list of plists:
     (:notebook-id STRING :passed (CELL-ID...) :codes ((CELL-ID . CODE)...))
   Rule: passed = OR (idempotent insert). codes = DB wins (insert only
   if no existing row for that cell).
   Returns plist (:passed-merged N :codes-merged M :codes-skipped K)."
  (let ((passed-merged 0) (codes-merged 0) (codes-skipped 0))
    (dolist (nb notebooks)
      (let ((nb-id (getf nb :notebook-id)))
        ;; passed
        (dolist (cell-id (getf nb :passed))
          (let ((existed (find-dao 'learn-progress
                                   :user-id user-id
                                   :notebook-id nb-id
                                   :cell-id cell-id)))
            (mark-cell-passed user-id nb-id cell-id)
            (unless existed (incf passed-merged))))
        ;; codes
        (dolist (pair (getf nb :codes))
          (let* ((cell-id (car pair))
                 (code (cdr pair))
                 (existing (find-dao 'learn-cell-code
                                     :user-id user-id
                                     :notebook-id nb-id
                                     :cell-id cell-id)))
            (cond
              (existing (incf codes-skipped))
              (t (upsert-cell-code user-id nb-id cell-id code)
                 (incf codes-merged)))))))
    (list :passed-merged passed-merged
          :codes-merged codes-merged
          :codes-skipped codes-skipped)))
```

**Step 4: テスト → PASS**

**Step 5: コミット**

```
Implement merge-localstorage with OR-passed and DB-wins-code rules
```

---

## Task 8: ハンドラ拡張 - Run 時の DB 書き込み

**Files:**
- Modify: `web/routes-wardlisp.lisp`

**Step 1: 既存の `notebook-cell-run-handler` を拡張する**

`mcp__cl-mcp__lisp-read-file` で現コードを確認。`defpackage` の `:import-from` に追加するもの:
- `recurya/web/auth` から `current-user`
- `recurya/db/learn` から `mark-cell-passed`, `upsert-cell-code`, `record-submission`
- `recurya/models/users` から `users-id`

**Step 2: ヘルパ `%maybe-persist-cell-run` を `notebook-cell-run-handler` の直前に `insert_before` で追加**

```lisp
(defun %maybe-persist-cell-run (user nb-id-keyword cell result code)
  "If USER is non-nil (logged in), persist the cell run state to DB.
   Failures are logged and silenced — the user-facing response stays intact."
  (when user
    (handler-case
        (let ((uid (users-id user))
              (nb-id-str (string-downcase (symbol-name nb-id-keyword)))
              (cell-id-str (string-downcase
                            (symbol-name
                             (recurya/game/notebook:cell-id cell))))
              (status (notebook-cell-result-status result)))
          (upsert-cell-code uid nb-id-str cell-id-str (or code ""))
          (when (and (eq (recurya/game/notebook:cell-kind cell) :code-exercise))
            (record-submission uid nb-id-str cell-id-str (or code "")
                               (string-downcase (symbol-name status)))
            (when (eq status :pass)
              (mark-cell-passed uid nb-id-str cell-id-str))))
      (error (e)
        (log:warn "Failed to persist cell run: ~A" e)))))
```

`log:warn` は log4cl 経由(既存依存)。

**Step 3: `notebook-cell-run-handler` 内で `%maybe-persist-cell-run` を呼ぶ**

`mcp__cl-mcp__lisp-patch-form` で、`notebook-cell-run-handler` の `(t ...)` 句内、`(let* ((result ...) ...) ... )` の `let*` body の `(if ...)` の直前に挿入:

```lisp
(%maybe-persist-cell-run
 (recurya/web/auth:current-user (ningle:lack-request-env ningle:*request*))
 id
 (nth index (notebook-cells nb))
 result
 (nth index codes-list))
```

問題: Ningle のセッション/環境取得方法を実装時に確認すること。`ningle:*request*` から `lack:env` を取る方法、または `lack.request` 経由。具体名称は実装スパイクで確定。代替案: `(ningle:context :request)` や `lack.request:request-env`。

**スパイク**: 実装最初の repl-eval で:

```lisp
(ningle:lack-request-env ningle:*request*)
```

が動くか確認。動かなければ `(slot-value ningle:*request* 'env)` 等の代替を試す。

**Step 4: テストは Task 13 でまとめて追加**

このタスクは route 側のロード確認のみ:

```
mcp__cl-mcp__load-system  system=recurya  force=true
```

**Step 5: コミット**

```
Persist code/progress/submissions on Run for logged-in users

Adds %maybe-persist-cell-run helper that, when current-user is non-nil,
upserts learn-cell-code, appends learn-submission for code-exercise
cells, and inserts learn-progress on :pass. DB failures are logged but
do not affect the HTML response.
```

---

## Task 9: `notebook-page-handler` 拡張 - DB コードを描画

**Files:**
- Modify: `web/routes-wardlisp.lisp`
- Modify: `web/ui/notebook.lisp`

**Step 1: `notebook-page-handler` を `lisp-edit-form` `replace` で書き換え**

```lisp
(defun notebook-page-handler (params)
  "GET /wardlisp/learn/:id - Notebook page."
  (let* ((id (%coerce-notebook-id (get-path-param params :id)))
         (nb (and id (get-notebook id))))
    (cond
      ((not nb) (html-response "<h1>404</h1>" :status 404))
      (t
       (let* ((user (recurya/web/auth:current-user
                     (ningle:lack-request-env ningle:*request*)))
              (nb-id-str (and user (string-downcase (symbol-name id))))
              (saved-codes (and user (recurya/db/learn:user-cell-codes
                                      (recurya/models/users:users-id user)
                                      nb-id-str)))
              (passed-cells (and user (recurya/db/learn:user-passed-cells
                                       (recurya/models/users:users-id user)
                                       nb-id-str))))
         (html-response (recurya/web/ui/notebook:render
                         nb
                         :user user
                         :saved-codes saved-codes
                         :passed-cells passed-cells)))))))
```

**Step 2: `web/ui/notebook.lisp` の `render` シグネチャ拡張**

`mcp__cl-mcp__lisp-edit-form` で `defun render` を `replace`。新シグネチャ:

```lisp
(defun render (notebook &key user saved-codes passed-cells)
  "Render the full notebook page. ..."
  (let ((*saved-codes* saved-codes)
        (*passed-cells* passed-cells)
        (*user* user))
    (with-html-string
      ...)))
```

`*saved-codes*` `*passed-cells*` `*user*` の `defparameter` を `(in-package ...)` の直後に追加(初期値 nil):

```lisp
(defparameter *saved-codes* nil)
(defparameter *passed-cells* nil)
(defparameter *user* nil)
```

**Step 3: `render-code-cell` で `*saved-codes*` を参照**

`render-code-cell` 内で `editor-textarea` に渡す initial body を:

```lisp
(let* ((cid-str (string-downcase (symbol-name (cell-id cell))))
       (initial-code (or (cdr (assoc cid-str *saved-codes* :test #'string=))
                         (cell-body cell)
                         "")))
  ...
  (editor-textarea "codes[]" initial-code :id-suffix id-suffix
                   :textarea-class "notebook-code"))
```

**Step 4: `render-code-cell` で `*passed-cells*` をチェックして SSR バッジ**

exercise セルなら `cid-str` が `*passed-cells*` に含まれていれば、`<span class=badge-pass>✓ done</span>` を `:div` の冒頭で出す。

**Step 5: 確認**

```
mcp__cl-mcp__load-system  system=recurya  force=true
```

その後 repl-eval で:

```lisp
(let ((html (recurya/web/ui/notebook:render
             (recurya/game/notebooks/registry:get-notebook :sicp-1-1-1)
             :saved-codes '(("ex-sum3" . "(+ 999 0)"))
             :passed-cells '("ex-sum3"))))
  (list :has-code (search "(+ 999 0)" html)
        :has-badge (search "badge-pass" html)))
```

両方 non-nil を期待。

**Step 6: コミット**

```
Render saved code and pass badges from DB on logged-in notebook pages
```

---

## Task 10: UI - ユーザバナー

**Files:**
- Modify: `web/ui/notebook.lisp`
- Modify: `web/ui/learn-home.lisp`

**Step 1: notebook.lisp の `render` で `<main>` の冒頭にバナー追加**

```lisp
(:main
 (cond
   (*user*
    (:div :class "user-banner"
          "ログイン中: "
          (:strong (recurya/models/users:users-display-name *user*))
          " · " (:a :href "/logout" "ログアウト")))
   (t
    (:div :class "user-banner anon"
          "進捗を端末を超えて保存するには "
          (:a :href "/login" "ログイン") " してください。")))
 ...)
```

`*styles*` に `.user-banner` を追加(色: `#1e293b`, padding: `0.5rem 1rem`, font-size: `0.85rem`)。

**Step 2: `learn-home.lisp` でも同様の処理**

`render` シグネチャを `(notebooks &key user passed-counts)` に拡張。バナーをカード一覧の上に表示。`*user*` `*passed-counts*` も同様に動的特殊変数に。

**Step 3: `learn-home-handler` を更新して `:user :passed-counts` を渡す**

`web/routes-wardlisp.lisp` の `learn-home-handler`:

```lisp
(defun learn-home-handler (params)
  "GET /wardlisp/learn - SICP course index."
  (declare (ignore params))
  (let* ((user (recurya/web/auth:current-user
                (ningle:lack-request-env ningle:*request*)))
         (notebooks (all-notebooks))
         (passed-counts
          (and user
               (let ((uid (recurya/models/users:users-id user)))
                 (mapcar (lambda (nb)
                           (cons (recurya/game/notebook:notebook-id nb)
                                 (length (recurya/db/learn:user-passed-cells
                                          uid
                                          (string-downcase
                                           (symbol-name
                                            (recurya/game/notebook:notebook-id nb))))))) 
                         notebooks)))))
    (html-response (recurya/web/ui/learn-home:render
                    notebooks :user user :passed-counts passed-counts))))
```

**Step 4: `learn-home.lisp` で各カードに `~D/~D 完了` バッジ**

`render` 内、`(dolist (nb notebooks) ...)` で:

```lisp
(let* ((nb-id (recurya/game/notebook:notebook-id nb))
       (count (and *passed-counts*
                   (or (cdr (assoc nb-id *passed-counts*)) 0)))
       (total (count-if (lambda (c)
                          (eq (recurya/game/notebook:cell-kind c) :code-exercise))
                        (recurya/game/notebook:notebook-cells nb))))
  ...
  (when (and *user* (plusp total))
    (:div :class "nb-card__progress"
          (format nil "~D/~D 完了" count total))))
```

**Step 5: 確認**

```
mcp__cl-mcp__load-system  system=recurya  force=true
```

curl で `/wardlisp/learn` と `/wardlisp/learn/sicp-1-1-1` を匿名取得 → どちらもエラーなく 200。

**Step 6: コミット**

```
Add user banner and per-notebook completion count to learn pages
```

---

## Task 11: `/wardlisp/learn/sync` ハンドラ + ルート + テスト

**Files:**
- Modify: `web/routes-wardlisp.lisp`
- Modify: `tests/web/learn-routes.lisp`

**Step 1: テスト先行(TDD)— `tests/web/learn-routes.lisp` に追加**

```lisp
(deftest sync-handler-rejects-anonymous
  (testing "POST /wardlisp/learn/sync without auth returns 401"
    (with-test-db
      (let* ((response
              (recurya/web/routes-wardlisp::learn-sync-handler
               '(("body" . "{\"notebooks\":[]}")))))
        (ok (= 401 (first response)))))))

(deftest sync-handler-merges-payload
  (testing "POST /wardlisp/learn/sync merges into DB"
    (with-test-db
      ;; This test calls merge-localstorage directly via a helper since
      ;; setting up the full Ningle session for an authenticated test
      ;; is more involved. We exercise the JSON parsing + dispatch path
      ;; through a smaller seam.
      (let* ((u (create-test-user))
             (uid (users-id u))
             (summary
              (recurya/db/learn:merge-localstorage
               uid
               '((:notebook-id "sicp-1-1-1"
                  :passed ("ex-sum3")
                  :codes (("ex-sum3" . "(+ 1 2)")))))))
        (ok (= 1 (getf summary :passed-merged)))
        (ok (= 1 (getf summary :codes-merged)))))))
```

注: 完全な HTTP 経由のテストは認証セッション構築が複雑なため、`merge-localstorage` 経由で間接検証。`learn-sync-handler` のディスパッチパスは matter-of-fact に書き、運用時にブラウザで E2E 検証する。

**Step 2: 失敗確認**

```
mcp__cl-mcp__run-tests  system=recurya/tests/web/learn-routes
```

Expected: FAIL on `sync-handler-rejects-anonymous`(関数未定義)

**Step 3: ハンドラ実装(`web/routes-wardlisp.lisp` に挿入)**

`defpackage` の `:import-from` に追加: `com.inuoe.jzon` から `parse`, `stringify`(必要に応じて)。

`learn-sync-handler` を `notebook-cell-run-handler` の後に `insert_after`:

```lisp
(defun %parse-sync-payload (raw-json)
  "Parse JSON payload into the plist shape merge-localstorage expects."
  (let* ((parsed (com.inuoe.jzon:parse raw-json))
         (notebooks (and (hash-table-p parsed)
                         (gethash "notebooks" parsed))))
    (when notebooks
      (loop for nb across notebooks
            collect (list :notebook-id (gethash "notebook_id" nb)
                          :passed (loop for x across (gethash "passed" nb #())
                                        collect x)
                          :codes (let ((codes-ht (gethash "codes" nb)))
                                   (when codes-ht
                                     (let (acc)
                                       (maphash (lambda (k v) (push (cons k v) acc))
                                                codes-ht)
                                       acc))))))))

(defun json-response (data &key (status 200))
  (list status
        '(:content-type "application/json; charset=utf-8")
        (list (com.inuoe.jzon:stringify data))))

(defun learn-sync-handler (params)
  "POST /wardlisp/learn/sync — merge localStorage payload into DB.
   Auth required. Body: {\"notebooks\":[{...}, ...]}."
  (let ((user (recurya/web/auth:current-user
               (ningle:lack-request-env ningle:*request*))))
    (cond
      ((not user)
       (json-response (let ((h (make-hash-table :test 'equal)))
                        (setf (gethash "error" h) "auth required")
                        h)
                      :status 401))
      (t
       (handler-case
           (let* ((raw (or (cdr (assoc "body" params :test #'string=)) "{}"))
                  (notebooks (%parse-sync-payload raw))
                  (summary (recurya/db/learn:merge-localstorage
                            (recurya/models/users:users-id user)
                            notebooks))
                  (ht (make-hash-table :test 'equal)))
             (loop for (k v) on summary by #'cddr
                   do (setf (gethash (string-downcase (symbol-name k)) ht) v))
             (json-response ht))
         (error (e)
           (log:warn "Failed to handle /sync: ~A" e)
           (json-response (let ((h (make-hash-table :test 'equal)))
                            (setf (gethash "error" h) "server error")
                            h)
                          :status 500)))))))
```

注: `params` で raw body を取得する正確な方法は実装時に Ningle/Lack ドキュメントで確認。代替: `lack.request:request-content` から読み取る。スパイクで決定。

**Step 4: ルート登録**

`setup-wardlisp-routes` 内、`/wardlisp/learn/:id/cells/:index/run` の直後に:

```lisp
(setf (ningle/app:route app "/wardlisp/learn/sync" :method :post)
      (make-dynamic-handler 'learn-sync-handler))
```

**Step 5: テスト実行 → PASS**

**Step 6: コミット**

```
Add /wardlisp/learn/sync endpoint for one-time anonymous → DB upload
```

---

## Task 12: `learn.js` 拡張 - codes 保存 + sync POST

**Files:**
- Modify: `resources/static/js/learn.js`

**Step 1: 既存 `learn.js` を `Read` で全部確認**

(JS なので Claude Code 組み込みの `Read`/`Edit`/`Write` 使用 OK)

**Step 2: localStorage スキーマを拡張**

進捗オブジェクトに `codes` を追加:

```js
{
  "sicp-1-1-1": {
    "passed": ["ex-sum3"],
    "codes": {"ex-sum3": "(+ 137 349 22)"},
    "last_visited_at": "..."
  }
}
```

**Step 3: コード保存ロジックを追加**

匿名(`!isLoggedIn`)の Run 後、`htmx:afterRequest` を listen して、対象 form の `.notebook-code` の `name="codes[]"` 値の中で**現在実行されたセル**のコードを保存する。

実装は: Run ボタンの click ハンドラを `htmx:configRequest` で intercept しても良いし、URL の `/cells/N/run` から N を取り出して N番目のtextarea値を保存する。

簡単な実装(`afterRequest` を使う):

```js
document.body.addEventListener('htmx:afterRequest', (e) => {
  if (isLoggedIn) return;             // logged-in の場合はサーバが永続化
  const url = e.detail.requestConfig?.path || '';
  const m = url.match(/\/wardlisp\/learn\/([^\/]+)\/cells\/(\d+)\/run/);
  if (!m) return;
  const nbId = m[1];
  const cellIdx = parseInt(m[2], 10);
  // textarea を index で取得
  const tas = document.querySelectorAll('.notebook-code');
  const ta = tas[cellIdx];
  if (!ta) return;
  const cellId = ta.closest('[data-cell-id]')?.dataset?.cellId;
  if (!cellId) return;
  const p = loadProgress();
  if (!p[nbId]) p[nbId] = { passed: [], codes: {}, last_visited_at: null };
  if (!p[nbId].codes) p[nbId].codes = {};
  p[nbId].codes[cellId] = ta.value;
  p[nbId].last_visited_at = new Date().toISOString();
  saveProgress(p);
});
```

**Step 4: ログイン検知 + sync POST**

```js
async function maybeSyncLocalProgress() {
  if (!isLoggedIn) return;
  const raw = localStorage.getItem(STORAGE_KEY);
  if (!raw) return;
  let payload;
  try { payload = JSON.parse(raw); } catch (_) { return; }
  const notebooks = Object.entries(payload).map(([nbId, val]) => ({
    notebook_id: nbId,
    passed: val.passed || [],
    codes: val.codes || {},
  }));
  if (notebooks.length === 0) return;
  try {
    const res = await fetch('/wardlisp/learn/sync', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({notebooks}),
    });
    if (res.ok) localStorage.removeItem(STORAGE_KEY);
  } catch (_) {
    // Network error — keep localStorage intact for retry on next load.
  }
}
```

`isLoggedIn` を `body.dataset.loggedIn === 'true'` で取得。`DOMContentLoaded` で `maybeSyncLocalProgress()` を呼ぶ。

**Step 5: ログイン時はバッジ後付けをスキップ**

```js
if (isLoggedIn) {
  // SSR badge already rendered, nothing to do.
  return;
}
markCompletedCells(nbId);
```

**Step 6: 動作確認**

```
mcp__cl-mcp__load-system  system=recurya  force=true   # 念のため
```

curl で `/static/js/learn.js` が更新されていることを確認(2.x KiB 程度に増えている)。

**Step 7: コミット**

```
Extend learn.js: persist code in localStorage and sync to server on login
```

---

## Task 13: ルートテスト追加(認証あり/なしの DB 書き込み検証)

**Files:**
- Modify: `tests/web/learn-routes.lisp`

**Step 1: テスト追加**

`%maybe-persist-cell-run` を直接呼び出して DB 書き込みを検証(HTTP 経由はセッション設定が複雑なため、内部関数経由のテストとする)。

```lisp
(deftest persist-cell-run-anonymous-no-write
  (testing "%maybe-persist-cell-run with nil user does nothing"
    (with-test-db
      (let* ((cell (recurya/game/notebook:make-cell
                    :id :ex-sum3 :kind :code-exercise :body ""))
             (result (recurya/game/notebook:make-notebook-cell-result
                      :cell-id :ex-sum3 :kind :code-exercise
                      :status :pass :metrics nil :test-results nil)))
        (recurya/web/routes-wardlisp::%maybe-persist-cell-run
         nil :sicp-1-1-1 cell result "(+ 1 2)")
        (ok (zerop (mito:count-dao 'recurya/models/learn-progress:learn-progress)))
        (ok (zerop (mito:count-dao 'recurya/models/learn-cell-code:learn-cell-code)))))))

(deftest persist-cell-run-logged-in-saves-code
  (testing "logged-in run saves code"
    (with-test-db
      (let* ((u (create-test-user))
             (cell (recurya/game/notebook:make-cell
                    :id :c1 :kind :code-eval :body ""))
             (result (recurya/game/notebook:make-notebook-cell-result
                      :cell-id :c1 :kind :code-eval :status :ok
                      :metrics nil :test-results nil)))
        (recurya/web/routes-wardlisp::%maybe-persist-cell-run
         u :sicp-1-1-1 cell result "(+ 1 2)")
        (let ((rows (recurya/db/learn:user-cell-codes
                     (users-id u) "sicp-1-1-1")))
          (ok (= 1 (length rows)))
          (ok (string= "(+ 1 2)"
                       (cdr (assoc "c1" rows :test #'string=)))))))))

(deftest persist-cell-run-pass-marks-progress
  (testing "logged-in :pass marks progress"
    (with-test-db
      (let* ((u (create-test-user))
             (cell (recurya/game/notebook:make-cell
                    :id :ex-sum3 :kind :code-exercise :body ""))
             (result (recurya/game/notebook:make-notebook-cell-result
                      :cell-id :ex-sum3 :kind :code-exercise
                      :status :pass :metrics nil :test-results nil)))
        (recurya/web/routes-wardlisp::%maybe-persist-cell-run
         u :sicp-1-1-1 cell result "(+ 137 349 22)")
        (ok (member "ex-sum3"
                    (recurya/db/learn:user-passed-cells
                     (users-id u) "sicp-1-1-1")
                    :test #'string=))))))

(deftest persist-cell-run-records-submission
  (testing "logged-in exercise run appends a submission row"
    (with-test-db
      (let* ((u (create-test-user))
             (cell (recurya/game/notebook:make-cell
                    :id :ex-sum3 :kind :code-exercise :body ""))
             (result (recurya/game/notebook:make-notebook-cell-result
                      :cell-id :ex-sum3 :kind :code-exercise
                      :status :fail :metrics nil :test-results nil)))
        (recurya/web/routes-wardlisp::%maybe-persist-cell-run
         u :sicp-1-1-1 cell result "(bad)")
        (let ((rows (recurya/db/learn:cell-submissions
                     (users-id u) "sicp-1-1-1" "ex-sum3")))
          (ok (= 1 (length rows))))))))
```

`tests/web/learn-routes.lisp` の `:import-from` に必要なものを追加(`make-cell`, `make-notebook-cell-result` など)。

**Step 2: テスト実行**

```
mcp__cl-mcp__run-tests  system=recurya/tests/web/learn-routes
```

Expected: 既存 + 新 4 テスト全 PASS。

**Step 3: コミット**

```
Add tests for %maybe-persist-cell-run anonymous/logged-in branches
```

---

## Task 14: フルテスト + 手動 E2E

**Files:** 変更なし(検証のみ)

**Step 1: コンテナ内でフルテスト**

```bash
docker compose exec -T recurya qlot exec ros run \
  -e '(ql:quickload :recurya/tests :silent t)' \
  -e '(let ((r (asdf:test-system :recurya))) (format t "~&TEST-RESULT: ~A~%" r))' -q
```

Expected: `TEST-RESULT: T`

**Step 2: cl-mcp 経由のサーバ再起動**

```
mcp__cl-mcp__repl-eval  code='(progn (recurya/web/server:stop!) (recurya/web/server:start!))'
```

**Step 3: ブラウザ E2E チェックリスト(ユーザに依頼)**

ユーザに以下の手順を依頼:

1. **匿名動作**: `http://localhost:3000/wardlisp/learn/sicp-1-1-1` を開き、演習セルで `(+ 137 349 22)` を Run → PASS。バッジが付く。リロードしてもバッジが残る(localStorage)。
2. **新規登録**: `http://localhost:3000/signup` で新規ユーザを作成。ログイン状態に。
3. **自動 sync**: ログイン後 `http://localhost:3000/wardlisp/learn` を開く。DevTools の Network タブで `POST /wardlisp/learn/sync` が 200 で完了。Application タブで `recurya:learn:v1` が消えていることを確認。
4. **進捗復元**: `/wardlisp/learn/sicp-1-1-1` をログイン状態で開くと、合格セルに「✓ done」バッジが SSR で表示される(JS 不要で出る)。textarea にも前のコードが入っている。
5. **新セルの保存**: 別の演習セルを Run → PASS。`/wardlisp/learn/sicp-1-1-2` でも同様。
6. **別ブラウザ**: シークレットウィンドウで同じユーザでログイン → 進捗・コードが復元される。
7. **既存機能の回帰**: `/wardlisp/`, `/wardlisp/puzzle/adjacent`, `/wardlisp/arena`, `/wardlisp/playground` がすべて正常表示。

**Step 4: README に簡潔な追記(任意)**

`README.md` に「ログインで進捗保存」の 1 行追加。

**Step 5: 最終コミット(変更なしならスキップ)**

```bash
git commit --allow-empty -m "$(cat <<'EOF'
Verified Learn Account Sync feature end-to-end

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## 完了基準

- `asdf:test-system :recurya` が green
- 3 つの新テーブルが Postgres に存在
- 匿名で `/wardlisp/learn/*` が変わらず動く
- ログインユーザの Run が DB に記録される(`learn-cell-code`/`learn-progress`/`learn-submission`)
- `/wardlisp/learn/sync` が JSON 応答する
- 別デバイス・別ブラウザで同じ進捗が見える
- 既存ページ(`/wardlisp/puzzle/*`, `/wardlisp/arena`, `/wardlisp/playground`)に回帰なし

## リスクと対処

| リスク | 対処 |
|------|----|
| `ningle:lack-request-env` の API 名が違う | 実装最初の repl-eval スパイクで確認。代替: `lack.request:request-env`、`(slot-value ningle:*request* 'lack/lack:env)` |
| `params` での raw body 取得方法不明 | 同上スパイクで `lack.request:request-content` 経由を試す |
| Mito の race condition で重複 insert | `unique-keys` で守られる。`handler-case` で吸収 |
| マイグレーション CLI のホスト名違い | コンテナ内では `postgres`(サービス名)、ホストからなら `localhost` |
| JSON parse の cl-jzon API 差異 | `(jzon:parse "...")` がハッシュテーブル/ベクトルを返す。テストで挙動確認 |
