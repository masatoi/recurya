# Notebook統合 実装プラン

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** ブログ機能 (`post`) を Notebook に統合し、`user-notebook` を `notebook` に改名、`@handle` URL名前空間と `/dashboard/*` 管理境界を導入する。

**Architecture:** 開発初期段階の前提を活用し、`post` テーブル / `users` データ / `user_notebook` テーブルを破棄してクリーンに再構築。ハンドル制を導入し、slug を `(author_id, slug)` 複合一意に変更。公開と管理を URL レベルで分離する。

**Tech Stack:** Common Lisp / Mito ORM / cl-dbi (PostgreSQL) / Ningle / Lack / Spinneret / HTMX / Rove / Mito CLI

---

## 前提と参照スキル

- 全 Lisp 操作は cl-mcp ツール経由（`lisp-edit-form`, `lisp-patch-form`, `lisp-read-file`, `clgrep-search`, `repl-eval`, `load-system`, `run-tests`）。Read/Edit/Write は `.lisp`/`.asd` には使わない。
- DB マイグレーションは `/mito-migrate` スキルを使う。
- 設計詳細は `docs/plans/2026-05-09-notebook-unification-design.md` を参照。
- 各タスクの最後でローカルテスト緑を確認してからコミット。
- 失敗時は次タスクに進まず、根本原因を調査する（CLAUDE.md の方針）。
- ブランチ: `feat/notebook-unification`（既に作成済み）

---

## Phase 1: ハンドルバリデーション（TDD）

### Task 1: handle バリデーションのテストを書く

**Files:**
- Create: `tests/utils/handle.lisp`

**Step 1: テストファイルを作る**

`fs-write-file` で最小スタブを作成:

```lisp
(defpackage #:recurya/tests/utils/handle
  (:use #:cl #:rove))
(in-package #:recurya/tests/utils/handle)

(deftest handle-validation
  (testing "valid handles"
    (ok (recurya/utils/handle:valid-handle-p "alice"))
    (ok (recurya/utils/handle:valid-handle-p "bob-the-builder"))
    (ok (recurya/utils/handle:valid-handle-p "user123"))
    (ok (recurya/utils/handle:valid-handle-p "abc")))
  (testing "invalid: too short"
    (ng (recurya/utils/handle:valid-handle-p "ab"))
    (ng (recurya/utils/handle:valid-handle-p "")))
  (testing "invalid: uppercase"
    (ng (recurya/utils/handle:valid-handle-p "Alice")))
  (testing "invalid: leading/trailing hyphen"
    (ng (recurya/utils/handle:valid-handle-p "-alice"))
    (ng (recurya/utils/handle:valid-handle-p "alice-")))
  (testing "invalid: special chars"
    (ng (recurya/utils/handle:valid-handle-p "alice.bob"))
    (ng (recurya/utils/handle:valid-handle-p "alice_bob"))
    (ng (recurya/utils/handle:valid-handle-p "alice@bob"))))

(deftest reserved-handles
  (testing "reserved words are rejected"
    (ok (recurya/utils/handle:reserved-handle-p "notebooks"))
    (ok (recurya/utils/handle:reserved-handle-p "dashboard"))
    (ok (recurya/utils/handle:reserved-handle-p "admin"))
    (ok (recurya/utils/handle:reserved-handle-p "API")) ; case insensitive
    (ng (recurya/utils/handle:reserved-handle-p "alice"))))
```

**Step 2: テストを実行して fail することを確認**

```
run-tests system="recurya/tests" test="recurya/tests/utils/handle"
```

期待: `recurya/utils/handle` パッケージが存在しないため fail。

**Step 3: コミットしない**（実装と同時にコミット）

---

### Task 2: handle バリデーション実装

**Files:**
- Create: `utils/handle.lisp`
- Modify: `recurya.asd`

**Step 1: `utils/handle.lisp` を作成**

`fs-write-file` で:

```lisp
(defpackage #:recurya/utils/handle
  (:use #:cl)
  (:export #:valid-handle-p
           #:reserved-handle-p
           #:+handle-min-length+
           #:+handle-max-length+))

(in-package #:recurya/utils/handle)

(defparameter +handle-min-length+ 3)
(defparameter +handle-max-length+ 64)

(defparameter *handle-regex*
  (cl-ppcre:create-scanner "^[a-z0-9][a-z0-9-]{1,62}[a-z0-9]$"))

(defparameter *reserved-handles*
  '("notebooks" "courses" "c" "n" "dashboard" "account" "login" "logout"
    "auth" "onboarding" "api" "static" "admin" "assets" "learn" "wardlisp"
    "settings" "help" "about" "new" "edit" "search" "blog" "posts"
    "register" "signup" "signin" "user" "users" "me"))

(defun valid-handle-p (s)
  "True if S is a syntactically valid handle (does not check reservation)."
  (and (stringp s)
       (>= (length s) +handle-min-length+)
       (<= (length s) +handle-max-length+)
       (cl-ppcre:scan *handle-regex* s)
       t))

(defun reserved-handle-p (s)
  "True if S is in the reserved-handles list (case-insensitive)."
  (and (stringp s)
       (member (string-downcase s) *reserved-handles* :test #'string=)
       t))
```

**Step 2: `recurya.asd` に追加**

`lisp-patch-form` で `defsystem "recurya"` の `:depends-on` 内、`recurya/utils/access-control` の前に `recurya/utils/handle` を追加。

`recurya.asd` の `defsystem "recurya/tests"` には `recurya/tests/utils/handle` を `recurya/tests/utils/access-control` の前に追加。

**Step 3: ロードして再実行**

```
load-system system="recurya"
load-system system="recurya/tests"
run-tests system="recurya/tests" test="recurya/tests/utils/handle"
```

期待: 全テスト pass。

**Step 4: コミット**

```bash
git add utils/handle.lisp tests/utils/handle.lisp recurya.asd
git commit -m "feat: add handle validation utilities"
```

---

## Phase 2: post 関連の削除

### Task 3: ASDF から post 関連を取り除く

**Files:**
- Modify: `recurya.asd`

**Step 1: 削除対象を確認**

`recurya.asd` の `defsystem "recurya"` 内から削除:
- `recurya/db/posts`
- `recurya/models/post`
- `recurya/web/ui/posts`
- `recurya/web/ui/post-form`
- `recurya/web/ui/blog`
- `recurya/web/ui/blog-post`

`defsystem "recurya/tests"` 内から削除:
- `recurya/tests/db/posts`

**Step 2: `lisp-patch-form` で除去**

各行を個別に除去（複数行を一度に削除する場合は `defsystem` 全体を `lisp-edit-form` で書き換える方が安全）。

**Step 3: コンパイル確認**

```
load-system system="recurya" force=true clear_fasls=true
```

期待: `Component "recurya/models/post" not found` 等が出ないこと（まだファイルは存在するが ASDF 依存は外れている）。

**Step 4: コミットしない**（次タスクと合わせて）

---

### Task 4: post 関連ファイル削除

**Files:**
- Delete: `models/post.lisp`
- Delete: `db/posts.lisp`
- Delete: `web/ui/posts.lisp`
- Delete: `web/ui/post-form.lisp`
- Delete: `web/ui/blog.lisp`
- Delete: `web/ui/blog-post.lisp`
- Delete: `tests/db/posts.lisp`

**Step 1: ファイル削除**

```bash
git rm models/post.lisp db/posts.lisp web/ui/posts.lisp web/ui/post-form.lisp web/ui/blog.lisp web/ui/blog-post.lisp tests/db/posts.lisp
```

**Step 2: routes.lisp から post ハンドラを除去**

`web/routes.lisp` に対し:

`clgrep-search pattern="post-.*-handler|/posts|/blog|post->plist"` で全該当箇所を確認。

`lisp-edit-form` で削除:
- `post->plist`
- `posts-handler`
- `post-new-handler`
- `post-create-handler`
- `post-edit-handler`
- `post-update-handler`
- `post-toggle-status-handler`
- `post-confirm-delete-handler`
- `post-delete-handler`
- `blog-handler`
- `blog-post-handler`

`setup-routes` 内の `/posts/*`, `/blog`, `/blog/:slug` を登録している `setf` 行を削除。

`defpackage` の `:import-from #:recurya/models/post` を削除。

**Step 3: routes.lisp のテストから post 関連を除去**

`tests/web/routes.lisp` を確認し、`post-` 系テストがあれば削除。

**Step 4: load-system でコンパイル確認**

```
load-system system="recurya" force=true clear_fasls=true
```

期待: 警告ゼロ・エラーなし。

**Step 5: 全テスト実行**

```
run-tests system="recurya/tests"
```

期待: 全 green。

**Step 6: コミット**

```bash
git add -u
git commit -m "feat: remove blog/post functionality (consolidating into Notebook)"
```

---

## Phase 3: user-notebook → notebook リネーム

### Task 5: モデルファイルとパッケージ名のリネーム

**Files:**
- Rename: `models/user-notebook.lisp` → `models/notebook.lisp`
- Rename: `db/user-notebooks.lisp` → `db/notebooks.lisp`
- Rename: `web/ui/user-notebooks.lisp` → `web/ui/notebooks-dashboard.lisp`
- Rename: `web/ui/user-notebook-form.lisp` → `web/ui/notebook-form.lisp`
- Rename: `tests/db/user-notebooks.lisp` → `tests/db/notebooks.lisp`
- Rename: `tests/web/user-notebook-routes.lisp` → `tests/web/notebook-routes.lisp`
- Modify: `recurya.asd`

**Step 1: `git mv` でファイル移動**

```bash
git mv models/user-notebook.lisp models/notebook.lisp
git mv db/user-notebooks.lisp db/notebooks.lisp
git mv web/ui/user-notebooks.lisp web/ui/notebooks-dashboard.lisp
git mv web/ui/user-notebook-form.lisp web/ui/notebook-form.lisp
git mv tests/db/user-notebooks.lisp tests/db/notebooks.lisp
git mv tests/web/user-notebook-routes.lisp tests/web/notebook-routes.lisp
```

**Step 2: `recurya.asd` を更新**

`lisp-patch-form` で `defsystem "recurya"` 内の依存を更新:
- `recurya/db/user-notebooks` → `recurya/db/notebooks`
- `recurya/models/user-notebook` → `recurya/models/notebook`
- `recurya/web/ui/user-notebooks` → `recurya/web/ui/notebooks-dashboard`
- `recurya/web/ui/user-notebook-form` → `recurya/web/ui/notebook-form`

`defsystem "recurya/tests"` 内:
- `recurya/tests/db/user-notebooks` → `recurya/tests/db/notebooks`
- `recurya/tests/web/user-notebook-routes` → `recurya/tests/web/notebook-routes`

**Step 3: コミットしない**（シンボル変更とまとめる）

---

### Task 6: 各ファイル内のパッケージ名・シンボルを置換

**Files:**
- Modify: `models/notebook.lisp`
- Modify: `db/notebooks.lisp`
- Modify: `web/ui/notebooks-dashboard.lisp`
- Modify: `web/ui/notebook-form.lisp`
- Modify: `tests/db/notebooks.lisp`
- Modify: `tests/web/notebook-routes.lisp`

**Step 1: `clgrep-search` で全プロジェクトの参照箇所を洗い出す**

```
clgrep-search pattern="user-notebook"
```

このタスクで触る対象（リネーム済みファイル＋それ以外で `user-notebook` を参照しているファイル全部）。

**Step 2: 各ファイルでパッケージ宣言とシンボル名を置換**

リネーム済みの自ファイル内では、以下を置換:

| 旧 | 新 |
|----|----|
| `recurya/models/user-notebook` | `recurya/models/notebook` |
| `recurya/db/user-notebooks` | `recurya/db/notebooks` |
| `recurya/web/ui/user-notebooks` | `recurya/web/ui/notebooks-dashboard` |
| `recurya/web/ui/user-notebook-form` | `recurya/web/ui/notebook-form` |
| `recurya/tests/db/user-notebooks` | `recurya/tests/db/notebooks` |
| `recurya/tests/web/user-notebook-routes` | `recurya/tests/web/notebook-routes` |
| `user-notebook` | `notebook` (型名・シンボル名) |
| `user-notebook-id` | `notebook-id` |
| `user-notebook-slug` | `notebook-slug` |
| `user-notebook-title` | `notebook-title` |
| `user-notebook-summary` | `notebook-summary` |
| `user-notebook-body-md` | `notebook-body-md` |
| `user-notebook-cells` | `notebook-cells` |
| `user-notebook-status` | `notebook-status` |
| `user-notebook-visibility` | `notebook-visibility` |
| `user-notebook-published-at` | `notebook-published-at` |
| `user-notebook-author` | `notebook-author` |
| `user-notebook-author-id` | `notebook-author-id` |
| `user-notebook-created-at` | `notebook-created-at` |
| `user-notebook-updated-at` | `notebook-updated-at` |

**重要:** 既存の `notebook` シンボル（`recurya/game/notebook` パッケージなど）と衝突しないよう、置換対象は **`user-notebook` プレフィックス付き識別子のみ**。`notebook` 単独のシンボルには手を出さない。

`models/notebook.lisp` 内の `deftable user-notebook` → `deftable notebook`、テーブル名にも注意:

```lisp
;; 既存:
(deftable user-notebook nil ...)
;; 変更後:
(deftable notebook nil
  (...)
  (:auto-pk nil) (:unique-keys (author_id slug))   ; ← 同時に複合一意に変更
  ...)
```

**注意:** `models/course-notebook.lisp` は名称維持。中の `:col-type user-notebook` を `:col-type notebook` に変更し、`(:import-from #:recurya/models/user-notebook ...)` を `(:import-from #:recurya/models/notebook ...)` に変更する。

**Step 3: 他ファイル（リネーム対象外）のシンボル参照も更新**

`clgrep-search` の結果に従い、以下も同様の置換:

- `models/course-notebook.lisp`
- `web/routes.lisp` (大量にある)
- `web/app.lisp`
- `web/auth.lisp`（参照していれば）
- `web/ui/notebook.lisp`（公開詳細UI）
- `web/ui/notebook-list.lisp`（公開一覧UI）
- `tests/db/course-notebooks.lisp`
- `tests/web/routes.lisp`
- `tests/web/course-routes.lisp`
- `tests/web/learn-routes.lisp`
- その他 `clgrep-search` でヒットしたファイル

**Step 4: コンパイル確認**

```
load-system system="recurya" force=true clear_fasls=true
```

期待: エラーなし。警告は最小限。

**Step 5: 全テスト実行（DB起動前提）**

```
run-tests system="recurya/tests"
```

DB系テストはまだ DB マイグレーション前なので、user_notebook テーブルが存在する状態で notebook シンボルを使っているとマップエラーになる可能性あり。Phase 4 の DB マイグレーション後に再実行する。

このステップでは **コンパイル成功を確認** までで OK。

**Step 6: コミット**

```bash
git add -u
git commit -m "refactor: rename user-notebook to notebook"
```

---

## Phase 4: モデル変更 (handle 列、slug 複合一意)

### Task 7: users モデルに handle 列追加

**Files:**
- Modify: `models/users.lisp`

**Step 1: `lisp-edit-form` で `deftable users` を更新**

`handle` フィールドを追加し `:unique-keys` に追加:

```lisp
(deftable users nil
          ((id :col-type :uuid :initarg :id :accessor %users-id :primary-key t)
           (email :col-type (:varchar 255) :initarg :email :accessor users-email)
           (handle :col-type (:varchar 64) :initarg :handle :accessor users-handle)
           (password-hash :col-type (or (:varchar 255) :null) ...)
           ;; ... 既存フィールド維持 ...
           )
          (:auto-pk nil)
          (:unique-keys email handle)
          (:documentation "..."))
```

`defpackage` の `:export` リストに `#:users-handle` を追加。

**Step 2: コンパイル確認**

```
load-system system="recurya" force=true
```

期待: エラーなし。

**Step 3: コミットしない**（次タスクの notebook/course slug 複合キーとセット）

---

### Task 8: notebook と course の slug を複合一意に変更

**Files:**
- Modify: `models/notebook.lisp`
- Modify: `models/course.lisp`

**Step 1: `lisp-edit-form` で `models/notebook.lisp` の `deftable notebook` を更新**

(Task 6 ですでに変更している場合はスキップ)

```lisp
;; 変更前: (:unique-keys slug)
;; 変更後: (:unique-keys (author_id slug))
```

`:keys` も活用しやすいよう更新:

```lisp
(:keys (status :created_at) (author_id :created_at) (visibility :status))
```

**Step 2: `models/course.lisp` の `deftable course` も同様に更新**

```lisp
(:unique-keys (author_id slug))
(:keys (status :created_at) (author_id :created_at) (visibility :status))
```

**Step 3: コンパイル確認**

```
load-system system="recurya" force=true
```

**Step 4: コミット**

```bash
git add -u
git commit -m "feat: add users.handle and per-author slug uniqueness"
```

---

## Phase 5: DB マイグレーション

### Task 9: マイグレーション生成と適用

**Files:**
- Create: `db/migrations/<timestamp>.up.sql`
- Create: `db/migrations/<timestamp>.down.sql`

**Step 1: PostgreSQL を起動して既存データを破棄**

```bash
docker compose up -d
psql postgresql://postgres:postgres@localhost:15434/recurya \
  -c "TRUNCATE users CASCADE;"
```

**Step 2: `/mito-migrate` スキルでマイグレーション生成**

`/mito-migrate` を起動し、ステップに従って:

```bash
.qlot/bin/mito generate-migrations \
  -t postgres -H localhost -P 15434 \
  -d recurya -u postgres -p postgres -s recurya -D db/
```

生成された `.up.sql` を `fs-read-file` で確認。期待される SQL:

```sql
-- post テーブル削除
DROP TABLE post;

-- user_notebook → notebook
ALTER TABLE user_notebook RENAME TO notebook;

-- 旧 slug 一意制約を破棄、(author_id, slug) で再作成
ALTER TABLE notebook DROP CONSTRAINT user_notebook_slug_key;
CREATE UNIQUE INDEX notebook_uniq_author_id_and_slug ON notebook (author_id, slug);

-- course も同様
ALTER TABLE course DROP CONSTRAINT course_slug_key;
CREATE UNIQUE INDEX course_uniq_author_id_and_slug ON course (author_id, slug);

-- users.handle
ALTER TABLE users ADD COLUMN handle VARCHAR(64) NOT NULL;
CREATE UNIQUE INDEX users_uniq_handle ON users (handle);
```

Mito CLI が想定通りの SQL を出さない場合は手書きで補正。`.down.sql` も同期させる。

**Step 3: マイグレーション適用**

```bash
.qlot/bin/mito migrate \
  -t postgres -H localhost -P 15434 \
  -d recurya -u postgres -p postgres -s recurya -D db/
```

期待: 全マイグレーション適用成功。

**Step 4: スキーマ確認**

```bash
psql postgresql://postgres:postgres@localhost:15434/recurya \
  -c "\d notebook" \
  -c "\d users" \
  -c "\d course"
```

期待:
- `notebook` テーブル存在
- `notebook` に `(author_id, slug)` 複合 UNIQUE インデックス
- `users.handle VARCHAR(64) NOT NULL UNIQUE`
- `post` テーブル消滅

**Step 5: テスト実行（DB必要なテスト含む）**

```
run-tests system="recurya/tests" test="recurya/tests/db/users"
run-tests system="recurya/tests" test="recurya/tests/db/notebooks"
run-tests system="recurya/tests" test="recurya/tests/db/courses"
```

期待: handle や slug 複合一意性のテストが新たに追加されるまで、既存テストは変わらず pass。
ただし `db/users` テストで「handle 必須」を考慮していなければ fail する可能性あり → 修正する。

**Step 6: コミット**

```bash
git add db/migrations/
git commit -m "feat: db migration for notebook unification"
```

---

### Task 10: モデル変更に伴う既存DBテストの調整

**Files:**
- Modify: `tests/db/users.lisp`
- Modify: `tests/db/notebooks.lisp`
- Modify: `tests/db/courses.lisp`
- Modify: `tests/db/course-notebooks.lisp`
- Modify: `tests/support/db.lisp`（fixture）

**Step 1: `tests/support/` を確認してfixture更新**

```
fs-list-directory path="tests/support"
lisp-read-file path="tests/support/db.lisp" name_pattern="."
```

ユーザー作成 fixture が `handle` を要求するよう修正（自動採番か必須引数）。

例:

```lisp
(defun make-test-user (&key (email "test@example.com")
                            (handle (format nil "user-~A" (random 100000)))
                            (display-name "Test User"))
  (mito:create-dao 'users :email email :handle handle :display-name display-name))
```

**Step 2: 各テストで fixture 呼び出しが handle を渡すよう調整**

`clgrep-search pattern="make-test-user|create-dao 'users"` で該当箇所をすべて修正。

**Step 3: `tests/db/users.lisp` に handle 関連テストを追加**

```lisp
(deftest users-handle
  (testing "handle is required"
    ;; insertion without handle should fail
    (ok (signals-error (mito:create-dao 'users :email "x@y.com" :display-name "X"))))
  (testing "handle is unique"
    (let ((u1 (make-test-user :handle "alice" :email "a@x.com")))
      (declare (ignore u1))
      (ok (signals-error (make-test-user :handle "alice" :email "b@x.com"))))))
```

`signals-error` のヘルパーを `tests/support/` に追加するか、Rove の `(handler-case ...)` で書き分け。

**Step 4: `tests/db/notebooks.lisp` に slug 複合一意性テストを追加**

```lisp
(deftest notebook-per-author-slug
  (testing "different authors can have same slug"
    (let ((u1 (make-test-user :handle "alice" :email "a@x.com"))
          (u2 (make-test-user :handle "bob"   :email "b@x.com")))
      (mito:create-dao 'notebook :slug "intro" :title "Intro" :body-md "" :cells #() :author u1)
      (ok (mito:create-dao 'notebook :slug "intro" :title "Intro" :body-md "" :cells #() :author u2))))
  (testing "same author cannot reuse slug"
    (let ((u (make-test-user :handle "carol" :email "c@x.com")))
      (mito:create-dao 'notebook :slug "x" :title "X" :body-md "" :cells #() :author u)
      (ok (signals-error
            (mito:create-dao 'notebook :slug "x" :title "Y" :body-md "" :cells #() :author u))))))
```

**Step 5: `tests/db/courses.lisp` にも同様の slug 複合一意性テストを追加**

**Step 6: 全 DB テスト実行**

```
run-tests system="recurya/tests"
```

期待: 全 green。

**Step 7: コミット**

```bash
git add -u
git commit -m "test: handle and per-author slug uniqueness"
```

---

## Phase 6: ハンドル登録（オンボーディング）

### Task 11: handle 必須リダイレクトミドルウェアのテスト

**Files:**
- Modify: `tests/web/oauth.lisp` または `tests/web/onboarding.lisp` 新規
- Create: `tests/web/onboarding.lisp`

**Step 1: テスト追加**

`tests/web/onboarding.lisp` を作成:

```lisp
(defpackage #:recurya/tests/web/onboarding
  (:use #:cl #:rove))
(in-package #:recurya/tests/web/onboarding)

(deftest handle-required-redirect
  (testing "logged-in user without handle is redirected to /onboarding/handle"
    ;; [既存のテストパターンに従い、セッションをセットしたリクエストを発行]
    ;; 期待: GET /dashboard → 302 to /onboarding/handle
    ))

(deftest handle-form-validation
  (testing "valid handle is accepted"
    ;; POST /onboarding/handle with handle=alice → 302 to /dashboard
    )
  (testing "invalid handle is rejected"
    ;; POST /onboarding/handle with handle=A!ice → 400 with error
    )
  (testing "duplicate handle is rejected"
    ;; 既存ユーザーで使用中のハンドル → 409 or 400 with error
    )
  (testing "reserved handle is rejected"
    ;; handle=admin → 400 with error
    ))
```

`recurya.asd` に `recurya/tests/web/onboarding` を追加（ASD更新）。

**Step 2: テストを fail することを確認**

```
load-system system="recurya/tests" force=true
run-tests system="recurya/tests" test="recurya/tests/web/onboarding"
```

**Step 3: 次タスクで実装**

---

### Task 12: オンボーディング UI とハンドラ実装

**Files:**
- Create: `web/ui/onboarding.lisp`
- Modify: `web/routes.lisp`
- Modify: `web/app.lisp`
- Modify: `recurya.asd`

**Step 1: `web/ui/onboarding.lisp` を作成**

```lisp
(defpackage #:recurya/web/ui/onboarding
  (:use #:cl #:spinneret)
  (:import-from #:recurya/web/ui/layout #:render-layout)
  (:import-from #:recurya/web/ui/csrf #:csrf-input)
  (:export #:render-onboarding-handle-page))

(in-package #:recurya/web/ui/onboarding)

(defun render-onboarding-handle-page (&key error suggested-handle csrf-token)
  (render-layout
    :title "ハンドル設定"
    :body (with-html-string
            (:div :class "max-w-md mx-auto py-12"
              (:h1 "ハンドルを決めてください")
              (:p "公開URLで使われます。後から変更できません。")
              (when error
                (:p :class "text-red-600" error))
              (:form :method "post" :action "/onboarding/handle"
                     :class "mt-6"
                (csrf-input csrf-token)
                (:label :for "handle" "ハンドル")
                (:input :type "text" :name "handle" :id "handle"
                        :pattern "^[a-z0-9][a-z0-9-]{1,62}[a-z0-9]$"
                        :value suggested-handle
                        :required t)
                (:button :type "submit" "決定"))))))
```

**Step 2: `web/routes.lisp` にハンドラ追加**

```lisp
(defun onboarding-handle-page-handler (params)
  "Handle GET /onboarding/handle - show handle setup form."
  (declare (ignore params))
  (let* ((user (get-current-user))
         (csrf-token (recurya/web/ui/csrf:get-or-create-csrf-token (get-session))))
    (cond
      ((null user) (redirect "/login"))
      ((users-handle-set-p user) (redirect "/dashboard"))
      (t (html-response
           (recurya/web/ui/onboarding:render-onboarding-handle-page
             :csrf-token csrf-token))))))

(defun onboarding-handle-create-handler (params)
  "Handle POST /onboarding/handle - validate and save handle."
  (let* ((user (get-current-user))
         (handle (string-downcase (or (get-param params "handle") "")))
         (csrf-token (recurya/web/ui/csrf:get-or-create-csrf-token (get-session))))
    (cond
      ((null user) (redirect "/login"))
      ((not (recurya/utils/handle:valid-handle-p handle))
       (html-response
         (recurya/web/ui/onboarding:render-onboarding-handle-page
           :error "ハンドルの形式が正しくありません。"
           :suggested-handle handle
           :csrf-token csrf-token)
         :status 400))
      ((recurya/utils/handle:reserved-handle-p handle)
       (html-response
         (recurya/web/ui/onboarding:render-onboarding-handle-page
           :error "このハンドルは予約語です。別のハンドルを選んでください。"
           :csrf-token csrf-token)
         :status 400))
      ((mito:find-dao 'recurya/models/users:users :handle handle)
       (html-response
         (recurya/web/ui/onboarding:render-onboarding-handle-page
           :error "このハンドルは既に使われています。"
           :csrf-token csrf-token)
         :status 409))
      (t
       (let ((user-dao (mito:find-dao 'recurya/models/users:users
                                      :id (getf user :id))))
         (setf (recurya/models/users:users-handle user-dao) handle)
         (mito:save-dao user-dao)
         (let ((session (get-session)))
           (setf (gethash :handle session) handle))
         (redirect "/dashboard"))))))
```

`users-handle-set-p` のヘルパーは `web/auth.lisp` に追加:

```lisp
(defun users-handle-set-p (user-plist)
  "True if the session user has a handle set (non-empty string)."
  (let ((h (getf user-plist :handle)))
    (and h (stringp h) (> (length h) 0))))
```

`user-dao->plist` でセッションに `:handle` を含めるよう修正。

**Step 3: ルート登録**

`web/routes.lisp` の `setup-routes` に追加:

```lisp
(setf (ningle:route app "/onboarding/handle" :method :get)
      (lambda (params) (onboarding-handle-page-handler params)))
(setf (ningle:route app "/onboarding/handle" :method :post)
      (lambda (params) (onboarding-handle-create-handler params)))
```

**Step 4: `recurya.asd` に `recurya/web/ui/onboarding` を追加**

`recurya/web/routes` の前に依存追加。

**Step 5: コンパイル + テスト**

```
load-system system="recurya" force=true
load-system system="recurya/tests" force=true
run-tests system="recurya/tests" test="recurya/tests/web/onboarding"
```

期待: 緑。

**Step 6: コミット**

```bash
git add -u
git commit -m "feat: handle onboarding flow"
```

---

## Phase 7: ルート再構築

### Task 13: `/dashboard/notebooks` 系ハンドラ移行

**Files:**
- Modify: `web/routes.lisp`
- Modify: `tests/web/notebook-routes.lisp`

**Step 1: 既存テストの URL を新URLに置換**

`clgrep-search pattern="/notebooks/(me|new|:?id)" path="tests/"` で該当行を確認。

`/notebooks/me` → `/dashboard/notebooks`
`/notebooks/new` → `/dashboard/notebooks/new`
`/notebooks/:id/edit` → `/dashboard/notebooks/:id/edit`
`/notebooks/:id/state` → `/dashboard/notebooks/:id/state`
`/notebooks/:id/toggle-status` → `/dashboard/notebooks/:id/toggle-status`
`/notebooks/:id/confirm-delete` → `/dashboard/notebooks/:id/confirm-delete`
`/notebooks/:id/delete` → `/dashboard/notebooks/:id/delete`
`/notebooks/:id` (POST update) → `/dashboard/notebooks/:id`

**Step 2: テストを実行して fail することを確認**

```
run-tests system="recurya/tests" test="recurya/tests/web/notebook-routes"
```

期待: ルート未登録エラー。

**Step 3: `web/routes.lisp` の `setup-routes` を更新**

各ルートのパスを `/dashboard` プレフィックス付きに置換。
ハンドラ関数名は変えない（`user-notebook-*-handler` → `notebook-*-handler` の rename はあり得るが、Phase 3 でやらなければそのままで OK）。

例:

```lisp
;; 変更前:
(setf (ningle:route app "/notebooks/me" :method :get)
      (lambda (params) (user-notebook-me-handler params)))
;; 変更後:
(setf (ningle:route app "/dashboard/notebooks" :method :get)
      (lambda (params) (notebook-dashboard-handler params)))
```

ハンドラ内の生成 URL も置換（HTMX `hx-post`, リダイレクト先, リンク`href`）:

```
clgrep-search pattern="/notebooks/" path="web/"
```

`render-user-notebook-status-pill` 内の `hx-post` URL なども `/dashboard/notebooks/:id/toggle-status` に置換。

**Step 4: テストを再実行**

```
run-tests system="recurya/tests" test="recurya/tests/web/notebook-routes"
```

期待: 緑。

**Step 5: コミット**

```bash
git add -u
git commit -m "feat: move notebook admin routes under /dashboard/notebooks"
```

---

### Task 14: `/dashboard/courses` 系ハンドラ移行

**Files:**
- Modify: `web/routes.lisp`
- Modify: `tests/web/course-routes.lisp`

**Step 1〜5:** Task 13 と同じパターンで `/courses/me`, `/courses/new`, `/courses/:id/...` を `/dashboard/courses/...` に移行。

**Step 6: コミット**

```bash
git add -u
git commit -m "feat: move course admin routes under /dashboard/courses"
```

---

### Task 15: `/dashboard` ルート（自分のNotebook一覧へ）

**Files:**
- Modify: `web/routes.lisp`

**Step 1: `dashboard-home-handler` を追加**

```lisp
(defun dashboard-home-handler (params)
  "Handle GET /dashboard - redirect to /dashboard/notebooks."
  (declare (ignore params))
  (redirect "/dashboard/notebooks"))
```

`setup-routes` に登録。

**Step 2: テスト追加**

```lisp
(deftest dashboard-home-redirects-to-notebooks
  (testing "GET /dashboard redirects to /dashboard/notebooks"
    ;; ログイン済みセッションで GET /dashboard → 302 /dashboard/notebooks
    ))
```

**Step 3: 実行 → 緑 → コミット**

```bash
git add -u
git commit -m "feat: /dashboard root redirects to notebooks"
```

---

### Task 16: 公開ルックアップ `/@:handle/:slug`

**Files:**
- Modify: `web/routes.lisp`
- Modify: `tests/web/notebook-routes.lisp`

**Step 1: 公開Notebook詳細のテスト追加**

```lisp
(deftest public-notebook-by-handle
  (testing "different authors can serve same slug"
    (let ((alice (make-test-user :handle "alice" :email "a@x.com"))
          (bob   (make-test-user :handle "bob"   :email "b@x.com")))
      (make-test-notebook :author alice :slug "intro" :title "Alice Intro"
                          :status "published" :visibility "public")
      (make-test-notebook :author bob   :slug "intro" :title "Bob Intro"
                          :status "published" :visibility "public")
      ;; GET /@alice/intro → "Alice Intro" 含む
      ;; GET /@bob/intro   → "Bob Intro" 含む
      ))
  (testing "private notebook returns 404 to non-owner"
    ;; private notebook を別ユーザーで GET → 404
    )
  (testing "draft notebook returns 404 to non-owner"
    ;; draft notebook を未ログインで GET → 404
    ))
```

**Step 2: テストfail確認 → 実装**

`web/routes.lisp` に追加:

```lisp
(defun public-notebook-by-handle-handler (params)
  "Handle GET /@:handle/:slug - public notebook detail by author handle."
  (let* ((handle (get-path-param params :handle))
         (slug (get-path-param params :slug))
         (author (mito:find-dao 'recurya/models/users:users :handle handle)))
    (cond
      ((null author) (not-found-handler params))
      (t
       (let ((nb (mito:find-dao 'recurya/models/notebook:notebook
                                :author author :slug slug)))
         (cond
           ((null nb) (not-found-handler params))
           ((not (notebook-publicly-viewable-p nb (get-current-user)))
            (not-found-handler params))
           (t (html-response (render-public-notebook-page nb)))))))))
```

`notebook-publicly-viewable-p` ヘルパー:

```lisp
(defun notebook-publicly-viewable-p (nb viewer)
  "True if NB is publicly viewable, or VIEWER is the owner."
  (or (and (string= (recurya/models/notebook:notebook-status nb) "published")
           (string= (recurya/models/notebook:notebook-visibility nb) "public"))
      (and viewer
           (equal (recurya/models/notebook:notebook-author-id nb)
                  (getf viewer :id)))))
```

**Step 3: ルート登録**

```lisp
;; Ningle のパスパラメタ構文で `:handle` `:slug` をキャプチャ
(setf (ningle:route app "/@:handle/:slug" :method :get)
      (lambda (params) (public-notebook-by-handle-handler params)))
```

**注:** Ningle で `@` 文字を含むパスパターンが受け付けられるか確認する。受け付けない場合は別のルーティング方法（直接マッチ + パスパースなど）を検討する。

**Step 4: テスト実行 → 緑**

**Step 5: コミット**

```bash
git add -u
git commit -m "feat: public notebook detail at /@handle/slug"
```

---

### Task 17: セル実行 `/@:handle/:slug/cells/:i/run`

**Files:**
- Modify: `web/routes.lisp`

**Step 1: 既存 `public-user-notebook-cell-run-handler` のシグネチャ調整**

slug ルックアップを `(handle, slug)` に変更。HTMX `hx-post` URL も対応。

**Step 2: ルート登録**

```lisp
(setf (ningle:route app "/@:handle/:slug/cells/:index/run" :method :post)
      (lambda (params) (public-cell-run-handler params)))
```

**Step 3: ノートブックのレンダリング箇所で `hx-post` を新URLに置換**

`web/ui/notebook.lisp` 内、cell の Run ボタンの `hx-post` 値を `/@<handle>/<slug>/cells/<i>/run` に。

**Step 4: テスト**

ハンドラのテストを書き、緑にする。

**Step 5: コミット**

```bash
git add -u
git commit -m "feat: cell-run endpoint moves under /@handle/slug"
```

---

### Task 18: 公開コース `/c/@:handle/:slug`

**Files:**
- Modify: `web/routes.lisp`
- Modify: `tests/web/course-routes.lisp`

**Step 1〜5:** Task 16 と同じパターンで Course 公開詳細に適用。
Ningle のルート: `/c/@:handle/:slug`

```bash
git add -u
git commit -m "feat: public course detail at /c/@handle/slug"
```

---

### Task 19: ユーザープロフィール `/@:handle`

**Files:**
- Create: `web/ui/profile.lisp`
- Modify: `web/routes.lisp`
- Modify: `recurya.asd`

**Step 1: `web/ui/profile.lisp` を作成**

```lisp
(defpackage #:recurya/web/ui/profile
  (:use #:cl #:spinneret)
  (:import-from #:recurya/web/ui/layout #:render-layout)
  (:export #:render-profile-page))

(in-package #:recurya/web/ui/profile)

(defun render-profile-page (&key handle display-name notebooks courses)
  (render-layout
    :title (format nil "@~A" handle)
    :body (with-html-string
            (:div :class "max-w-3xl mx-auto py-8"
              (:h1 (format nil "@~A" handle))
              (when display-name
                (:p :class "text-gray-600" display-name))
              (:section
                (:h2 "Notebooks")
                (:ul
                  (loop for nb in notebooks do
                    (:li
                      (:a :href (format nil "/@~A/~A" handle (getf nb :slug))
                          (getf nb :title))))))
              (:section
                (:h2 "Courses")
                (:ul
                  (loop for c in courses do
                    (:li
                      (:a :href (format nil "/c/@~A/~A" handle (getf c :slug))
                          (getf c :title))))))))))
```

**Step 2: ルートとハンドラ**

```lisp
(defun profile-handler (params)
  "Handle GET /@:handle - public profile with notebooks and courses."
  (let* ((handle (get-path-param params :handle))
         (user (mito:find-dao 'recurya/models/users:users :handle handle)))
    (if (null user)
        (not-found-handler params)
        (html-response
          (recurya/web/ui/profile:render-profile-page
            :handle handle
            :display-name (recurya/models/users:users-display-name user)
            :notebooks (list-public-notebooks-of user)
            :courses (list-public-courses-of user))))))
```

`list-public-notebooks-of` / `list-public-courses-of` は `db/notebooks.lisp` / `db/courses.lisp` に追加（status=published かつ visibility=public のみ抽出）。

**Step 3: ルート登録**

```lisp
(setf (ningle:route app "/@:handle" :method :get)
      (lambda (params) (profile-handler params)))
```

**Step 4: `recurya.asd` に `recurya/web/ui/profile` 追加**

**Step 5: テスト追加 + 緑 + コミット**

```bash
git add -u
git commit -m "feat: public profile page at /@handle"
```

---

### Task 20: ハイブリッドホーム `/`

**Files:**
- Modify: `web/routes.lisp`
- Modify: `tests/web/routes.lisp`

**Step 1: `root-handler` を書き換え**

```lisp
(defun root-handler (params)
  "Handle / - hybrid home: dashboard for logged-in, public list otherwise."
  (declare (ignore params))
  (let ((user (get-current-user)))
    (if user
        (redirect "/dashboard")
        (redirect "/notebooks"))))
```

**Step 2: テスト**

```lisp
(deftest root-hybrid
  (testing "logged-out goes to /notebooks"
    ;; GET / without session → 302 /notebooks
    )
  (testing "logged-in goes to /dashboard"
    ;; GET / with session → 302 /dashboard
    ))
```

**Step 3: 実行 → 緑 → コミット**

```bash
git add -u
git commit -m "feat: hybrid root handler"
```

---

### Task 21: 旧ルートと短縮URL削除、wardlisp/learn リダイレクト先更新

**Files:**
- Modify: `web/routes.lisp`
- Modify: `web/routes-wardlisp.lisp`

**Step 1: 旧ルートのリスティング除去**

`setup-routes` から削除:
- `/notebooks/me`, `/notebooks/new`, `/notebooks/:id/...`
- `/courses/me`, `/courses/new`, `/courses/:id/...`
- `/n/:slug`, `/n/:slug/cells/:index/run`
- `/c/:slug`

ハンドラ関数本体は Phase 7 で全て新URL用に書き換えているはず。重複するハンドラがあれば古いものを削除。

**Step 2: SICP 正規著者ハンドルを決定し、リダイレクト先を更新**

`web/routes-wardlisp.lisp`:
- `sicp-learn-redirect-handler`: `/wardlisp/learn` → `/c/@<sicp-author-handle>/sicp`
- `sicp-notebook-redirect-handler`: `/wardlisp/learn/:id` → `/@<sicp-author-handle>/:id`
- `sicp-cell-run-redirect-handler`: 同上

`<sicp-author-handle>` は定数で、例: `(defparameter +sicp-author-handle+ "recurya")`。

**Step 3: テスト更新**

`tests/web/learn-routes.lisp` のリダイレクト先期待値を更新。

**Step 4: 実行 → 緑 → コミット**

```bash
git add -u
git commit -m "feat: drop legacy routes and update wardlisp redirects"
```

---

## Phase 8: 認可ミドルウェア

### Task 22: `/dashboard/*` 認証ガード + ハンドル必須リダイレクト

**Files:**
- Modify: `web/auth.lisp`
- Modify: `web/app.lisp`
- Modify: `tests/web/auth.lisp` または `tests/web/oauth.lisp`

**Step 1: ミドルウェア関数を追加**

`web/auth.lisp`:

```lisp
(defun require-authenticated-and-handle (app)
  "Middleware: require auth for /dashboard/* and /onboarding/handle except as GET form."
  (lambda (env)
    (let ((path (getf env :path-info))
          (session (getf env :lack.session)))
      (cond
        ;; /dashboard 配下 + 未認証 → /login
        ((and (alexandria:starts-with-subseq "/dashboard" path)
              (null (gethash :user session)))
         '(302 (:location "/login") ("")))
        ;; /dashboard 配下 + 認証済 + handle 未設定 → /onboarding/handle
        ((and (alexandria:starts-with-subseq "/dashboard" path)
              (gethash :user session)
              (let ((u (gethash :user session)))
                (or (null (getf u :handle))
                    (zerop (length (getf u :handle))))))
         '(302 (:location "/onboarding/handle") ("")))
        (t (funcall app env))))))
```

**Step 2: `web/app.lisp` でミドルウェアを登録**

既存の middleware chain に挿入。

**Step 3: テスト**

```lisp
(deftest dashboard-auth-guard
  (testing "unauthenticated GET /dashboard → 302 /login"
    ...)
  (testing "authenticated without handle GET /dashboard → 302 /onboarding/handle"
    ...)
  (testing "authenticated with handle GET /dashboard → 200"
    ...))
```

**Step 4: 実行 → 緑 → コミット**

```bash
git add -u
git commit -m "feat: auth guard for /dashboard with handle-required redirect"
```

---

## Phase 9: UI/ナビゲーション更新

### Task 23: レイアウトのナビゲーション再構築

**Files:**
- Modify: `web/ui/layout.lisp`

**Step 1: 既存ナビを確認**

```
lisp-read-file path="web/ui/layout.lisp" name_pattern="render-layout|render-nav"
```

**Step 2: ナビゲーションを以下のように置換**

ログイン時:
- ホーム (`/`)
- 公開Notebook (`/notebooks`)
- 公開Course (`/courses`)
- ダッシュボード (`/dashboard`)
- アカウント (`/account`)
- ログアウトボタン

未ログイン時:
- ホーム (`/`)
- 公開Notebook (`/notebooks`)
- 公開Course (`/courses`)
- ログイン (`/login`)

**Step 3: ノートブック/コースカード UI に著者リンク追加**

`web/ui/notebook-list.lisp`, `web/ui/course-list.lisp`:
- 各カードに `@handle` リンク（`/@<handle>` へ）
- カード本体のリンク先を `/@<handle>/<slug>` (notebook) または `/c/@<handle>/<slug>` (course) に

**Step 4: コンパイル + 全テスト + 手動確認**

```
load-system system="recurya" force=true
```

ブラウザで `/`, `/notebooks`, `/dashboard` を巡回。

**Step 5: コミット**

```bash
git add -u
git commit -m "feat: update navigation and link targets for new URL scheme"
```

---

### Task 24: 残存する旧URL参照の掃除

**Files:**
- 全プロジェクト

**Step 1: `clgrep-search` で旧 URL を網羅検索**

```
clgrep-search pattern="/posts/|/blog|/notebooks/me|/notebooks/new|/n/[^:]|/c/[^@]|/courses/me|/courses/new"
```

**Step 2: ヒットした各箇所を新 URL に置換**

`hx-get`, `hx-post`, `hx-target`, `<a href>`, `redirect`, `format` などすべて。

**Step 3: 全テスト実行**

```
run-tests system="recurya/tests"
```

期待: 緑。

**Step 4: 手動確認**

ブラウザで主要動線:
- ログイン → /dashboard へ
- /dashboard/notebooks/new → 作成 → /dashboard/notebooks 一覧
- 公開設定 → `/@<my-handle>/<slug>` を直接踏んで閲覧
- 別ブラウザ（未ログイン）で同URLを踏んで閲覧
- /notebooks 一覧から記事クリック → /@handle/slug

**Step 5: コミット**

```bash
git add -u
git commit -m "chore: sweep remaining legacy URL references"
```

---

## Phase 10: SICP シード調整

### Task 25: SICP 正規著者ユーザーをシード

**Files:**
- Modify: `scripts/` 配下のシードスクリプト
- Modify: `web/routes-wardlisp.lisp` の `+sicp-author-handle+` 値を確定

**Step 1: シードスクリプトを確認**

```
fs-list-directory path="scripts"
```

`scripts/` 内のシードスクリプトに `recurya` ハンドルの admin ユーザーを作成し、SICP コースとそのノートブック群を author=recurya で作成するよう更新。

**Step 2: 開発DBにシード適用**

```bash
docker compose exec recurya qlot exec ros run -e '(asdf:load-system :recurya)' \
  -e '(load "scripts/seed-sicp.lisp")' -q   # スクリプト名は実際のものに合わせる
```

**Step 3: 動作確認**

```bash
curl -i http://localhost:3000/wardlisp/learn
# 期待: 302 → /c/@recurya/sicp
```

**Step 4: コミット**

```bash
git add -u
git commit -m "feat: seed SICP under recurya admin handle"
```

---

## Phase 11: 最終検証

### Task 26: フルコンパイル + 全テスト + 手動確認

**Step 1: クリーンビルド**

```
load-system system="recurya" force=true clear_fasls=true
```

期待: 警告ゼロ・エラーなし。

**Step 2: 全テスト実行**

```
run-tests system="recurya/tests"
```

期待: 全 green。

**Step 3: 主要動線の手動確認**

1. `/` 未ログイン → `/notebooks` リダイレクト
2. `/login` → OAuth → 初回 → `/onboarding/handle` 強制
3. ハンドル設定 → `/dashboard`
4. `/dashboard/notebooks/new` → 作成 → `/dashboard/notebooks`
5. ステータス公開 → `/@<handle>/<slug>` を別ブラウザで閲覧
6. セル実行 → 結果表示
7. `/dashboard/courses/new` → 作成 → notebook attach → 公開 → `/c/@<handle>/<slug>`
8. `/wardlisp/learn` → `/c/@recurya/sicp`
9. `/account` でアカウント設定
10. ログアウト → `/login`

**Step 4: 設計書からの逸脱チェック**

`docs/plans/2026-05-09-notebook-unification-design.md` と実装を突き合わせ、未着手・差分があればフォローアップタスクとして追加。

**Step 5: 完了コミット（あれば）**

```bash
git add -u
git commit -m "chore: final verification" --allow-empty
```

`--allow-empty` は変更なしで完了マーカーを残したい場合のみ。通常は不要。

---

## 完了基準

- [ ] `feat/notebook-unification` ブランチで全 Phase 完了
- [ ] `(asdf:compile-system :recurya :force t)` 警告ゼロ
- [ ] `run-tests system="recurya/tests"` 全 green
- [ ] 設計書の URL スキームと一致
- [ ] 手動動線確認パス
- [ ] PR 作成（マージは別作業）

## ロールバック

各タスクごとにコミット済みなので、問題発生時は `git revert` で個別撤回可能。
DB は破壊的マイグレーションを含むため、本番投入前にバックアップ必須（開発環境では `TRUNCATE` で再構築可能）。
