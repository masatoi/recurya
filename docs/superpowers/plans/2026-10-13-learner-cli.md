# 学習者向け CLI (JSON API + 個人用アクセストークン) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 学習者が手元のエディタでノートブックの演習を書き、`recurya` CLI から実行・提出でき、進捗が Web UI と共有されるようにする。

**Architecture:** `/api/v1/*` の JSON ルート群を新設し、Bearer トークン専用のミドルウェアで認証する (Cookie セッションは `/api/*` では使わない)。セル実行と保存は既存 Web ハンドラから共有関数 (`recurya/web/notebook-service`) と純粋なゲーティング関数 (`recurya/game/notebook-gating`) に抽出し、Web と API が同じ経路を通る。CLI は同じ package-inferred ツリー内の `recurya/cli/*` (サーバ系に非依存) と `roswell/recurya.ros`。

**Tech Stack:** Common Lisp (SBCL), Ningle/Lack, Mito/PostgreSQL, Spinneret + HTMX, com.inuoe.jzon, ironclad, dexador, Rove, cl-spec, Roswell.

**Spec:** `docs/superpowers/specs/2026-10-13-learner-cli-design.md`

## Global Constraints

- `.lisp` / `.asd` の読み書きは cl-mcp ツールのみ (`lisp-read-file`, `lisp-edit-form`, `lisp-patch-form`, `fs-write-file` は新規ファイルのみ, `clgrep-search`)。Read/Edit/Write/grep/sed を Lisp ファイルに使わない。
- シェルで許可されるのは `git`, `gh`, `mallet`, `.qlot/bin/mito`, `psql`, `curl`, `qlot exec ros`, `./scripts/*.sh`。テストは `run-tests`、評価は `repl-eval`。
- `deftable` 追加 (`api_token`) はユーザー承認済み (2026-10-13)。他テーブルは変更しない。
- 既存の cl-spec 契約を弱めない。既存テストは無変更で緑のまま (共有関数抽出で Web の振る舞いは不変)。
- 稼働中の Web サーバと同じワーカーで `repl-eval` から グローバル DB 接続を叩かない (ハングする)。DB を使う確認はテスト (`with-test-db`) か新規 `dbi:connect` で。
- jzon の境界: Lisp の `nil` は JSON `false` になる。JSON null は `'null`、空配列は `#()` (ベクタ) を明示する。
- 平文トークンは DB に保存しない。トークン書式: `rcy_` + 64 桁小文字 hex (計 68 文字)。
- 1 ユーザーあたり有効トークン最大 10。
- API エラー形: `{"error": {"code": "...", "message": "..."}}`。コード: `unauthorized` 401 / `not_found` 404 / `bad_json` 400 / `invalid_request` 422 / `internal` 500。
- i18n: 新しい UI 文言は `web/i18n/en.lisp` と `web/i18n/ja.lisp` の両方に同じキーで追加 (カタログ一致テストあり)。
- コミット末尾: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`。ブランチは `feat/learner-cli`。

### Spec からの確定事項 (計画時に判明)

- `api_token` の主キーは Mito 既定の BIGSERIAL `id` (learn_* テーブルと同じ規約)。spec の「uuid PK」はこれで置き換える。`user_id` は learn_* と同じく FK なしの UUID 列で、認証時にユーザー行の存在を確認する。
- 本番ドメインがリポジトリに無いため、CLI に既定サーバは埋め込まない。初回 `login` で `--server` (または `RECURYA_SERVER`) を必須とし、以後は設定ファイルの値を使う。
- 配布は「リポジトリを clone して `roswell/recurya.ros` を実行 (または `ros build` でバイナリ化)」を正とする。`ros install masatoi/recurya` は Roswell がリポジトリ名のシステム (`recurya`、Quicklisp 外の wardlisp に依存) を quickload しようとして失敗しうるため、v1 では案内しない。
- CLI のコードは独立 `.asd` ではなく `recurya` package-inferred ツリーの `cli/` 配下 (`recurya/cli/*`)。サブシステムはプライマリの `:depends-on` を引き込まないので、サーバ系依存はロードされない (Task 7 のテストで保証)。

## File Structure

| ファイル | 役割 |
|---|---|
| `models/api-token.lisp` (新) | `api-token` deftable |
| `db/migrations/<ts>.up.sql` / `.down.sql`, `db/schema.sql` (生成) | `api_token` テーブル |
| `db/api-tokens.lisp` (新) | 発行・認証・一覧・失効、トークン名正規化 |
| `db/users.lisp` (変更) | `user-dao->plist` を routes から移設・export |
| `specs/db/api-tokens.lisp` (新) | cl-spec: トークンのライフサイクル Property、名前正規化 Function Spec |
| `web/http.lisp` (新) | `read-request-body`, `json-response` (routes から移設) |
| `web/api-auth.lisp` (新) | `api-token-auth` ミドルウェア、`api-path-p`、`api-error-response` |
| `web/server.lisp`, `web/auth.lisp` (変更) | ミドルウェア組込み、CSRF / onboarding 除外 |
| `game/notebook-gating.lisp` (新) | 解答解放判定の純粋関数 |
| `web/notebook-service.lisp` (新) | `notebook-row->notebook-struct`, `persist-cell-run`, `run-notebook-cell` |
| `web/ui/notebook.lisp`, `web/routes.lisp` (変更) | 共有関数を使うよう置換 |
| `web/routes-api.lisp` (新) | `/api/v1/*` ハンドラと登録 |
| `web/app.lisp` (変更) | `setup-api-routes` 呼び出し |
| `web/ui/account.lisp`, `web/routes.lisp`, `web/i18n/{en,ja}.lisp` (変更) | トークン管理 UI |
| `cli/workspace.lisp`, `cli/report.lisp`, `cli/config.lisp`, `cli/client.lisp`, `cli/main.lisp` (新) | CLI |
| `roswell/recurya.ros` (新) | CLI エントリ |
| `tests/db/api-tokens.lisp`, `tests/web/api-auth.lisp`, `tests/game/notebook-gating.lisp`, `tests/web/api-routes.lisp`, `tests/web/account-tokens.lisp`, `tests/cli/workspace.lisp`, `tests/cli/report.lisp`, `tests/cli/main.lisp` (新) | テスト |
| `recurya.asd`, `tests/all.lisp`, `tests/support/db.lisp`, `tests/specs/contracts.lisp`, `specs/all.lisp` (変更) | 登録 |
| `scripts/request-test.sh` (変更), `scripts/cli-e2e.sh` (新) | HTTP 検証 / E2E |
| `docs/CLI.md` (新), `docs/DEVELOPMENT.md`, `README.md` (変更) | ドキュメント |

---

### Task 1: `api_token` テーブルと DB 層

**Files:**
- Create: `models/api-token.lisp`, `db/api-tokens.lisp`, `tests/db/api-tokens.lisp`
- Generate: `db/migrations/<ts>.up.sql`, `db/migrations/<ts>.down.sql`, `db/schema.sql`
- Modify: `recurya.asd` (production `:depends-on` に model と db、tests に test)、`tests/all.lisp`、`tests/support/db.lisp` (`cleanup-all-test-data`)

**Interfaces:**
- Produces (`recurya/models/api-token`): `api-token` クラス、`api-token-id`, `api-token-user-id`, `api-token-name`, `api-token-token-hash`, `api-token-token-prefix`, `api-token-last-used-at`, `api-token-revoked-at`, `api-token-created-at`。
- Produces (`recurya/db/api-tokens`):
  - `*max-active-tokens*` = 10、`*token-prefix*` = `"rcy_"`
  - `(token-format-p x)` → boolean
  - `(hash-token plaintext)` → 64 桁小文字 hex 文字列
  - `(normalize-token-name name)` → 前後空白除去、空なら `"cli"`、最大 64 文字
  - `(issue-api-token user-id name)` → `(values plaintext row)`; 上限超過で `api-token-limit-exceeded` を signal
  - `(authenticate-api-token plaintext)` → `users` DAO または NIL (成功時 `last_used_at` 更新)
  - `(list-api-tokens user-id)` → 有効 (未失効) トークン行のリスト、新しい順
  - `(revoke-api-token user-id token-id)` → 自分の未失効トークンを失効させたら T、それ以外 NIL
  - condition `api-token-limit-exceeded` (reader `api-token-limit-exceeded-user-id`)

- [ ] **Step 1: モデルを作る**

`fs-write-file` で `models/api-token.lisp`:

```lisp
;;;; models/api-token.lisp --- Mito table for personal API access tokens.

(defpackage #:recurya/models/api-token
  (:use #:cl #:mito)
  (:export #:api-token
           #:api-token-id
           #:api-token-user-id
           #:api-token-name
           #:api-token-token-hash
           #:api-token-token-prefix
           #:api-token-last-used-at
           #:api-token-revoked-at
           #:api-token-created-at))

(in-package #:recurya/models/api-token)

(deftable api-token ()
  ((user-id :col-type :uuid
            :initarg :user-id
            :accessor api-token-user-id)
   (name :col-type (:varchar 64)
         :initarg :name
         :accessor api-token-name)
   (token-hash :col-type (:varchar 64)
               :initarg :token-hash
               :accessor api-token-token-hash)
   (token-prefix :col-type (:varchar 12)
                 :initarg :token-prefix
                 :accessor api-token-token-prefix)
   (last-used-at :col-type (or :timestamptz :null)
                 :initarg :last-used-at
                 :initform nil
                 :accessor api-token-last-used-at)
   (revoked-at :col-type (or :timestamptz :null)
               :initarg :revoked-at
               :initform nil
               :accessor api-token-revoked-at))
  (:unique-keys token-hash)
  (:keys user-id)
  (:documentation "Personal access token for the JSON API. Only the SHA-256 of
the plaintext is stored; TOKEN-PREFIX keeps the first characters for display.
A non-NULL REVOKED-AT disables the token."))

(defun api-token-id (row) (mito:object-id row))
(defun api-token-created-at (row) (mito:object-created-at row))
```

`lisp-check-parens` で確認。`recurya.asd` の production `:depends-on` の Models 群 (`"recurya/models/novel-state"` の後) に `"recurya/models/api-token"` を `lisp-patch-form` (form_type `defsystem`, form_name `recurya`) で追加。

- [ ] **Step 2: マイグレーションを生成して内容を確認**

`load-system recurya` 後に:

```bash
.qlot/bin/mito generate-migrations -t postgres -H localhost -P 15434 \
  -d recurya -u postgres -p postgres -s recurya -D db/
```

期待される `db/migrations/<ts>.up.sql` (列順は Mito 次第で前後してよい):

```sql
CREATE TABLE "api_token" (
    "id" BIGSERIAL NOT NULL PRIMARY KEY,
    "user_id" UUID NOT NULL,
    "name" VARCHAR(64) NOT NULL,
    "token_hash" VARCHAR(64) NOT NULL,
    "token_prefix" VARCHAR(12) NOT NULL,
    "last_used_at" TIMESTAMPTZ,
    "revoked_at" TIMESTAMPTZ,
    "created_at" TIMESTAMPTZ,
    "updated_at" TIMESTAMPTZ
);
CREATE UNIQUE INDEX "unique_api_token_token_hash" ON "api_token" ("token_hash");
CREATE INDEX "key_api_token_user_id" ON "api_token" ("user_id");
```

他テーブルへの差分が混ざっていたら止めてユーザーに報告する (モデルとスキーマのずれ)。`db/schema.sql` にも `api_token` が追記されていることを `git diff db/schema.sql` で確認。

- [ ] **Step 3: dev DB と test DB に適用**

```bash
.qlot/bin/mito migrate -t postgres -H localhost -P 15434 \
  -d recurya -u postgres -p postgres -s recurya -D db/
PGPASSWORD=postgres psql -h localhost -p 15434 -U postgres -d recurya_test \
  -f db/migrations/<ts>.up.sql
```

(`recurya_test` は `users` テーブルがあると schema.sql を再適用しないため、新テーブルは手で入れる。CI は空 DB に schema.sql を流すので不要。)

- [ ] **Step 4: テストデータ掃除に追加**

`tests/support/db.lisp` の `cleanup-all-test-data` に `lisp-patch-form`:
old `  (execute! "DELETE FROM novel_state")` → new
```lisp
  (execute! "DELETE FROM api_token")
  (execute! "DELETE FROM novel_state")
```

- [ ] **Step 5: 失敗するテストを書く**

`fs-write-file` で `tests/db/api-tokens.lisp`:

```lisp
;;;; tests/db/api-tokens.lisp --- Tests for personal API token storage.

(defpackage #:recurya/tests/db/api-tokens
  (:use #:cl #:rove)
  (:import-from #:recurya/tests/support/db
                #:with-test-db
                #:create-test-user)
  (:import-from #:recurya/db/users
                #:users-id
                #:users-email
                #:delete-user!)
  (:import-from #:recurya/db/core
                #:null->nil)
  (:import-from #:recurya/models/api-token
                #:api-token-id
                #:api-token-name
                #:api-token-token-hash
                #:api-token-token-prefix
                #:api-token-last-used-at)
  (:import-from #:recurya/db/api-tokens
                #:*max-active-tokens*
                #:token-format-p
                #:hash-token
                #:normalize-token-name
                #:issue-api-token
                #:authenticate-api-token
                #:list-api-tokens
                #:revoke-api-token
                #:api-token-limit-exceeded))

(in-package #:recurya/tests/db/api-tokens)

(defun same-id-p (a b)
  (string-equal (princ-to-string a) (princ-to-string b)))

(deftest issue-returns-plaintext-once-and-stores-only-hash
  (with-test-db
    (let ((user (create-test-user :email-prefix "tok")))
      (multiple-value-bind (plain row) (issue-api-token (users-id user) "laptop")
        (ok (token-format-p plain) "plaintext has the rcy_ + 64 hex shape")
        (ok (= 68 (length plain)))
        (ok (string= (hash-token plain) (api-token-token-hash row)) "row keeps the hash")
        (ng (string= plain (api-token-token-hash row)) "row never keeps the plaintext")
        (ok (string= (subseq plain 0 12) (api-token-token-prefix row)))
        (ok (string= "laptop" (api-token-name row)))))))

(deftest authenticate-accepts-only-live-tokens
  (with-test-db
    (let* ((user (create-test-user :email-prefix "tok"))
           (plain (issue-api-token (users-id user) "a")))
      (let ((found (authenticate-api-token plain)))
        (ok found "a freshly issued token authenticates")
        (ok (same-id-p (users-id user) (users-id found)) "to its owner"))
      (ok (null->nil (api-token-last-used-at (first (list-api-tokens (users-id user)))))
          "authentication records last_used_at")
      (ng (authenticate-api-token nil))
      (ng (authenticate-api-token "garbage"))
      (ng (authenticate-api-token (concatenate 'string "rcy_" (make-string 64 :initial-element #\0)))
          "a well-formed but unknown token is refused"))))

(deftest revoke-disables-and-is-owner-only
  (with-test-db
    (let* ((alice (create-test-user :email-prefix "tok-a"))
           (bob (create-test-user :email-prefix "tok-b")))
      (multiple-value-bind (plain row) (issue-api-token (users-id alice) "a")
        (ng (revoke-api-token (users-id bob) (api-token-id row)) "bob cannot revoke alice's token")
        (ok (authenticate-api-token plain) "still valid after bob's attempt")
        (ok (revoke-api-token (users-id alice) (api-token-id row)) "owner revokes")
        (ng (revoke-api-token (users-id alice) (api-token-id row)) "second revoke is a no-op")
        (ng (authenticate-api-token plain) "revoked token is refused")
        (ok (null (list-api-tokens (users-id alice))) "revoked tokens are not listed")))))

(deftest issue-enforces-active-token-limit
  (with-test-db
    (let* ((user (create-test-user :email-prefix "tok"))
           (uid (users-id user))
           (rows (loop repeat *max-active-tokens*
                       collect (nth-value 1 (issue-api-token uid "t")))))
      (ok (signals (issue-api-token uid "one too many") 'api-token-limit-exceeded))
      (revoke-api-token uid (api-token-id (first rows)))
      (ok (issue-api-token uid "fits again") "revoking frees a slot"))))

(deftest deleted-user-token-is-refused
  (with-test-db
    (let* ((user (create-test-user :email-prefix "tok"))
           (plain (issue-api-token (users-id user) "a")))
      (delete-user! (users-email user))
      (ng (authenticate-api-token plain)))))

(deftest normalize-token-name-rules
  (ok (string= "cli" (normalize-token-name "")))
  (ok (string= "cli" (normalize-token-name "   ")))
  (ok (string= "ci box" (normalize-token-name "  ci box  ")))
  (ok (= 64 (length (normalize-token-name (make-string 80 :initial-element #\a))))))
```

`recurya.asd` の `recurya/tests` `:depends-on` の DB tests 群に `"recurya/tests/db/api-tokens"`、`tests/all.lisp` の `*test-packages*` に `:recurya/tests/db/api-tokens` を追加 (`lisp-patch-form`)。

- [ ] **Step 6: 失敗を確認**

`run-tests` `{"system":"recurya/tests","test":"recurya/tests/db/api-tokens::issue-returns-plaintext-once-and-stores-only-hash"}` (先に `load-system recurya/tests` が package 不在で失敗するのが期待される red: `recurya/db/api-tokens` 未定義)。

- [ ] **Step 7: DB 層を実装**

`fs-write-file` で `db/api-tokens.lisp`:

```lisp
;;;; db/api-tokens.lisp --- Personal API access tokens: issue, authenticate, revoke.
;;;;
;;;; Tokens are "rcy_" + 64 lower-case hex characters drawn from a strong
;;;; random source.  Only their SHA-256 is stored, so a leaked table does not
;;;; leak usable tokens; the plaintext is returned once, at issue time.

(defpackage #:recurya/db/api-tokens
  (:use #:cl #:mito #:sxql)
  (:import-from #:recurya/models/api-token
                #:api-token
                #:api-token-user-id
                #:api-token-revoked-at
                #:api-token-last-used-at)
  (:import-from #:recurya/db/users
                #:get-user-by-id)
  (:import-from #:recurya/db/core
                #:null->nil)
  (:import-from #:local-time
                #:now)
  (:import-from #:ironclad
                #:random-data
                #:digest-sequence
                #:byte-array-to-hex-string)
  (:import-from #:babel
                #:string-to-octets)
  (:export #:*max-active-tokens*
           #:*token-prefix*
           #:token-format-p
           #:hash-token
           #:normalize-token-name
           #:issue-api-token
           #:authenticate-api-token
           #:list-api-tokens
           #:revoke-api-token
           #:api-token-limit-exceeded
           #:api-token-limit-exceeded-user-id))

(in-package #:recurya/db/api-tokens)

(defparameter *token-prefix* "rcy_"
  "Prefix of every plaintext API token.")

(defparameter *max-active-tokens* 10
  "Most unrevoked tokens one user may hold.")

(define-condition api-token-limit-exceeded (error)
  ((user-id :initarg :user-id :reader api-token-limit-exceeded-user-id))
  (:report (lambda (c stream)
             (format stream "User ~A already holds ~D active API tokens"
                     (api-token-limit-exceeded-user-id c) *max-active-tokens*))))

(defun token-format-p (value)
  "True when VALUE is a string shaped like a plaintext token: *TOKEN-PREFIX*
followed by exactly 64 lower-case hex digits."
  (and (stringp value)
       (= (length value) (+ (length *token-prefix*) 64))
       (string= *token-prefix* value :end2 (length *token-prefix*))
       (every (lambda (ch) (find ch "0123456789abcdef"))
              (subseq value (length *token-prefix*)))))

(defun hash-token (plaintext)
  "SHA-256 of PLAINTEXT's UTF-8 octets as 64 lower-case hex digits."
  (byte-array-to-hex-string
   (digest-sequence :sha256 (string-to-octets plaintext :encoding :utf-8))))

(defun normalize-token-name (name)
  "NAME without surrounding whitespace, cut to 64 characters; a blank or
non-string NAME becomes \"cli\"."
  (let ((trimmed (if (stringp name)
                     (string-trim '(#\Space #\Tab #\Newline #\Return) name)
                     "")))
    (if (zerop (length trimmed))
        "cli"
        (subseq trimmed 0 (min 64 (length trimmed))))))

(defun generate-token ()
  "A fresh plaintext token."
  (concatenate 'string *token-prefix* (byte-array-to-hex-string (random-data 32))))

(defun list-api-tokens (user-id)
  "USER-ID's unrevoked token rows, newest first."
  (select-dao 'api-token
    (where (:and (:= :user-id user-id)
                 (:is-null :revoked-at)))
    (order-by (:desc :created-at))))

(defun issue-api-token (user-id name)
  "Issue a token for USER-ID named NAME (normalised by NORMALIZE-TOKEN-NAME).
Returns (VALUES PLAINTEXT ROW).  Signals API-TOKEN-LIMIT-EXCEEDED when the user
already holds *MAX-ACTIVE-TOKENS* unrevoked tokens."
  (when (>= (length (list-api-tokens user-id)) *max-active-tokens*)
    (error 'api-token-limit-exceeded :user-id user-id))
  (let* ((plaintext (generate-token))
         (row (insert-dao (make-instance 'api-token
                                         :user-id user-id
                                         :name (normalize-token-name name)
                                         :token-hash (hash-token plaintext)
                                         :token-prefix (subseq plaintext 0 12)))))
    (values plaintext row)))

(defun authenticate-api-token (plaintext)
  "The users DAO owning PLAINTEXT when it is a well-formed, unrevoked token of
an existing user, recording the use in last_used_at; NIL otherwise."
  (when (token-format-p plaintext)
    (let ((row (find-dao 'api-token :token-hash (hash-token plaintext))))
      (when (and row (null (null->nil (api-token-revoked-at row))))
        (let ((user (get-user-by-id (api-token-user-id row))))
          (when user
            (setf (api-token-last-used-at row) (now))
            (save-dao row)
            user))))))

(defun revoke-api-token (user-id token-id)
  "Revoke USER-ID's unrevoked token TOKEN-ID.  T when it was revoked now, NIL
when no such live token of that user exists."
  (let ((row (and (integerp token-id)
                  (find-dao 'api-token :id token-id :user-id user-id))))
    (when (and row (null (null->nil (api-token-revoked-at row))))
      (setf (api-token-revoked-at row) (now))
      (save-dao row)
      t)))
```

`recurya.asd` の production `:depends-on` の Database layer 群 (`"recurya/db/novel"` の後) に `"recurya/db/api-tokens"` を追加。

- [ ] **Step 8: テストを通す**

`load-system recurya`、`run-tests {"system":"recurya/tests","tests":[...6 tests in recurya/tests/db/api-tokens...]}` → 6 PASS。失敗時のよくある原因: `revoked_at`/`last_used_at` の NIL 書き込み (cl-dbi の `"false"` 化)。その場合 `make-instance` から nil の initform を外さず、`(setf slot :null)` ではなく Mito の `(or :timestamptz :null)` 宣言が効いているかを `repl-eval` でテスト DB 上 (`with-test-db` 内) に確認する。

- [ ] **Step 9: Commit**

```bash
git add models/api-token.lisp db/api-tokens.lisp db/migrations db/schema.sql \
  tests/db/api-tokens.lisp tests/support/db.lisp tests/all.lisp recurya.asd
git commit -m "feat(db): api_token table and personal access token storage"
```

---

### Task 2: API トークンの cl-spec 契約

**Files:**
- Create: `specs/db/api-tokens.lisp`
- Modify: `specs/all.lisp`, `tests/specs/contracts.lisp`

**Interfaces:**
- Consumes: Task 1 の `recurya/db/api-tokens` 全 export。
- Produces: Property `recurya/specs/db/api-tokens::api-token-lifecycle`、Function Spec `recurya/db/api-tokens:normalize-token-name`。

- [ ] **Step 1: 契約ファイルを書く**

`fs-write-file` で `specs/db/api-tokens.lisp`:

```lisp
;;;; specs/db/api-tokens.lisp --- cl-spec contracts for personal API tokens.
;;;;
;;;; A token authenticates exactly its owner while unrevoked; revocation is
;;;; owner-only; nothing but the SHA-256 of a token is stored.  Each trial
;;;; runs inside WITH-TEST-DB (recurya_test only).  Design doc:
;;;; docs/superpowers/specs/2026-10-13-learner-cli-design.md

(defpackage #:recurya/specs/db/api-tokens
  (:use #:cl)
  (:import-from #:cl-spec/main
                #:defspec
                #:defspec-function
                #:defproperty
                #:defgenerator)
  (:import-from #:cl-spec/src/backends/check-it)
  (:import-from #:recurya/specs/db/domain
                #:random-element)
  (:import-from #:recurya/tests/support/db
                #:with-test-db
                #:create-test-user)
  (:import-from #:recurya/db/users
                #:users-id)
  (:import-from #:recurya/models/api-token
                #:api-token-id
                #:api-token-token-hash)
  (:import-from #:recurya/db/api-tokens
                #:issue-api-token
                #:authenticate-api-token
                #:revoke-api-token
                #:list-api-tokens
                #:hash-token
                #:normalize-token-name))
(in-package #:recurya/specs/db/api-tokens)

(defgenerator token-ops ()
  "0-10 operations: (:issue U), (:revoke K) by the owner, (:cross-revoke K) by
the other user, (:forge).  U picks one of two users; K indexes the tokens
issued so far (modulo their count).  At most 10 issues, so the per-user limit
is never reached."
  (loop repeat (random 11)
        collect (random-element
                 (vector (list :issue (random 2))
                         (list :revoke (random 10))
                         (list :cross-revoke (random 10))
                         (list :forge)))))

(defspec token-ops list (:generator token-ops))

(defun same-id-p (a b)
  "True when ids A and B print the same, ignoring case."
  (string-equal (princ-to-string a) (princ-to-string b)))

(defproperty api-token-lifecycle ((ops token-ops))
  "After any sequence of issues and revocations: every unrevoked token
authenticates to its owner, every revoked or forged one to nobody, a user
cannot revoke another's token, rows hold only the hash of the plaintext, and
each user lists exactly their unrevoked tokens."
  (:about issue-api-token authenticate-api-token revoke-api-token list-api-tokens)
  (:kind :invariant)
  (:trials (:smoke 10 :normal 50))
  (with-test-db
    (let ((users (vector (users-id (create-test-user :email-prefix "spec-tok"))
                         (users-id (create-test-user :email-prefix "spec-tok"))))
          (issued '())                  ; newest first: (plain owner row revoked-p)
          (forged '())
          (cross-ok t))
      (dolist (op ops)
        (ecase (first op)
          (:issue
           (let ((owner (second op)))
             (multiple-value-bind (plain row)
                 (issue-api-token (aref users owner) "spec")
               (push (list plain owner row nil) issued))))
          (:revoke
           (when issued
             (let ((entry (nth (mod (second op) (length issued)) issued)))
               (revoke-api-token (aref users (second entry)) (api-token-id (third entry)))
               (setf (fourth entry) t))))
          (:cross-revoke
           (when issued
             (let ((entry (nth (mod (second op) (length issued)) issued)))
               (when (revoke-api-token (aref users (- 1 (second entry)))
                                       (api-token-id (third entry)))
                 (setf cross-ok nil)))))
          (:forge
           (push (concatenate 'string "rcy_"
                              (format nil "~(~64,'0x~)" (random (expt 2 256))))
                 forged))))
      (and cross-ok
           (loop for (plain owner row revoked) in issued
                 always (and (string= (api-token-token-hash row) (hash-token plain))
                             (string/= (api-token-token-hash row) plain)
                             (let ((who (authenticate-api-token plain)))
                               (if revoked
                                   (null who)
                                   (and who (same-id-p (users-id who)
                                                       (aref users owner)))))))
           (loop for plain in forged
                 always (null (authenticate-api-token plain)))
           (loop for u below 2
                 always (let ((listed (mapcar #'api-token-id
                                              (list-api-tokens (aref users u))))
                              (live (loop for (nil owner row revoked) in issued
                                          when (and (= owner u) (not revoked))
                                            collect (api-token-id row))))
                          (and (subsetp listed live) (subsetp live listed)
                               (= (length listed) (length live)))))))))

(defgenerator token-name-input ()
  "Names a user might type: empty, blank, plain, padded, over-long, non-ASCII."
  (random-element (vector "" "   " "laptop" "  ci box  "
                          (make-string 80 :initial-element #\a)
                          "ラップトップ" (format nil "~Ctab~%" #\Tab))))

(defspec token-name-input string (:generator token-name-input))

(defspec-function normalize-token-name
  "Surrounding whitespace is trimmed, a blank name becomes \"cli\", and the
result is at most 64 characters."
  (:args (name token-name-input))
  (:returns string)
  (:post (let ((trimmed (string-trim '(#\Space #\Tab #\Newline #\Return) name)))
           (if (zerop (length trimmed))
               (string= result "cli")
               (string= result (subseq trimmed 0 (min 64 (length trimmed))))))))
```

- [ ] **Step 2: ハーネスに登録**

- `specs/all.lisp` の defpackage に `(:import-from #:recurya/specs/db/api-tokens)` を `recurya/specs/db/novel` の後へ追加 (`lisp-patch-form`, form_type `defpackage`, form_name `recurya/specs/all`)。
- `tests/specs/contracts.lisp`:
  - `*expected-properties*` に `("RECURYA/SPECS/DB/API-TOKENS" . "API-TOKEN-LIFECYCLE")`
  - `*expected-function-specs*` に `("RECURYA/DB/API-TOKENS" . "NORMALIZE-TOKEN-NAME")`

- [ ] **Step 3: 契約を検証**

`load-system cl-spec/check-it` → `load-system recurya` → `load-system recurya/specs/all` → 
`spec-check {"property":"recurya/specs/db/api-tokens::api-token-lifecycle","profile":"normal","timeout_seconds":180}` と
`spec-check {"function":"recurya/db/api-tokens:normalize-token-name","trials":100}`。
期待: どちらも passed、`effective_trials` > 0。seed・digest・`verification_gaps` を控える (最終報告用)。

- [ ] **Step 4: ハーネス経由でも通す**

`run-tests {"system":"recurya/tests","tests":["recurya/tests/specs/contracts::expected-contracts-registered","recurya/tests/specs/contracts::project-properties-pass","recurya/tests/specs/contracts::project-function-specs-pass"]}` → PASS。

- [ ] **Step 5: Commit**

```bash
git add specs/db/api-tokens.lisp specs/all.lisp tests/specs/contracts.lisp
git commit -m "test(specs): cl-spec contracts for API token lifecycle and naming"
```

---

### Task 3: Bearer 認証ミドルウェアと除外設定

**Files:**
- Create: `web/http.lisp`, `web/api-auth.lisp`, `tests/web/api-auth.lisp`
- Modify: `db/users.lisp` (`user-dao->plist` を移設・export)、`web/routes.lisp` (定義削除・import 追加)、`web/server.lisp`、`web/auth.lisp`、`recurya.asd`、`tests/all.lisp`

**Interfaces:**
- Consumes: `authenticate-api-token` (Task 1)。
- Produces:
  - `recurya/web/http`: `(read-request-body)` → 文字列、`(json-response data &key (status 200))` → Clack レスポンス。
  - `recurya/db/users:user-dao->plist` (セッションと同じ plist: `:id :email :name :handle :role :provider :language :timezone`)。
  - `recurya/web/api-auth`: `*api-prefix*` = `"/api/"`、`(api-path-p path)`、`(api-error-response status code message)`、`(api-token-auth app)` (成功時 env に `:recurya.api-user` plist を追加)。

- [ ] **Step 1: `web/http.lisp` を作り、routes から移設**

`fs-write-file` で `web/http.lisp`:

```lisp
;;;; web/http.lisp --- Request/response helpers shared by HTML and JSON routes.

(defpackage #:recurya/web/http
  (:use #:cl)
  (:import-from #:recurya/utils/common
                #:json->string)
  (:export #:read-request-body
           #:json-response))

(in-package #:recurya/web/http)

(defun json-response (data &key (status 200))
  "Return a Clack ring response with JSON content."
  (list status
        '(:content-type "application/json; charset=utf-8")
        (list (json->string data))))

(defun read-request-body ()
  "Read the raw POST body as a UTF-8 string, or empty string if unavailable."
  (let* ((env (lack/request:request-env ningle/context:*request*))
         (stream (getf env :raw-body))
         (content-length (or (getf env :content-length) 0)))
    (cond
      ((and stream (plusp content-length))
       (handler-case (file-position stream 0) (error () nil))
       (let ((buf (make-array content-length :element-type '(unsigned-byte 8))))
         (read-sequence buf stream)
         (babel:octets-to-string buf :encoding :utf-8)))
      (t ""))))
```

`web/routes.lisp`: `json-response` と `%read-request-body` の defun を削除 (`lisp-edit-form` で該当 form を削除できない場合は `lisp-patch-form` で form 全体を空に置換)、defpackage に `(:import-from #:recurya/web/http #:json-response #:read-request-body)` を追加し、`%read-request-body` の呼び出し (learn-sync-handler 内) を `read-request-body` に置換。`clgrep-search` で `%read-request-body` が残っていないこと、および tests が `recurya/web/routes::json-response` 等を参照していないことを確認 (参照があればテスト側の import を `recurya/web/http` へ)。

- [ ] **Step 2: `user-dao->plist` を db/users へ移設**

`db/users.lisp` の末尾に `lisp-edit-form insert_after list-users`:

```lisp
(defun user-dao->plist (user)
  "Convert a USER mito instance to the session plist used by handlers:
(:id :email :name :handle :role :provider :language :timezone)."
  (list :id (users-id user)
        :email (users-email user)
        :name (users-display-name user)
        :handle (users-handle user)
        :role (intern (string-upcase (users-role user)) :keyword)
        :provider (users-provider user)
        :language (users-language user)
        :timezone (users-timezone user)))
```

export に `#:user-dao->plist` を追加。`web/routes.lisp` の `user-dao->plist` defun を削除し、defpackage の `recurya/db/users` import (無ければ新設) に `#:user-dao->plist` を追加。`load-system recurya` が警告なしで通ることを確認。

- [ ] **Step 3: 失敗するテストを書く**

`fs-write-file` で `tests/web/api-auth.lisp`:

```lisp
;;;; tests/web/api-auth.lisp --- Bearer-token middleware and /api exemptions.

(defpackage #:recurya/tests/web/api-auth
  (:use #:cl #:rove)
  (:import-from #:recurya/tests/support/db
                #:with-test-db
                #:create-test-user)
  (:import-from #:recurya/db/users
                #:users-id
                #:users-handle)
  (:import-from #:recurya/models/api-token
                #:api-token-id)
  (:import-from #:recurya/db/api-tokens
                #:issue-api-token
                #:revoke-api-token)
  (:import-from #:recurya/web/api-auth
                #:api-token-auth
                #:api-path-p)
  (:import-from #:recurya/web/server
                #:csrf-with-skip)
  (:import-from #:recurya/web/auth
                #:require-real-handle))

(in-package #:recurya/tests/web/api-auth)

(defun make-env (path &key authorization session-user (method :get))
  (let ((headers (make-hash-table :test 'equal))
        (session (make-hash-table)))
    (when authorization (setf (gethash "authorization" headers) authorization))
    (when session-user (setf (gethash :user session) session-user))
    (list :request-method method :path-info path :headers headers
          :lack.session session)))

(defun capturing-app ()
  "An app that returns 200 and records the env it was called with."
  (let ((seen nil))
    (values (lambda (env) (setf seen env) (list 200 '() (list "inner")))
            (lambda () seen))))

(defun body-of (response) (first (third response)))

(deftest api-path-p-matches-prefix-only
  (ok (api-path-p "/api/v1/me"))
  (ng (api-path-p "/apiary"))
  (ng (api-path-p "/account")))

(deftest non-api-paths-pass-through-untouched
  (multiple-value-bind (app seen) (capturing-app)
    (let ((res (funcall (api-token-auth app) (make-env "/notebooks"))))
      (ok (= 200 (first res)))
      (ng (getf (funcall seen) :recurya.api-user)))))

(deftest api-without-token-is-401-json
  (multiple-value-bind (app seen) (capturing-app)
    (let ((res (funcall (api-token-auth app) (make-env "/api/v1/me"))))
      (ok (= 401 (first res)))
      (ok (search "unauthorized" (body-of res)))
      (ng (funcall seen) "inner app not called"))))

(deftest api-ignores-cookie-session
  (with-test-db
    (let ((user (create-test-user :email-prefix "auth")))
      (multiple-value-bind (app seen) (capturing-app)
        (let ((res (funcall (api-token-auth app)
                            (make-env "/api/v1/me"
                                      :session-user (list :id (users-id user)
                                                          :handle (users-handle user))))))
          (ok (= 401 (first res)) "a session cookie alone does not authenticate /api")
          (ng (funcall seen)))))))

(deftest api-with-valid-token-injects-user
  (with-test-db
    (let* ((user (create-test-user :email-prefix "auth"))
           (plain (issue-api-token (users-id user) "t")))
      (multiple-value-bind (app seen) (capturing-app)
        (let ((res (funcall (api-token-auth app)
                            (make-env "/api/v1/me"
                                      :authorization (format nil "Bearer ~A" plain)))))
          (ok (= 200 (first res)))
          (ok (string-equal (princ-to-string (users-id user))
                            (princ-to-string (getf (getf (funcall seen) :recurya.api-user) :id)))))))))

(deftest api-with-revoked-token-is-401
  (with-test-db
    (let ((user (create-test-user :email-prefix "auth")))
      (multiple-value-bind (plain row) (issue-api-token (users-id user) "t")
        (revoke-api-token (users-id user) (api-token-id row))
        (multiple-value-bind (app seen) (capturing-app)
          (let ((res (funcall (api-token-auth app)
                              (make-env "/api/v1/me"
                                        :authorization (format nil "Bearer ~A" plain)))))
            (ok (= 401 (first res)))
            (ng (funcall seen))))))))

(deftest csrf-skips-api-posts
  (multiple-value-bind (app seen) (capturing-app)
    (let ((res (funcall (csrf-with-skip app)
                        (make-env "/api/v1/notebooks/a/b/cells/0/run" :method :post))))
      (ok (= 200 (first res)) "no CSRF token needed under /api/")
      (ok (funcall seen)))))

(deftest onboarding-redirect-skips-api
  (multiple-value-bind (app seen) (capturing-app)
    (let ((res (funcall (require-real-handle app)
                        (make-env "/api/v1/me"
                                  :session-user (list :id "x" :handle "u-placeholder")))))
      (ok (= 200 (first res)))
      (ok (funcall seen)))))
```

`csrf-with-skip` は未 export なら `recurya/web/server` の export に追加する。asd の Web tests に `"recurya/tests/web/api-auth"`、`tests/all.lisp` に `:recurya/tests/web/api-auth`。

- [ ] **Step 4: 失敗を確認**

`run-tests {"system":"recurya/tests","test":"recurya/tests/web/api-auth::api-path-p-matches-prefix-only"}` → package `recurya/web/api-auth` が無く失敗。

- [ ] **Step 5: ミドルウェアを実装**

`fs-write-file` で `web/api-auth.lisp`:

```lisp
;;;; web/api-auth.lisp --- Bearer-token authentication for the JSON API.
;;;;
;;;; Under /api/ the only credential is "Authorization: Bearer <token>"; the
;;;; session cookie is never consulted, which is what makes it safe to exempt
;;;; /api/ from the CSRF middleware.

(defpackage #:recurya/web/api-auth
  (:use #:cl)
  (:import-from #:alexandria
                #:starts-with-subseq)
  (:import-from #:recurya/db/api-tokens
                #:authenticate-api-token)
  (:import-from #:recurya/db/users
                #:user-dao->plist)
  (:import-from #:recurya/web/http
                #:json-response)
  (:export #:*api-prefix*
           #:api-path-p
           #:api-error-response
           #:api-token-auth))

(in-package #:recurya/web/api-auth)

(defparameter *api-prefix* "/api/"
  "Path prefix of the token-authenticated JSON API.")

(defun api-path-p (path)
  "True when PATH is under *API-PREFIX*."
  (and (stringp path) (starts-with-subseq *api-prefix* path)))

(defun api-error-response (status code message)
  "A JSON error response {\"error\": {\"code\": CODE, \"message\": MESSAGE}}."
  (let ((err (make-hash-table :test 'equal))
        (body (make-hash-table :test 'equal)))
    (setf (gethash "code" err) code
          (gethash "message" err) message
          (gethash "error" body) err)
    (json-response body :status status)))

(defun bearer-token (env)
  "The token of ENV's \"Authorization: Bearer <token>\" header, or NIL."
  (let* ((headers (getf env :headers))
         (value (and (hash-table-p headers) (gethash "authorization" headers))))
    (when (and (stringp value)
               (> (length value) 7)
               (string-equal "Bearer " value :end2 7))
      (string-trim " " (subseq value 7)))))

(defun api-token-auth (app)
  "Lack middleware: authenticate /api/ requests by bearer token.
Outside *API-PREFIX* the request passes through untouched.  Under it, a valid
token adds the owner's session-shaped plist to ENV as :RECURYA.API-USER and
calls APP; anything else is a 401 JSON error."
  (lambda (env)
    (if (not (api-path-p (getf env :path-info)))
        (funcall app env)
        (let* ((token (bearer-token env))
               (user (and token
                          (handler-case (authenticate-api-token token)
                            (error (e)
                              (log:warn "API token check failed: ~A" e)
                              nil)))))
          (if user
              (funcall app (list* :recurya.api-user (user-dao->plist user) env))
              (api-error-response 401 "unauthorized"
                                  "A valid API token is required (Authorization: Bearer <token>)."))))))
```

`recurya.asd` の Web layer 群 (`"recurya/web/auth"` の後) に `"recurya/web/http"` と `"recurya/web/api-auth"` を追加。

- [ ] **Step 6: server / auth に組み込む**

`web/server.lisp`:
- defpackage に `(:import-from #:recurya/web/api-auth #:api-token-auth #:api-path-p)`、export に `#:csrf-with-skip`。
- `csrf-with-skip` の分岐を `lisp-patch-form`:
  old `(if (member (getf env :path-info) *csrf-skip-paths* :test #'string=)`
  new
  ```lisp
  (if (or (member (getf env :path-info) *csrf-skip-paths* :test #'string=)
          ;; /api/ authenticates by bearer token only (see web/api-auth).
          (api-path-p (getf env :path-info)))
  ```
- `build-app` の builder で `#'require-dashboard-auth` の直後に `#'api-token-auth` を挿入し、コメント表に「5. #'api-token-auth — /api/* を Bearer トークンで認証 (Cookie 不使用)。CSRF より前」を追記して以降の番号をずらす。

`web/auth.lisp`: `*handle-onboarding-skip-prefixes*` に `"/api/"` を追加 (`lisp-patch-form`: `'("/auth/" "/static/"` → `'("/api/" "/auth/" "/static/"`)、docstring に「the token-authenticated JSON API」を追記。

- [ ] **Step 7: テストを通す**

`run-tests {"system":"recurya/tests","tests":[recurya/tests/web/api-auth の 8 テスト]}` → PASS。続けて既存の `recurya/tests/web/csrf` と `recurya/tests/web/dashboard-auth` と `recurya/tests/web/routes` を `run-tests` で → PASS (移設の回帰なし)。

- [ ] **Step 8: Commit**

```bash
git add web/http.lisp web/api-auth.lisp web/server.lisp web/auth.lisp web/routes.lisp \
  db/users.lisp tests/web/api-auth.lisp tests/all.lisp recurya.asd
git commit -m "feat(web): bearer-token auth middleware for /api with CSRF/onboarding exemptions"
```

---

### Task 4: セル実行・保存・解答解放の共有関数抽出 (Web 振る舞い不変)

**Files:**
- Create: `game/notebook-gating.lisp`, `web/notebook-service.lisp`, `tests/game/notebook-gating.lisp`
- Modify: `web/ui/notebook.lisp`, `web/routes.lisp`, `recurya.asd`, `tests/all.lisp`

**Interfaces:**
- Produces (`recurya/game/notebook-gating`):
  - `(cell-id-string id)` → NIL は `""`、シンボルは小文字名、文字列はそのまま
  - `(solution-unlocked-p cells index passed-cell-ids)` → INDEX の solution セルが表示可か (非 gated、または直前の exercise が合格済み)
  - `(gated-solution-indices cells exercise-index)` → その exercise に属する gated solution の index リスト
- Produces (`recurya/web/notebook-service`):
  - `(notebook-row->notebook-struct nb-row)` (routes から移設)
  - `(parse-cell-index raw)` → 整数または NIL
  - `(persist-cell-run uid nb-uuid cell result code)` (旧 `%maybe-persist-notebook-cell-run`)
  - `(run-notebook-cell nb-row uid index-raw codes)` → `(values result cells revealed-indices index)`; 拒否時は `cell-run-refused` (reader `cell-run-refused-reason`: `:invalid-index` / `:index-out-of-range` / `:cannot-run-cell`)。アクセス制御は呼び出し側。

- [ ] **Step 1: ゲーティングの失敗テストを書く**

`fs-write-file` で `tests/game/notebook-gating.lisp`:

```lisp
;;;; tests/game/notebook-gating.lisp --- Pure solution-unlock rules.

(defpackage #:recurya/tests/game/notebook-gating
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebook
                #:make-cell)
  (:import-from #:recurya/game/notebook-gating
                #:cell-id-string
                #:solution-unlocked-p
                #:gated-solution-indices))

(in-package #:recurya/tests/game/notebook-gating)

(defun cells (&rest specs)
  "Build cells from (KIND ID &optional GATED) specs."
  (loop for (kind id gated) in specs
        collect (make-cell :id id :kind kind :body "" :gated-p (and gated t))))

(defparameter *nb*
  (cells '(:prose "p") '(:code-exercise "e1") '(:code-solution "s1" t)
         '(:code-solution "s1open") '(:code-exercise "e2") '(:code-solution "s2" t)))

(deftest cell-id-string-normalises
  (ok (string= "" (cell-id-string nil)))
  (ok (string= "abc" (cell-id-string :abc)))
  (ok (string= "X-1" (cell-id-string "X-1"))))

(deftest gated-solution-needs-preceding-exercise-pass
  (ng (solution-unlocked-p *nb* 2 '()))
  (ok (solution-unlocked-p *nb* 2 '("e1")))
  (ng (solution-unlocked-p *nb* 2 '("e2")) "another exercise's pass does not unlock it")
  (ok (solution-unlocked-p *nb* 3 '()) "an ungated solution is always visible")
  (ng (solution-unlocked-p *nb* 5 '("e1")))
  (ok (solution-unlocked-p *nb* 5 '("e2"))))

(deftest gated-solution-without-exercise-stays-locked
  (ng (solution-unlocked-p (cells '(:prose "p") '(:code-solution "s" t)) 1 '("p"))))

(deftest gated-solution-indices-stop-at-next-exercise
  (ok (equal '(2) (gated-solution-indices *nb* 1)))
  (ok (equal '(5) (gated-solution-indices *nb* 4)))
  (ok (null (gated-solution-indices (cells '(:code-exercise "e")) 0))))
```

asd の Game tests に `"recurya/tests/game/notebook-gating"`、`tests/all.lisp` に `:recurya/tests/game/notebook-gating`。

- [ ] **Step 2: 失敗を確認** — `run-tests` 単体指定で package 不在の red。

- [ ] **Step 3: ゲーティングを実装**

`fs-write-file` で `game/notebook-gating.lisp`:

```lisp
;;;; game/notebook-gating.lisp --- Which solution cells a reader may see.
;;;;
;;;; Pure rules shared by the HTML renderer and the JSON API: a gated
;;;; :code-solution is visible only once the nearest :code-exercise before it
;;;; is passed, and passing an exercise unlocks the gated solutions that
;;;; follow it up to the next exercise.

(defpackage #:recurya/game/notebook-gating
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:cell-id
                #:cell-kind
                #:cell-gated-p)
  (:export #:cell-id-string
           #:solution-unlocked-p
           #:gated-solution-indices))

(in-package #:recurya/game/notebook-gating)

(defun cell-id-string (id)
  "Stringify a cell or notebook id, accepting both keyword (legacy SICP)
and string (UUID) representations. NIL becomes \"\"."
  (cond ((null id) "")
        ((symbolp id) (string-downcase (symbol-name id)))
        (t (string id))))

(defun solution-unlocked-p (cells index passed-cell-ids)
  "True when the cell at INDEX of CELLS may be shown in full: it is not a
gated solution, or the nearest :code-exercise before it has its id (as by
CELL-ID-STRING) in PASSED-CELL-IDS.  A gated solution with no exercise before
it stays locked."
  (let ((cell (nth index cells)))
    (or (not (cell-gated-p cell))
        (loop for i from (1- index) downto 0
              for c = (nth i cells)
              when (eq (cell-kind c) :code-exercise)
                do (return (and (member (cell-id-string (cell-id c)) passed-cell-ids
                                        :test #'string=)
                                t))
              finally (return nil)))))

(defun gated-solution-indices (cells exercise-index)
  "Indices of the gated :code-solution cells that belong to the exercise at
EXERCISE-INDEX: those after it and before the next :code-exercise."
  (loop for i from (1+ exercise-index) below (length cells)
        for c = (nth i cells)
        until (eq (cell-kind c) :code-exercise)
        when (and (eq (cell-kind c) :code-solution) (cell-gated-p c))
          collect i))
```

asd の Notebook 群 (`"recurya/game/notebook-jsonb"` の後) に `"recurya/game/notebook-gating"`。`run-tests` で 4 テスト PASS。

- [ ] **Step 4: UI をゲーティング関数に置換**

`web/ui/notebook.lisp`:
- defpackage に `(:import-from #:recurya/game/notebook-gating #:solution-unlocked-p #:gated-solution-indices)`。
- `render-solution-cell` の
  old `(let ((unlocked (or (not (cell-gated-p cell))\n                          (preceding-exercise-passed-p index))))`
  new `(let ((unlocked (solution-unlocked-p *cells* index *passed-cells*)))`
  (`lisp-read-file name_pattern="^render-solution-cell$"` で正確な空白を確認してから `lisp-patch-form`)。
- `render-solution-oob-reveals` を `lisp-edit-form replace`:
  ```lisp
  (defun render-solution-oob-reveals (cells exercise-index)
    "Return HTML (string) of out-of-band <div id=\"cell-<M>-solution\"
  hx-swap-oob=\"true\"> reveals for every gated :code-solution cell that belongs
  to the exercise at EXERCISE-INDEX (appears after it, before the next
  exercise). Empty string when there are none. Appended to a Run response after
  a :pass so the solution unlocks instantly."
    (with-html-string
      (dolist (i (gated-solution-indices cells exercise-index))
        (%render-solution-unlocked (nth i cells) i :oob t))))
  ```
- `clgrep-search "preceding-exercise-passed-p"` (プロジェクト全体)。他に使用箇所が無ければ `preceding-exercise-passed-p` の defun を削除。テストが参照していればそのテストは残し関数も残す。

- [ ] **Step 5: service モジュールを作る**

`fs-write-file` で `web/notebook-service.lisp`:

```lisp
;;;; web/notebook-service.lisp --- Run a notebook cell and persist the outcome.
;;;;
;;;; Shared by the HTML cell-run route and the JSON API so both validate,
;;;; execute, persist and unlock solutions identically.  Access control and
;;;; response rendering stay with the callers.

(defpackage #:recurya/web/notebook-service
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook
                #:notebook-cells
                #:cell-id
                #:cell-kind
                #:run-cell
                #:notebook-cell-result-status)
  (:import-from #:recurya/game/notebook-jsonb
                #:jsonb-hash->cell)
  (:import-from #:recurya/game/notebook-gating
                #:gated-solution-indices)
  (:import-from #:recurya/db/notebooks
                #:notebook-cells-parsed
                #:notebook-title
                #:notebook-summary)
  (:import-from #:recurya/db/learn
                #:upsert-cell-code
                #:record-submission
                #:mark-cell-passed)
  (:export #:notebook-row->notebook-struct
           #:parse-cell-index
           #:persist-cell-run
           #:run-notebook-cell
           #:cell-run-refused
           #:cell-run-refused-reason))

(in-package #:recurya/web/notebook-service)

(defun notebook-row->notebook-struct (nb-row)
  "Convert a notebook DAO into a recurya/game/notebook:notebook struct
that the existing notebook UI and run-cell logic can consume.
Cells come from the JSONB cache (parsed via jsonb-hash->cell)."
  (let* ((cells-data (notebook-cells-parsed nb-row))
         (cells-list (mapcar #'jsonb-hash->cell
                             (coerce (or cells-data #()) 'list))))
    (make-notebook
     :id (princ-to-string (recurya/db/notebooks:notebook-id nb-row))
     :chapter ""
     :title (or (notebook-title nb-row) "")
     :summary (or (notebook-summary nb-row) "")
     :cells cells-list)))

(define-condition cell-run-refused (error)
  ((reason :initarg :reason :reader cell-run-refused-reason))
  (:report (lambda (c stream)
             (format stream "Cell run refused: ~(~A~)" (cell-run-refused-reason c)))))

(defun parse-cell-index (raw)
  "RAW (a path string or an integer) as a cell index, or NIL."
  (typecase raw
    (string (parse-integer raw :junk-allowed t))
    (integer raw)
    (t nil)))

(defun persist-cell-run (uid nb-uuid cell result code)
  "Persist saved code, submission, and progress for a notebook cell run.
Anonymous users (UID NIL) are skipped silently; DB errors are logged but
do not poison the response."
  (when uid
    (handler-case
        (let* ((cell-id-str (string (or (cell-id cell) "")))
               (status      (notebook-cell-result-status result))
               (kind        (cell-kind cell))
               (status-str  (string-downcase (symbol-name status))))
          (upsert-cell-code uid nb-uuid cell-id-str (or code ""))
          (when (eq kind :code-exercise)
            (record-submission uid nb-uuid cell-id-str (or code "") status-str)
            (when (eq status :pass)
              (mark-cell-passed uid nb-uuid cell-id-str))))
      (error (e) (log:warn "Failed to persist notebook cell run: ~A" e)))))

(defun run-notebook-cell (nb-row uid index-raw codes)
  "Run the cell at INDEX-RAW of NB-ROW with CODES, the submitted code of cells
0..N in order, and persist the outcome for UID (NIL: anonymous, nothing saved).
Returns (VALUES RESULT CELLS REVEALED-INDICES INDEX): REVEALED-INDICES are the
gated solutions a passing exercise unlocks.  Signals CELL-RUN-REFUSED with
reason :INVALID-INDEX, :INDEX-OUT-OF-RANGE or :CANNOT-RUN-CELL (prose and
solution cells).  The caller checks that the viewer may see NB-ROW."
  (let* ((notebook (notebook-row->notebook-struct nb-row))
         (cells (notebook-cells notebook))
         (index (parse-cell-index index-raw)))
    (cond
      ((null index) (error 'cell-run-refused :reason :invalid-index))
      ((or (< index 0) (>= index (length cells)))
       (error 'cell-run-refused :reason :index-out-of-range))
      ((member (cell-kind (nth index cells)) '(:prose :code-solution))
       (error 'cell-run-refused :reason :cannot-run-cell)))
    (let* ((cell (nth index cells))
           (result (run-cell notebook index codes))
           (revealed (when (and (eq (cell-kind cell) :code-exercise)
                                (eq (notebook-cell-result-status result) :pass))
                       (gated-solution-indices cells index))))
      (persist-cell-run uid (princ-to-string (recurya/db/notebooks:notebook-id nb-row))
                        cell result (nth index codes))
      (values result cells revealed index))))
```

asd の Web layer 群 (`"recurya/web/api-auth"` の後) に `"recurya/web/notebook-service"`。

- [ ] **Step 6: routes を service に置換**

`web/routes.lisp`:
- defpackage に `(:import-from #:recurya/web/notebook-service #:notebook-row->notebook-struct #:run-notebook-cell #:cell-run-refused #:cell-run-refused-reason)`。
- `notebook-row->notebook-struct` と `%maybe-persist-notebook-cell-run` の defun を削除 (tests が `recurya/web/routes::notebook-row->notebook-struct` を参照していれば `clgrep-search` で見つけて import 先を service に変更)。
- `%run-public-cell` を `lisp-edit-form replace`:

```lisp
(defun %run-public-cell (nb-row params)
  "Execute a cell on NB-ROW and render the HTMX result fragment.

Encapsulates the access check, codes[] collection and the shared
run-notebook-cell service (validation, execution, persistence).

Returns a Clack response list. Returns 404 when NB-ROW is NIL or the
viewer cannot view it; 400 on bad index/cell-kind."
  (let* ((user (get-current-user))
         (uid (and user (getf user :id))))
    (cond
      ((null nb-row) (html-response (tr :server.errors.notebook_not_found) :status 404))
      ((not (recurya/utils/access-control:can-view-notebook-p user nb-row))
       (html-response (tr :server.errors.notebook_not_found) :status 404))
      (t
       (let ((codes-list (loop for (k . v) in params
                               when (and (stringp k) (string= k "codes[]"))
                                 collect v)))
         (handler-case
             (multiple-value-bind (result cells revealed index)
                 (run-notebook-cell nb-row uid (get-path-param params :index) codes-list)
               (html-response
                (concatenate 'string
                             (recurya/web/ui/notebook:render-cell-result result)
                             (if revealed
                                 (recurya/web/ui/notebook:render-solution-oob-reveals
                                  cells index)
                                 ""))))
           (cell-run-refused (c)
             (html-response
              (tr (ecase (cell-run-refused-reason c)
                    (:invalid-index :server.errors.invalid_index)
                    (:index-out-of-range :server.errors.index_out_of_range)
                    (:cannot-run-cell :server.errors.cannot_run_cell)))
              :status 400))))))))
```

- [ ] **Step 7: 回帰なしを確認**

`load-system recurya` (警告ゼロ)。`run-tests {"system":"recurya/tests"}` で全体 → 既存 + 新規すべて PASS (この時点で 478 + Task1〜4 の追加分)。`./scripts/request-test.sh` (dev サーバ稼働時) → 既存チェックすべて PASS (セル実行断片・OOB 解放が不変)。

- [ ] **Step 8: Commit**

```bash
git add game/notebook-gating.lisp web/notebook-service.lisp web/ui/notebook.lisp \
  web/routes.lisp tests/game/notebook-gating.lisp tests/all.lisp recurya.asd
git commit -m "refactor(notebook): extract cell-run service and solution gating rules"
```

---

### Task 5: `/api/v1/*` ハンドラ

**Files:**
- Create: `web/routes-api.lisp`, `tests/web/api-routes.lisp`
- Modify: `web/app.lisp`, `recurya.asd`, `tests/all.lisp`

**Interfaces:**
- Consumes: `api-error-response` (Task 3), `json-response`/`read-request-body` (Task 3), service と gating (Task 4)。ハンドラは env の `:recurya.api-user` (Task 3 のミドルウェアが設定) からユーザーを読む。
- Produces: `setup-api-routes`, `api-me-handler`, `api-notebooks-handler`, `api-notebook-handler`, `api-cell-run-handler`, `api-not-found-handler`。JSON 形は spec §3 のとおり (下のテストが正)。

- [ ] **Step 1: 失敗するテストを書く**

`fs-write-file` で `tests/web/api-routes.lisp`:

```lisp
;;;; tests/web/api-routes.lisp --- JSON API handlers (/api/v1/*).

(defpackage #:recurya/tests/web/api-routes
  (:use #:cl #:rove)
  (:import-from #:recurya/tests/support/db
                #:with-test-db
                #:create-test-user)
  (:import-from #:recurya/db/users
                #:users-id
                #:users-handle
                #:users-display-name
                #:user-dao->plist)
  (:import-from #:recurya/db/notebooks
                #:create-notebook!
                #:notebook-id)
  (:import-from #:recurya/db/learn
                #:cell-submissions)
  (:import-from #:recurya/web/routes-api
                #:api-me-handler
                #:api-notebooks-handler
                #:api-notebook-handler
                #:api-cell-run-handler)
  (:import-from #:recurya/web/routes
                #:public-notebook-by-handle-handler))

(in-package #:recurya/tests/web/api-routes)

(defmacro with-api-request ((user &key body) &body forms)
  "Bind ningle/context:*request* as the token middleware leaves it: env carries
USER (a session plist) as :RECURYA.API-USER and BODY as the raw request body."
  `(let* ((octets (babel:string-to-octets (or ,body "") :encoding :utf-8))
          (env (list :request-method :post
                     :path-info "/api/test"
                     :headers (make-hash-table :test 'equal)
                     :raw-body (flexi-streams:make-in-memory-input-stream octets)
                     :content-length (length octets)
                     :recurya.api-user ,user))
          (ningle/context:*request* (lack/request:make-request env)))
     ,@forms))

(defun status-of (res) (first res))
(defun json-of (res) (com.inuoe.jzon:parse (first (third res))))
(defun jget (obj &rest keys)
  (reduce (lambda (o k) (if (integerp k) (aref o k) (gethash k o))) keys :initial-value obj))

(defparameter *gated-body*
  (format nil "===prose===~%hi~%~%===exercise: q===~%; fill~%~%===expect===~%3~%~%===solution-locked: ans===~%(SECRET-ANSWER)"))

(defun make-nb (author slug &key (body *gated-body*) (status "published") (visibility "public"))
  (create-notebook! :title (format nil "T ~A" slug) :slug slug :body-md body
                    :cells (mapcar #'recurya/game/notebook-jsonb:cell->jsonb-form
                                   (recurya/game/notebook-parser:parse-notebook-body body))
                    :author author :status status :visibility visibility
                    :published-at (local-time:now)))

(defun run-body (&rest codes)
  (com.inuoe.jzon:stringify
   (let ((h (make-hash-table :test 'equal)))
     (setf (gethash "codes" h) (coerce codes 'vector))
     h)))

(deftest me-returns-handle-and-name
  (with-test-db
    (let ((dao (create-test-user :email-prefix "api" :display-name "Ann")))
      (with-api-request ((user-dao->plist dao))
        (let ((res (api-me-handler nil)))
          (ok (= 200 (status-of res)))
          (ok (string= (users-handle dao) (jget (json-of res) "handle")))
          (ok (string= "Ann" (jget (json-of res) "display_name"))))))))

(deftest notebooks-lists-published-public-only
  (with-test-db
    (let ((author (create-test-user :email-prefix "api")))
      (make-nb author "pub")
      (make-nb author "draft" :status "draft")
      (make-nb author "unl" :visibility "unlisted")
      (with-api-request ((user-dao->plist author))
        (let* ((json (json-of (api-notebooks-handler '(("page" . "1")))))
               (slugs (map 'list (lambda (i) (gethash "slug" i)) (jget json "items"))))
          (ok (equal '("pub") slugs))
          (ok (= 1 (jget json "total")))
          (ok (string= (users-handle author) (jget json "items" 0 "handle"))))))))

(deftest notebook-detail-hides-gated-solution-until-passed
  (with-test-db
    (let* ((author (create-test-user :email-prefix "api"))
           (learner (create-test-user :email-prefix "api"))
           (handle (users-handle author)))
      (make-nb author "g")
      (with-api-request ((user-dao->plist learner))
        (let* ((res (api-notebook-handler `((:handle . ,handle) (:slug . "g"))))
               (cells (jget (json-of res) "cells")))
          (ok (= 200 (status-of res)))
          (ok (= 3 (length cells)))
          (ok (string= "prose" (jget cells 0 "kind")))
          (ok (search "hi" (jget cells 0 "body")) "prose body is its text")
          (ok (string= "code-exercise" (jget cells 1 "kind")))
          (ok (string= "3" (jget cells 1 "test_cases" 0 "expected")))
          (ok (eq 'null (jget cells 1 "saved_code")))
          (ok (eq nil (jget cells 1 "passed")))
          (ok (string= "code-solution" (jget cells 2 "kind")))
          (ok (eq t (jget cells 2 "gated")))
          (ok (eq nil (jget cells 2 "unlocked")))
          (ok (eq 'null (jget cells 2 "body")) "locked solution body is withheld"))))))

(deftest notebook-detail-404s
  (with-test-db
    (let ((author (create-test-user :email-prefix "api"))
          (other (create-test-user :email-prefix "api")))
      (make-nb author "priv" :visibility "private")
      (with-api-request ((user-dao->plist other))
        (let ((res (api-notebook-handler `((:handle . ,(users-handle author)) (:slug . "priv")))))
          (ok (= 404 (status-of res)))
          (ok (string= "not_found" (jget (json-of res) "error" "code"))))
        (ok (= 404 (status-of (api-notebook-handler '((:handle . "nobody-xyz") (:slug . "x"))))))))))

(deftest run-fail-then-pass-persists-and-unlocks
  (with-test-db
    (let* ((author (create-test-user :email-prefix "api"))
           (learner (create-test-user :email-prefix "api"))
           (handle (users-handle author))
           (nb (make-nb author "g"))
           (path `((:handle . ,handle) (:slug . "g") (:index . "1"))))
      (with-api-request ((user-dao->plist learner) :body (run-body "" "4"))
        (let* ((res (api-cell-run-handler path)) (json (json-of res)))
          (ok (= 200 (status-of res)))
          (ok (string= "fail" (jget json "status")))
          (ok (eq nil (jget json "tests" 0 "passed")))
          (ok (string= "4" (jget json "tests" 0 "actual")))
          (ok (zerop (length (jget json "revealed_solutions"))))))
      (with-api-request ((user-dao->plist learner) :body (run-body "" "3"))
        (let ((json (json-of (api-cell-run-handler path))))
          (ok (string= "pass" (jget json "status")))
          (ok (= 2 (jget json "revealed_solutions" 0 "index")))
          (ok (search "SECRET-ANSWER" (jget json "revealed_solutions" 0 "body")))
          (ok (integerp (jget json "metrics" "steps")))))
      (let ((exercise-id (recurya/game/notebook-gating:cell-id-string
                          (recurya/game/notebook:cell-id
                           (second (recurya/game/notebook:notebook-cells
                                    (recurya/web/notebook-service:notebook-row->notebook-struct nb)))))))
        (ok (= 2 (length (cell-submissions (users-id learner)
                                           (princ-to-string (notebook-id nb))
                                           exercise-id)))
            "both submissions are in the history"))
      (with-api-request ((user-dao->plist learner))
        (let ((cells (jget (json-of (api-notebook-handler path)) "cells")))
          (ok (eq t (jget cells 1 "passed")))
          (ok (string= "3" (jget cells 1 "saved_code")))
          (ok (eq t (jget cells 2 "unlocked")))
          (ok (search "SECRET-ANSWER" (jget cells 2 "body"))))))))

(deftest api-progress-shows-on-web-page
  (with-test-db
    (let* ((author (create-test-user :email-prefix "api"))
           (learner (create-test-user :email-prefix "api"))
           (handle (users-handle author)))
      (make-nb author "g")
      (with-api-request ((user-dao->plist learner) :body (run-body "" "3"))
        (api-cell-run-handler `((:handle . ,handle) (:slug . "g") (:index . "1"))))
      (let ((session (make-hash-table)))
        (setf (gethash :user session) (user-dao->plist learner))
        (let ((ningle/context:*session* session))
          (ok (search "SECRET-ANSWER"
                      (first (third (public-notebook-by-handle-handler
                                     (list (cons :captures (list handle "g"))))))))
              "the browser sees the solution unlocked by the CLI run"))))))

(deftest run-rejects-bad-requests
  (with-test-db
    (let* ((author (create-test-user :email-prefix "api"))
           (handle (users-handle author))
           (user (user-dao->plist author)))
      (make-nb author "g")
      (flet ((run (index body)
               (with-api-request (user :body body)
                 (api-cell-run-handler `((:handle . ,handle) (:slug . "g") (:index . ,index))))))
        (let ((res (run "1" "{not json")))
          (ok (= 400 (status-of res)))
          (ok (string= "bad_json" (jget (json-of res) "error" "code"))))
        (ok (= 422 (status-of (run "1" "{\"codes\": \"x\"}"))) "codes must be an array of strings")
        (ok (= 422 (status-of (run "1" (run-body "")))) "codes shorter than index+1")
        (ok (= 422 (status-of (run "0" (run-body "")))) "prose cell")
        (ok (= 422 (status-of (run "2" (run-body "" "" "")))) "solution cell")
        (ok (= 422 (status-of (run "9" (run-body "" "" "")))) "index out of range")
        (ok (= 404 (status-of (with-api-request (user :body (run-body "" "3"))
                                (api-cell-run-handler '((:handle . "nobody-xyz") (:slug . "g") (:index . "1")))))))))))
```

asd の Web tests に `"recurya/tests/web/api-routes"`、`tests/all.lisp` に `:recurya/tests/web/api-routes`。テストが `flexi-streams` を使うので、asd の `recurya/tests` `:depends-on` に `"flexi-streams"` が無ければ追加。

- [ ] **Step 2: 失敗を確認** — package `recurya/web/routes-api` 不在の red。

- [ ] **Step 3: ハンドラを実装**

`fs-write-file` で `web/routes-api.lisp`:

```lisp
;;;; web/routes-api.lisp --- JSON API for the learner CLI (/api/v1/*).
;;;;
;;;; Every route sits behind web/api-auth's bearer-token middleware, which puts
;;;; the caller's session-shaped plist in the request env as
;;;; :RECURYA.API-USER.  Cell runs go through web/notebook-service, so a run
;;;; from the CLI saves code, history and progress exactly like the browser.

(defpackage #:recurya/web/routes-api
  (:use #:cl)
  (:import-from #:recurya/web/http
                #:json-response
                #:read-request-body)
  (:import-from #:recurya/web/api-auth
                #:api-error-response)
  (:import-from #:recurya/db/users
                #:users-handle)
  (:import-from #:recurya/db/notebooks
                #:find-notebook-by-handle-and-slug
                #:list-notebooks
                #:count-notebooks
                #:notebook-slug
                #:notebook-title
                #:notebook-summary
                #:notebook-author)
  (:import-from #:recurya/db/learn
                #:user-cell-codes
                #:user-passed-cells)
  (:import-from #:recurya/utils/access-control
                #:can-view-notebook-p)
  (:import-from #:recurya/game/notebook
                #:notebook-cells
                #:cell-id
                #:cell-kind
                #:cell-body
                #:cell-description
                #:cell-test-cases
                #:cell-gated-p
                #:notebook-cell-result-status
                #:notebook-cell-result-value
                #:notebook-cell-result-print-output
                #:notebook-cell-result-error-message
                #:notebook-cell-result-error-cell-id
                #:notebook-cell-result-metrics
                #:notebook-cell-result-test-results)
  (:import-from #:recurya/game/puzzle
                #:test-case-input
                #:test-case-expected
                #:test-case-description)
  (:import-from #:recurya/game/notebook-gating
                #:cell-id-string
                #:solution-unlocked-p)
  (:import-from #:recurya/web/notebook-service
                #:notebook-row->notebook-struct
                #:parse-cell-index
                #:run-notebook-cell
                #:cell-run-refused)
  (:export #:setup-api-routes
           #:api-me-handler
           #:api-notebooks-handler
           #:api-notebook-handler
           #:api-cell-run-handler
           #:api-not-found-handler))

(in-package #:recurya/web/routes-api)

(defparameter *api-page-size* 20
  "Notebooks per page of GET /api/v1/notebooks.")

;;; JSON building.  jzon writes NIL as false, so null and empty arrays are
;;; spelled out.

(defun obj (&rest keys-and-values)
  "A JSON object (EQUAL hash table) from alternating string keys and values."
  (let ((h (make-hash-table :test 'equal)))
    (loop for (k v) on keys-and-values by #'cddr
          do (setf (gethash k h) v))
    h))

(defun nullable (value)
  "VALUE, or JSON null when VALUE is NIL."
  (if (null value) 'null value))

(defun json-array (list)
  "LIST as a JSON array (empty list: [])."
  (coerce list 'vector))

;;; Request helpers

(defun api-user ()
  "The caller's plist, put in the request env by the token middleware."
  (let ((request ningle/context:*request*))
    (and request (getf (lack/request:request-env request) :recurya.api-user))))

(defun param (params key)
  "PARAMS' value for KEY (a keyword for path params, a string for query params)."
  (cdr (assoc key params :test #'equal)))

(defun parse-page (raw)
  "RAW as a page number >= 1; 1 when missing or invalid."
  (let ((n (and (stringp raw) (parse-integer raw :junk-allowed t))))
    (if (and n (plusp n)) n 1)))

(defmacro with-api-errors (&body body)
  "Run BODY; any unhandled error becomes a 500 JSON response."
  `(handler-case (progn ,@body)
     (error (e)
       (log:error "API handler error: ~A" e)
       (api-error-response 500 "internal" "Internal server error"))))

(defun viewable-notebook (params user)
  "The notebook named by PARAMS' :handle and :slug when USER may view it."
  (let ((row (find-notebook-by-handle-and-slug (param params :handle)
                                               (param params :slug))))
    (and row (can-view-notebook-p user row) row)))

;;; Serialisers

(defun notebook-summary-json (nb)
  (let ((author (notebook-author nb)))
    (obj "handle" (nullable (and author (users-handle author)))
         "slug" (notebook-slug nb)
         "title" (notebook-title nb)
         "summary" (nullable (notebook-summary nb)))))

(defun test-case-json (tc)
  (obj "input" (test-case-input tc)
       "expected" (test-case-expected tc)
       "description" (test-case-description tc)))

(defun cell-json (cell index cells saved passed)
  "CELL at INDEX as the API shows it to a reader with SAVED codes (alist of
cell-id . code) and PASSED cell ids.  A locked gated solution has body null."
  (let* ((id (cell-id-string (cell-id cell)))
         (kind (cell-kind cell))
         (unlocked (solution-unlocked-p cells index passed)))
    (obj "index" index
         "cell_id" id
         "kind" (string-downcase (symbol-name kind))
         "body" (if unlocked (or (cell-body cell) "") 'null)
         "description" (or (cell-description cell) "")
         "test_cases" (json-array (mapcar #'test-case-json (cell-test-cases cell)))
         "gated" (cell-gated-p cell)
         "unlocked" unlocked
         "saved_code" (nullable (cdr (assoc id saved :test #'string=)))
         "passed" (and (member id passed :test #'string=) t))))

(defun test-result-json (tr)
  (obj "input" (getf tr :input)
       "description" (nullable (getf tr :description))
       "expected" (getf tr :expected)
       "actual" (nullable (getf tr :actual))
       "passed" (and (getf tr :passed) t)
       "error" (nullable (getf tr :error))))

(defun cell-index-of (id cells)
  "Index in CELLS of the cell whose id is ID, or NIL."
  (and id (position (cell-id-string id) cells
                    :key (lambda (c) (cell-id-string (cell-id c)))
                    :test #'string=)))

(defun run-result-json (result cells revealed)
  (let ((status (notebook-cell-result-status result))
        (metrics (notebook-cell-result-metrics result)))
    (obj "status" (if (eq status :limit-exceeded)
                      "error"
                      (string-downcase (symbol-name status)))
         "value" (nullable (notebook-cell-result-value result))
         "output" (or (notebook-cell-result-print-output result) "")
         "error" (nullable (notebook-cell-result-error-message result))
         "error_cell_index" (nullable (cell-index-of
                                       (notebook-cell-result-error-cell-id result) cells))
         "tests" (json-array (mapcar #'test-result-json
                                     (notebook-cell-result-test-results result)))
         "metrics" (obj "steps" (or (getf metrics :steps-used) 0)
                        "cons" (or (getf metrics :cons-allocated) 0)
                        "depth" (or (getf metrics :max-depth-reached) 0))
         "revealed_solutions"
         (json-array (mapcar (lambda (i)
                               (let ((c (nth i cells)))
                                 (obj "index" i
                                      "cell_id" (cell-id-string (cell-id c))
                                      "body" (or (cell-body c) ""))))
                             revealed)))))

;;; Handlers

(defun api-me-handler (params)
  "GET /api/v1/me - the caller's handle and display name."
  (declare (ignore params))
  (with-api-errors
    (let ((user (api-user)))
      (json-response (obj "handle" (getf user :handle)
                          "display_name" (nullable (getf user :name)))))))

(defun api-notebooks-handler (params)
  "GET /api/v1/notebooks?page=N - published, public notebooks, newest first."
  (with-api-errors
    (let* ((page (parse-page (param params "page")))
           (total (count-notebooks :status "published" :visibility "public"))
           (rows (list-notebooks :status "published" :visibility "public"
                                 :limit *api-page-size*
                                 :offset (* (1- page) *api-page-size*))))
      (json-response (obj "items" (json-array (mapcar #'notebook-summary-json rows))
                          "page" page
                          "per_page" *api-page-size*
                          "total" total)))))

(defun api-notebook-handler (params)
  "GET /api/v1/notebooks/:handle/:slug - a notebook with every cell and the
caller's saved code and progress.  404 when it does not exist or the caller
may not view it."
  (with-api-errors
    (let* ((user (api-user))
           (row (viewable-notebook params user)))
      (if (null row)
          (api-error-response 404 "not_found" "Notebook not found")
          (let* ((uid (getf user :id))
                 (nb-id (princ-to-string (recurya/db/notebooks:notebook-id row)))
                 (cells (notebook-cells (notebook-row->notebook-struct row)))
                 (saved (user-cell-codes uid nb-id))
                 (passed (user-passed-cells uid nb-id))
                 (author (notebook-author row)))
            (json-response
             (obj "handle" (nullable (and author (users-handle author)))
                  "slug" (notebook-slug row)
                  "title" (notebook-title row)
                  "summary" (nullable (notebook-summary row))
                  "cells" (json-array (loop for cell in cells
                                            for i from 0
                                            collect (cell-json cell i cells saved passed))))))))))

(defun request-codes ()
  "The request body's \"codes\" array as a list of strings, or :BAD-JSON when
the body is not JSON, or :INVALID when it is not {\"codes\": [string, ...]}."
  (let ((data (handler-case (com.inuoe.jzon:parse (read-request-body))
                (error () :bad-json))))
    (cond ((eq data :bad-json) :bad-json)
          ((not (hash-table-p data)) :invalid)
          (t (let ((codes (gethash "codes" data)))
               (if (and (vectorp codes) (not (stringp codes)) (every #'stringp codes))
                   (coerce codes 'list)
                   :invalid))))))

(defun api-cell-run-handler (params)
  "POST /api/v1/notebooks/:handle/:slug/cells/:index/run with
{\"codes\": [code of cell 0, ..., code of cell N]}: run cell N, save the run
for the caller, and return the result with any solutions it unlocked."
  (with-api-errors
    (let* ((user (api-user))
           (row (viewable-notebook params user)))
      (if (null row)
          (api-error-response 404 "not_found" "Notebook not found")
          (let ((codes (request-codes))
                (index (parse-cell-index (param params :index))))
            (cond
              ((eq codes :bad-json)
               (api-error-response 400 "bad_json" "Request body is not valid JSON"))
              ((eq codes :invalid)
               (api-error-response 422 "invalid_request"
                                   "Body must be {\"codes\": [string, ...]}"))
              ((or (null index) (< (length codes) (1+ index)))
               (api-error-response 422 "invalid_request"
                                   "codes must hold the code of every cell up to the one run"))
              (t
               (handler-case
                   (multiple-value-bind (result cells revealed)
                       (run-notebook-cell row (getf user :id) index codes)
                     (json-response (run-result-json result cells revealed)))
                 (cell-run-refused ()
                   (api-error-response 422 "invalid_request"
                                       "That cell cannot be run"))))))))))

(defun api-not-found-handler (params)
  "Any other /api/ path."
  (declare (ignore params))
  (api-error-response 404 "not_found" "No such API endpoint"))

(defun dynamic-handler (symbol)
  "A handler calling SYMBOL's current function, so redefinitions take effect."
  (lambda (params) (funcall (symbol-function symbol) params)))

(defun setup-api-routes (app)
  "Register the /api/v1 routes on APP."
  (setf (ningle/app:route app "/api/v1/me")
        (dynamic-handler 'api-me-handler))
  (setf (ningle/app:route app "/api/v1/notebooks")
        (dynamic-handler 'api-notebooks-handler))
  (setf (ningle/app:route app "/api/v1/notebooks/:handle/:slug")
        (dynamic-handler 'api-notebook-handler))
  (setf (ningle/app:route app "/api/v1/notebooks/:handle/:slug/cells/:index/run"
                          :method :post)
        (dynamic-handler 'api-cell-run-handler))
  (setf (ningle/app:route app "/api/*") (dynamic-handler 'api-not-found-handler))
  (setf (ningle/app:route app "/api/*" :method :post)
        (dynamic-handler 'api-not-found-handler))
  app)
```

`web/app.lisp`: import `(:import-from #:recurya/web/routes-api #:setup-api-routes)`、`make-recurya-app` で `(setup-novel-routes *app*)` の後に `(setup-api-routes *app*)`。asd の WardLisp UI 群の `"recurya/web/routes-novel"` の後に `"recurya/web/routes-api"`。

- [ ] **Step 4: テストを通す**

`run-tests` で `recurya/tests/web/api-routes` の 7 テスト → PASS。prose の `body` が文字列でない (Spinneret リスト等) と判明した場合は、`repl-eval` で `(recurya/game/notebook-parser:parse-notebook-body "===prose===\nhi")` の結果を確認し、`cell-json` の prose 分岐で Markdown 文字列を返すよう修正する (JSONB 経由のセルは文字列のはず)。

- [ ] **Step 5: 稼働サーバで HTTP 検証**

`load-system recurya` (ホットリロード)。トークンは Task 6 まで UI が無いので、`curl` で認証なしの振る舞いだけ確認:

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:13000/api/v1/me          # 401
curl -s http://localhost:13000/api/v1/me                                             # {"error":{"code":"unauthorized",...}}
curl -s -o /dev/null -w '%{http_code}\n' -X POST http://localhost:13000/api/v1/notebooks/a/b/cells/0/run  # 401 (CSRF 400 ではない)
```

- [ ] **Step 6: Commit**

```bash
git add web/routes-api.lisp web/app.lisp tests/web/api-routes.lisp tests/all.lisp recurya.asd
git commit -m "feat(api): /api/v1 notebook read and cell-run endpoints"
```

---

### Task 6: `/account` のトークン管理 UI

**Files:**
- Modify: `web/ui/account.lisp`, `web/routes.lisp`, `web/i18n/en.lisp`, `web/i18n/ja.lisp`, `scripts/request-test.sh`
- Create: `tests/web/account-tokens.lisp`
- Modify: `recurya.asd`, `tests/all.lisp`

**Interfaces:**
- Consumes: `issue-api-token`, `list-api-tokens`, `revoke-api-token`, `api-token-limit-exceeded`, `*max-active-tokens*`, model accessors (Task 1)。
- Produces: `recurya/web/ui/account:render-api-tokens` `(tokens &key new-token error)` → `<section id="api-tokens">` の HTML 文字列。`render` は `:tokens` を受け取る。routes: `account-token-create-handler` (POST `/account/tokens`), `account-token-revoke-handler` (POST `/account/tokens/:id/revoke`)。

- [ ] **Step 1: 失敗するテストを書く**

`fs-write-file` で `tests/web/account-tokens.lisp`:

```lisp
;;;; tests/web/account-tokens.lisp --- API token management on /account.

(defpackage #:recurya/tests/web/account-tokens
  (:use #:cl #:rove)
  (:import-from #:recurya/tests/support/db
                #:with-test-db
                #:create-test-user)
  (:import-from #:recurya/db/users
                #:users-id
                #:user-dao->plist)
  (:import-from #:recurya/db/api-tokens
                #:*max-active-tokens*
                #:issue-api-token
                #:list-api-tokens)
  (:import-from #:recurya/models/api-token
                #:api-token-id)
  (:import-from #:recurya/web/routes
                #:account-page-handler
                #:account-token-create-handler
                #:account-token-revoke-handler))

(in-package #:recurya/tests/web/account-tokens)

(defmacro with-user-session ((user) &body body)
  `(let ((ningle/context:*session* (make-hash-table)))
     (when ,user (setf (gethash :user ningle/context:*session*) ,user))
     ,@body))

(defun html-of (res) (first (third res)))

(deftest account-page-wires-token-form-both-sides
  (with-test-db
    (let ((user (user-dao->plist (create-test-user :email-prefix "acct"))))
      (with-user-session (user)
        (let ((html (html-of (account-page-handler nil))))
          (ok (search "id=api-tokens" html) "target section exists")
          (ok (search "hx-post=\"/account/tokens\"" html) "create form posts via HTMX")
          (ok (search "#api-tokens" html) "and targets the section"))))))

(deftest create-shows-plaintext-once-and-lists-token
  (with-test-db
    (let ((user (user-dao->plist (create-test-user :email-prefix "acct"))))
      (with-user-session (user)
        (let ((html (html-of (account-token-create-handler '(("name" . "my laptop"))))))
          (ok (cl-ppcre:scan "rcy_[0-9a-f]{64}" html) "the new token is shown")
          (ok (search "my laptop" html))
          (ok (= 1 (length (list-api-tokens (getf user :id))))))
        (ng (cl-ppcre:scan "rcy_[0-9a-f]{64}" (html-of (account-page-handler nil)))
            "the plaintext is never shown again")))))

(deftest create-over-limit-shows-error
  (with-test-db
    (let* ((dao (create-test-user :email-prefix "acct"))
           (user (user-dao->plist dao)))
      (loop repeat *max-active-tokens* do (issue-api-token (users-id dao) "t"))
      (with-user-session (user)
        (let ((html (html-of (account-token-create-handler '(("name" . "x"))))))
          (ng (cl-ppcre:scan "rcy_[0-9a-f]{64}" html))
          (ok (search (princ-to-string *max-active-tokens*) html) "limit message names the limit"))))))

(deftest revoke-own-token-only
  (with-test-db
    (let* ((alice (create-test-user :email-prefix "acct"))
           (bob (create-test-user :email-prefix "acct"))
           (row (nth-value 1 (issue-api-token (users-id alice) "alice-token"))))
      (with-user-session ((user-dao->plist bob))
        (account-token-revoke-handler `((:id . ,(princ-to-string (api-token-id row))))))
      (ok (= 1 (length (list-api-tokens (users-id alice)))) "bob cannot revoke it")
      (with-user-session ((user-dao->plist alice))
        (let ((html (html-of (account-token-revoke-handler
                              `((:id . ,(princ-to-string (api-token-id row))))))))
          (ng (search "alice-token" html) "revoked token disappears from the list")))
      (ok (null (list-api-tokens (users-id alice)))))))

(deftest token-routes-require-login
  (with-user-session (nil)
    (ok (= 302 (first (account-token-create-handler '(("name" . "x"))))))
    (ok (= 302 (first (account-token-revoke-handler '((:id . "1"))))))))
```

asd の Web tests に `"recurya/tests/web/account-tokens"`、`tests/all.lisp` に `:recurya/tests/web/account-tokens`。

- [ ] **Step 2: 失敗を確認** — `account-token-create-handler` 未定義の red。

- [ ] **Step 3: i18n キーを追加**

`web/i18n/en.lisp` の `;;; --- flash ---` の直前 (account ブロック末尾) に:

```lisp
  (:account.tokens.heading    "API tokens")
  (:account.tokens.body       "Personal access tokens let the recurya CLI act as you. Treat them like passwords.")
  (:account.tokens.name_label "Token name")
  (:account.tokens.create     "Create token")
  (:account.tokens.new_notice "Copy this token now. It will not be shown again.")
  (:account.tokens.empty      "No active tokens.")
  (:account.tokens.col_name   "Name")
  (:account.tokens.col_token  "Token")
  (:account.tokens.col_created "Created")
  (:account.tokens.col_last_used "Last used")
  (:account.tokens.never      "Never")
  (:account.tokens.revoke     "Revoke")
  (:account.tokens.limit      "You can have at most ~D active tokens. Revoke one first.")
```

`web/i18n/ja.lisp` の同位置に:

```lisp
  (:account.tokens.heading    "APIトークン")
  (:account.tokens.body       "個人用アクセストークンを使うと recurya CLI があなたとして操作できます。パスワードと同様に扱ってください。")
  (:account.tokens.name_label "トークン名")
  (:account.tokens.create     "トークンを発行")
  (:account.tokens.new_notice "このトークンを今すぐコピーしてください。再表示はできません。")
  (:account.tokens.empty      "有効なトークンはありません。")
  (:account.tokens.col_name   "名前")
  (:account.tokens.col_token  "トークン")
  (:account.tokens.col_created "作成日時")
  (:account.tokens.col_last_used "最終使用")
  (:account.tokens.never      "未使用")
  (:account.tokens.revoke     "失効")
  (:account.tokens.limit      "有効なトークンは最大 ~D 個です。先にどれかを失効してください。")
```

(これらのファイルは `defcatalog` フォーム内の要素なので `lisp-patch-form` で `(:flash.account.saved` の行の前に挿入する。)

- [ ] **Step 4: UI を実装**

`web/ui/account.lisp`:
- defpackage に `(:import-from #:recurya/models/api-token #:api-token-id #:api-token-name #:api-token-token-prefix #:api-token-created-at #:api-token-last-used-at)`、`(:import-from #:recurya/db/core #:null->nil)`、`(:import-from #:recurya/db/api-tokens #:*max-active-tokens*)`、export に `#:render-api-tokens`。
- `render` の直前に `lisp-edit-form insert_before render`:

```lisp
(defun format-token-time (timestamp)
  "TIMESTAMP as YYYY-MM-DD HH:MM (UTC), or NIL for NIL/:NULL."
  (let ((ts (null->nil timestamp)))
    (when ts
      (local-time:format-timestring
       nil ts :format '(:year "-" (:month 2) "-" (:day 2) " " (:hour 2) ":" (:min 2))
              :timezone local-time:+utc-zone+))))

(defun render-api-tokens (tokens &key new-token error)
  "The API token section (#api-tokens): an HTMX form to issue a token, the
just-issued NEW-TOKEN shown once, ERROR if any, and TOKENS (rows) with a
revoke button each.  Returned as an HTML string; it is both part of the
account page and the HTMX swap response."
  (with-html-string
    (:section :id "api-tokens" :class "card"
      (:h2 (tr :account.tokens.heading))
      (:p :class "muted" (tr :account.tokens.body))
      (when error
        (:div :class "message error" error))
      (when new-token
        (:div :class "message success"
          (:p (tr :account.tokens.new_notice))
          (:pre (:code new-token))))
      (:form :class "settings" :hx-post "/account/tokens"
             :hx-target "#api-tokens" :hx-swap "outerHTML"
        (:raw (csrf-input))
        (:div
          (:label :for "api-token-name" (tr :account.tokens.name_label))
          (:input :id "api-token-name" :name "name" :type "text" :maxlength "64"))
        (:button :type "submit" :class "button-primary" (tr :account.tokens.create)))
      (if (null tokens)
          (:p :class "muted" (tr :account.tokens.empty))
          (:table
            (:thead
              (:tr (:th (tr :account.tokens.col_name))
                   (:th (tr :account.tokens.col_token))
                   (:th (tr :account.tokens.col_created))
                   (:th (tr :account.tokens.col_last_used))
                   (:th "")))
            (:tbody
              (dolist (row tokens)
                (:tr
                  (:td (api-token-name row))
                  (:td (:code (api-token-token-prefix row) "…"))
                  (:td (or (format-token-time (api-token-created-at row)) ""))
                  (:td (or (format-token-time (api-token-last-used-at row))
                           (tr :account.tokens.never)))
                  (:td
                    (:form :hx-post (format nil "/account/tokens/~D/revoke" (api-token-id row))
                           :hx-target "#api-tokens" :hx-swap "outerHTML"
                      (:raw (csrf-input))
                      (:button :type "submit" :class "button-danger"
                               (tr :account.tokens.revoke))))))))))))
```

- `render` の lambda list を `(&key user message error tokens)` に変え、Danger zone の `(:div :class "card" (:h2 (tr :account.danger.heading)) ...)` の直前に `(:raw (render-api-tokens tokens))` を挿入 (`lisp-patch-form`)。

- [ ] **Step 5: routes を実装**

`web/routes.lisp`:
- defpackage に `(:import-from #:recurya/db/api-tokens #:issue-api-token #:list-api-tokens #:revoke-api-token #:api-token-limit-exceeded #:*max-active-tokens*)`。
- `account-page-handler` の render 呼び出しに `:tokens (list-api-tokens (getf user :id))` を追加 (`lisp-patch-form`: `(recurya/web/ui/account:render :user user` → `(recurya/web/ui/account:render :user user :tokens (list-api-tokens (getf user :id))`)。
- `account-confirm-delete-handler` の前に `lisp-edit-form insert_before`:

```lisp
(defun account-token-create-handler (params)
  "Handle POST /account/tokens - issue an API token and return the
#api-tokens section showing it once (HTMX swap)."
  (let ((user (get-current-user)))
    (if (null user)
        (redirect "/login")
        (let ((uid (getf user :id)))
          (handler-case
              (let ((plaintext (issue-api-token uid (get-param params "name"))))
                (html-response
                 (recurya/web/ui/account:render-api-tokens
                  (list-api-tokens uid) :new-token plaintext)))
            (api-token-limit-exceeded ()
              (html-response
               (recurya/web/ui/account:render-api-tokens
                (list-api-tokens uid)
                :error (tr :account.tokens.limit *max-active-tokens*)))))))))

(defun account-token-revoke-handler (params)
  "Handle POST /account/tokens/:id/revoke - revoke one of the user's tokens
and return the refreshed #api-tokens section (HTMX swap)."
  (let ((user (get-current-user)))
    (if (null user)
        (redirect "/login")
        (let* ((uid (getf user :id))
               (raw (get-path-param params :id))
               (token-id (and (stringp raw) (parse-integer raw :junk-allowed t))))
          (when token-id (revoke-api-token uid token-id))
          (html-response
           (recurya/web/ui/account:render-api-tokens (list-api-tokens uid)))))))
```

- `setup-routes` の `/account/delete` 登録の後に:

```lisp
  (setf (ningle/app:route app "/account/tokens" :method :post)
          (make-dynamic-handler 'account-token-create-handler))
  (setf (ningle/app:route app "/account/tokens/:id/revoke" :method :post)
          (make-dynamic-handler 'account-token-revoke-handler))
```

- export に `#:account-token-create-handler #:account-token-revoke-handler`。

- [ ] **Step 6: テストを通す**

`run-tests` で `recurya/tests/web/account-tokens` 5 件と、既存の `recurya/tests/web/i18n-catalog` / `recurya/tests/web/routes` → PASS。

- [ ] **Step 7: request-test にチェックを追加して実行**

`scripts/request-test.sh` の末尾の集計の前に (既存ブロックの書式に合わせて):

```bash
echo "== /account API tokens (logged in via dev stub) =="
rt_reset_session; rt_login
rt_status 200 "$(rt_get /account)" "account page renders"
rt_contains 'hx-post="/account/tokens"' "token form posts via HTMX"
rt_contains '#api-tokens' "token form targets #api-tokens"
rt_contains 'id=api-tokens' "target #api-tokens exists (both-sides)"
rt_status 200 "$(rt_hx_post /account/tokens 'name=request-test')" "create token fragment"
rt_contains 'id=api-tokens' "fragment is the #api-tokens section"
grep -qE 'rcy_[0-9a-f]{64}' "$BODY" && _ok "fragment shows the new token once" \
  || _bad "fragment shows the new token once"
TOKEN="$(grep -oE 'rcy_[0-9a-f]{64}' "$BODY" | head -1)"
code=$(curl -s -o "$BODY" -w '%{http_code}' -H "Authorization: Bearer $TOKEN" "$BASE/api/v1/me")
rt_status 200 "$code" "the new token authenticates /api/v1/me"
rt_contains '"handle"' "/api/v1/me returns the handle"
```

`load-system recurya` 後、`./scripts/request-test.sh` → 全 PASS (dev サーバは `OAUTH_DEV_STUB` 有効が前提。stub ユーザーの handle が placeholder なら `/account` が onboarding に飛ぶので、その場合は dev DB の stub ユーザーで一度 onboarding を済ませる)。作成されたトークンはテスト後に `/account` から失効してよい (dev データ)。

- [ ] **Step 8: Commit**

```bash
git add web/ui/account.lisp web/routes.lisp web/i18n/en.lisp web/i18n/ja.lisp \
  tests/web/account-tokens.lisp tests/all.lisp recurya.asd scripts/request-test.sh
git commit -m "feat(account): issue, list and revoke API tokens on /account"
```

**視覚確認 (ユーザー依頼)**: テーブルとフォームのレイアウトは CSS 依存なので、Task 9 の報告時にブラウザでの見た目確認を依頼する。

---

### Task 7: CLI の純粋部分 (ワークスペースと結果整形)

**Files:**
- Create: `cli/workspace.lisp`, `cli/report.lisp`, `tests/cli/workspace.lisp`, `tests/cli/report.lisp`
- Modify: `recurya.asd` (tests の `:depends-on`)、`tests/all.lisp`

**Interfaces:**
- 入力は API の JSON を jzon で parse したもの (string キーの `equal` ハッシュ、配列はベクタ、null は `'null`)。
- Produces (`recurya/cli/workspace`):
  - `(index-width n-cells)` → `(max 2 桁数(n-cells - 1))`
  - `(cell-file-name index kind width)` → `"03-exercise.wl"` / `"01-eval.wl"` / `"04-solution.wl"`、他 kind は NIL
  - `(initial-code cell)` → `saved_code` が文字列ならそれ、次に `body` が文字列ならそれ、他は `""`
  - `(content-hash string)` → SHA-256 hex
  - `(render-readme notebook width)` → README.md 文字列
  - `(plan-pull notebook width old-manifest existing force)` → `(values actions new-manifest)`。EXISTING は `(file . 現在内容)` の alist (無いファイルは含めない)。actions は `(:write file content)` または `(:keep file)` のリスト
  - `(manifest-cells manifest)`, `(manifest-cell manifest index)`
  - `(collect-codes manifest index read-file)` → セル 0..INDEX のコード列 (eval/exercise はファイル内容、ファイル無しや他 kind は `""`)。READ-FILE は file 名 → 内容 or NIL の関数
  - `(resolve-cell-arg arg manifest)` → index (`"03"`, `"3"`, `"03-exercise.wl"`); 実行不可/不在は `workspace-error`
  - `(manifest->json manifest)` / `(json->manifest string)`、condition `workspace-error` (reader `workspace-error-message`)
- Produces (`recurya/cli/report`):
  - `(format-run-result result width stream)`、`(result-exit-code result)` → `"pass"`/`"ok"` は 0、他 1
  - `(format-notebook-list json stream)`、`(format-status manifest modified-files stream)`

マニフェストは JSON オブジェクト:
`{"server", "handle", "slug", "title", "width", "cells": [{"index", "cell_id", "kind", "file" (string|null), "hash" (string|null), "passed", "unlocked"}]}`。

- [ ] **Step 1: 失敗するテストを書く**

`fs-write-file` で `tests/cli/workspace.lisp`:

```lisp
;;;; tests/cli/workspace.lisp --- CLI workspace layout, manifest and pull plan.

(defpackage #:recurya/tests/cli/workspace
  (:use #:cl #:rove)
  (:import-from #:recurya/cli/workspace
                #:index-width
                #:cell-file-name
                #:initial-code
                #:content-hash
                #:render-readme
                #:plan-pull
                #:manifest-cell
                #:collect-codes
                #:resolve-cell-arg
                #:manifest->json
                #:json->manifest
                #:workspace-error))

(in-package #:recurya/tests/cli/workspace)

(defun jobj (&rest kv)
  (let ((h (make-hash-table :test 'equal)))
    (loop for (k v) on kv by #'cddr do (setf (gethash k h) v))
    h))

(defun cell (index kind &key (body "") saved (unlocked t) (passed nil) (description "")
                         (tests #()))
  (jobj "index" index "cell_id" (format nil "c~D" index) "kind" kind
        "body" body "saved_code" (or saved 'null) "unlocked" unlocked
        "passed" passed "description" description "test_cases" tests "gated" nil))

(defun notebook (&rest cells)
  (jobj "handle" "alice" "slug" "nb" "title" "Title" "summary" "Sum"
        "cells" (coerce cells 'vector)))

(defparameter *nb*
  (notebook (cell 0 "prose" :body "Intro text")
            (cell 1 "code-eval" :body "(+ 1 2)")
            (cell 2 "code-exercise" :body "; fill" :saved "(saved)"
                  :description "Write it"
                  :tests (vector (jobj "input" "(f 1)" "expected" "2" "description" "")))
            (cell 3 "code-solution" :body 'null :unlocked nil)
            (cell 4 "scene" :body "(scene)")))

(deftest widths-and-file-names
  (ok (= 2 (index-width 5)))
  (ok (= 2 (index-width 100)))
  (ok (= 3 (index-width 101)))
  (ok (string= "03-exercise.wl" (cell-file-name 3 "code-exercise" 2)))
  (ok (string= "001-eval.wl" (cell-file-name 1 "code-eval" 3)))
  (ok (string= "04-solution.wl" (cell-file-name 4 "code-solution" 2)))
  (ng (cell-file-name 0 "prose" 2))
  (ng (cell-file-name 4 "scene" 2)))

(deftest initial-code-prefers-saved
  (ok (string= "(saved)" (initial-code (cell 2 "code-exercise" :body "; fill" :saved "(saved)"))))
  (ok (string= "; fill" (initial-code (cell 2 "code-exercise" :body "; fill"))))
  (ok (string= "" (initial-code (cell 3 "code-solution" :body 'null)))))

(deftest readme-mentions-every-cell
  (let ((md (render-readme *nb* 2)))
    (ok (search "# Title" md))
    (ok (search "Intro text" md))
    (ok (search "01-eval.wl" md))
    (ok (search "Write it" md))
    (ok (search "(f 1)" md))
    (ok (search "02-exercise.wl" md))
    (ok (search "locked" md) "locked solution is marked")
    (ok (search "not supported" md) "scene cell is marked")))

(deftest fresh-pull-writes-code-cells-only
  (multiple-value-bind (actions manifest) (plan-pull *nb* 2 nil '() nil)
    (ok (equal '((:write "01-eval.wl" "(+ 1 2)") (:write "02-exercise.wl" "(saved)"))
               actions))
    (ok (string= (content-hash "(saved)")
                 (gethash "hash" (manifest-cell manifest 2))))
    (ok (eq 'null (gethash "file" (manifest-cell manifest 3))) "locked solution has no file")))

(deftest repull-keeps-edited-files-unless-forced
  (let ((old (nth-value 1 (plan-pull *nb* 2 nil '() nil))))
    (let ((existing '(("01-eval.wl" . "(+ 1 2)") ("02-exercise.wl" . "(my edit)"))))
      (ok (equal '((:write "01-eval.wl" "(+ 1 2)") (:keep "02-exercise.wl"))
                 (plan-pull *nb* 2 old existing nil)))
      (ok (equal '((:write "01-eval.wl" "(+ 1 2)") (:write "02-exercise.wl" "(saved)"))
                 (plan-pull *nb* 2 old existing t))))
    (ok (equal '((:keep "01-eval.wl") (:keep "02-exercise.wl"))
               (plan-pull *nb* 2 nil '(("01-eval.wl" . "x") ("02-exercise.wl" . "y")) nil))
        "without a manifest, existing files are never overwritten")))

(deftest unlocked-solution-gets-a-file
  (let ((nb (notebook (cell 0 "code-exercise" :body "x")
                      (cell 1 "code-solution" :body "(answer)" :unlocked t))))
    (ok (equal '((:write "00-exercise.wl" "x") (:write "01-solution.wl" "(answer)"))
               (plan-pull nb 2 nil '() nil)))))

(deftest collect-codes-sends-files-for-code-cells
  (let ((manifest (nth-value 1 (plan-pull *nb* 2 nil '() nil))))
    (ok (equal '("" "(+ 1 2)" "(mine)")
               (collect-codes manifest 2
                              (lambda (f) (cdr (assoc f '(("01-eval.wl" . "(+ 1 2)")
                                                          ("02-exercise.wl" . "(mine)"))
                                                      :test #'string=))))))
    (ok (equal '("" "" "") (collect-codes manifest 2 (constantly nil)))
        "missing files are sent as empty code")))

(deftest resolve-cell-arg-forms
  (let ((manifest (nth-value 1 (plan-pull *nb* 2 nil '() nil))))
    (ok (= 2 (resolve-cell-arg "02" manifest)))
    (ok (= 2 (resolve-cell-arg "2" manifest)))
    (ok (= 2 (resolve-cell-arg "02-exercise.wl" manifest)))
    (ok (signals (resolve-cell-arg "0" manifest) 'workspace-error) "prose cannot run")
    (ok (signals (resolve-cell-arg "3" manifest) 'workspace-error) "solution cannot run")
    (ok (signals (resolve-cell-arg "99" manifest) 'workspace-error))
    (ok (signals (resolve-cell-arg "abc" manifest) 'workspace-error))))

(deftest manifest-json-roundtrip
  (let ((manifest (nth-value 1 (plan-pull *nb* 2 nil '() nil))))
    (let ((back (json->manifest (manifest->json manifest))))
      (ok (string= "alice" (gethash "handle" back)))
      (ok (string= "02-exercise.wl" (gethash "file" (manifest-cell back 2)))))))
```

`fs-write-file` で `tests/cli/report.lisp`:

```lisp
;;;; tests/cli/report.lisp --- CLI output formatting.

(defpackage #:recurya/tests/cli/report
  (:use #:cl #:rove)
  (:import-from #:recurya/cli/report
                #:format-run-result
                #:result-exit-code
                #:format-notebook-list))

(in-package #:recurya/tests/cli/report)

(defun jobj (&rest kv)
  (let ((h (make-hash-table :test 'equal)))
    (loop for (k v) on kv by #'cddr do (setf (gethash k h) v))
    h))

(defun result (status &key (tests #()) (error 'null) (error-cell 'null) (output "")
                           (value 'null) (revealed #()))
  (jobj "status" status "value" value "output" output "error" error
        "error_cell_index" error-cell "tests" tests
        "metrics" (jobj "steps" 12 "cons" 3 "depth" 4)
        "revealed_solutions" revealed))

(defun render (r) (with-output-to-string (s) (format-run-result r 2 s)))

(deftest pass-and-fail-summaries
  (let ((tests (vector (jobj "input" "(f 1)" "expected" "2" "actual" "2" "passed" t
                             "error" 'null "description" 'null)
                       (jobj "input" "(f 2)" "expected" "4" "actual" "3" "passed" nil
                             "error" 'null "description" 'null))))
    (let ((out (render (result "fail" :tests tests))))
      (ok (search "FAIL" out))
      (ok (search "1 of 2" out))
      (ok (search "(f 2)" out))
      (ok (search "expected 4" out))
      (ok (search "got 3" out))
      (ok (search "steps 12" out)))
    (ok (search "PASS" (render (result "pass" :tests (vector (aref tests 0))))))))

(deftest error-names-the-cell-and-ok-shows-value
  (let ((out (render (result "error" :error "Undefined variable: x" :error-cell 1))))
    (ok (search "ERROR" out))
    (ok (search "cell 01" out))
    (ok (search "Undefined variable: x" out)))
  (ok (search "=> 3" (render (result "ok" :value "3")))))

(deftest revealed-solutions-are-announced
  (ok (search "04-solution.wl"
              (render (result "pass" :revealed (vector (jobj "index" 4 "cell_id" "s" "body" "x")))))))

(deftest exit-codes
  (ok (= 0 (result-exit-code (result "pass"))))
  (ok (= 0 (result-exit-code (result "ok"))))
  (ok (= 1 (result-exit-code (result "fail"))))
  (ok (= 1 (result-exit-code (result "error")))))

(deftest notebook-list-lines
  (let ((out (with-output-to-string (s)
               (format-notebook-list
                (jobj "items" (vector (jobj "handle" "alice" "slug" "nb" "title" "T" "summary" 'null))
                      "page" 1 "per_page" 20 "total" 1)
                s))))
    (ok (search "@alice/nb" out))
    (ok (search "T" out))))
```

asd の `recurya/tests` に `"recurya/tests/cli/workspace"`, `"recurya/tests/cli/report"`、`tests/all.lisp` に同 package を追加。

- [ ] **Step 2: 失敗を確認** — package 不在の red。

- [ ] **Step 3: workspace を実装**

`fs-write-file` で `cli/workspace.lisp`:

```lisp
;;;; cli/workspace.lisp --- Local layout of a pulled notebook.
;;;;
;;;; A pulled notebook is a directory with README.md (prose, exercise
;;;; descriptions and tests), one NN-<kind>.wl file per code cell, and
;;;; .recurya/notebook.json, the manifest recording each cell's file and the
;;;; hash of what was last written there.  Everything here is pure except
;;;; the callers' file reads and writes; notebooks and manifests are jzon
;;;; objects (EQUAL hash tables with string keys).

(defpackage #:recurya/cli/workspace
  (:use #:cl)
  (:import-from #:ironclad
                #:digest-sequence
                #:byte-array-to-hex-string)
  (:import-from #:babel
                #:string-to-octets)
  (:export #:index-width
           #:cell-file-name
           #:initial-code
           #:content-hash
           #:render-readme
           #:plan-pull
           #:manifest-cells
           #:manifest-cell
           #:collect-codes
           #:resolve-cell-arg
           #:manifest->json
           #:json->manifest
           #:workspace-error
           #:workspace-error-message))

(in-package #:recurya/cli/workspace)

(define-condition workspace-error (error)
  ((message :initarg :message :reader workspace-error-message))
  (:report (lambda (c stream) (write-string (workspace-error-message c) stream))))

(defun workspace-error (control &rest args)
  "Signal a WORKSPACE-ERROR with a message formatted from CONTROL and ARGS."
  (error 'workspace-error :message (apply #'format nil control args)))

(defun jobj (&rest keys-and-values)
  "A JSON object from alternating string keys and values."
  (let ((h (make-hash-table :test 'equal)))
    (loop for (k v) on keys-and-values by #'cddr
          do (setf (gethash k h) v))
    h))

(defun jstring (value)
  "VALUE when it is a string, else NIL (JSON null and absent read as NIL)."
  (and (stringp value) value))

(defun index-width (n-cells)
  "Digits used to number files in a notebook of N-CELLS cells (at least 2)."
  (max 2 (length (princ-to-string (max 0 (1- n-cells))))))

(defun kind-suffix (kind)
  "File-name suffix of a cell KIND that gets a code file, or NIL."
  (cond ((string= kind "code-eval") "eval")
        ((string= kind "code-exercise") "exercise")
        ((string= kind "code-solution") "solution")
        (t nil)))

(defun cell-file-name (index kind width)
  "File name of the code cell at INDEX of KIND (\"03-exercise.wl\"), or NIL
for cells without a code file (prose, scene)."
  (let ((suffix (kind-suffix kind)))
    (and suffix (format nil "~v,'0D-~A.wl" width index suffix))))

(defun initial-code (cell)
  "What a fresh pull writes for CELL: the reader's saved code, else the body."
  (or (jstring (gethash "saved_code" cell))
      (jstring (gethash "body" cell))
      ""))

(defun content-hash (string)
  "SHA-256 of STRING's UTF-8 octets as lower-case hex."
  (byte-array-to-hex-string
   (digest-sequence :sha256 (string-to-octets string :encoding :utf-8))))

(defun cells-of (notebook)
  "NOTEBOOK's cells as a list."
  (coerce (gethash "cells" notebook) 'list))

(defun cell-file (cell width)
  "The file CELL is written to, or NIL (prose, scene, locked solution)."
  (let ((kind (gethash "kind" cell)))
    (and (or (string/= kind "code-solution") (eq (gethash "unlocked" cell) t))
         (cell-file-name (gethash "index" cell) kind width))))

(defun render-readme (notebook width)
  "README.md for NOTEBOOK: its prose, exercise descriptions and tests, and a
pointer to the file of each code cell, in cell order."
  (with-output-to-string (s)
    (format s "# ~A~%~%" (gethash "title" notebook))
    (let ((summary (jstring (gethash "summary" notebook))))
      (when (and summary (plusp (length summary)))
        (format s "~A~%~%" summary)))
    (dolist (cell (cells-of notebook))
      (let* ((index (gethash "index" cell))
             (kind (gethash "kind" cell))
             (file (cell-file cell width))
             (label (format nil "~v,'0D" width index)))
        (cond
          ((string= kind "prose")
           (format s "~A~%~%" (or (jstring (gethash "body" cell)) "")))
          ((string= kind "code-exercise")
           (format s "## [~A] Exercise~%~%" label)
           (let ((desc (jstring (gethash "description" cell))))
             (when (and desc (plusp (length desc)))
               (format s "~A~%~%" desc)))
           (let ((tests (coerce (gethash "test_cases" cell) 'list)))
             (when tests
               (format s "Tests:~%~%")
               (dolist (tc tests)
                 (format s "- `~A` => `~A`~%" (gethash "input" tc) (gethash "expected" tc)))
               (terpri s)))
           (format s "→ `~A` (run: `recurya run ~A`)~%~%" file label))
          ((string= kind "code-eval")
           (format s "→ `~A` (run: `recurya run ~A`)~%~%" file label))
          ((string= kind "code-solution")
           (if file
               (format s "→ `~A` (solution)~%~%" file)
               (format s "_[~A] Solution locked — pass the exercise above to unlock it._~%~%"
                       label)))
          (t
           (format s "_[~A] ~A cell — not supported by the CLI; open it in the browser._~%~%"
                   label kind)))))))

(defun old-hash (old-manifest file)
  "The hash OLD-MANIFEST recorded for FILE, or NIL."
  (when old-manifest
    (loop for cell in (manifest-cells old-manifest)
          when (equal (jstring (gethash "file" cell)) file)
            do (return (jstring (gethash "hash" cell))))))

(defun plan-pull (notebook width old-manifest existing force)
  "Decide what pulling NOTEBOOK writes.  EXISTING is an alist of
(file . current content) for the code files already on disk.  A file is
written when it is absent, already equal to the new content, unchanged since
the last pull (its content hash equals OLD-MANIFEST's), or when FORCE;
otherwise it is kept.
Returns (VALUES ACTIONS MANIFEST): ACTIONS is a list of (:WRITE FILE CONTENT)
and (:KEEP FILE); MANIFEST is the new manifest (without \"server\")."
  (let ((actions '())
        (cells '()))
    (dolist (cell (cells-of notebook))
      (let* ((file (cell-file cell width))
             (content (and file (initial-code cell)))
             (current (and file (assoc file existing :test #'string=)))
             (hash nil))
        (when file
          (cond
            ((or (null current)
                 force
                 (string= (cdr current) content)
                 (equal (content-hash (cdr current)) (old-hash old-manifest file)))
             (push (list :write file content) actions)
             (setf hash (content-hash content)))
            (t
             (push (list :keep file) actions)
             (setf hash (old-hash old-manifest file)))))
        (push (jobj "index" (gethash "index" cell)
                    "cell_id" (gethash "cell_id" cell)
                    "kind" (gethash "kind" cell)
                    "file" (or file 'null)
                    "hash" (or hash 'null)
                    "passed" (eq (gethash "passed" cell) t)
                    "unlocked" (eq (gethash "unlocked" cell) t))
              cells)))
    (values (nreverse actions)
            (jobj "handle" (gethash "handle" notebook)
                  "slug" (gethash "slug" notebook)
                  "title" (gethash "title" notebook)
                  "width" width
                  "cells" (coerce (nreverse cells) 'vector)))))

(defun manifest-cells (manifest)
  "MANIFEST's cell entries as a list."
  (coerce (gethash "cells" manifest) 'list))

(defun manifest-cell (manifest index)
  "MANIFEST's entry for cell INDEX, or NIL."
  (find index (manifest-cells manifest) :key (lambda (c) (gethash "index" c))))

(defun collect-codes (manifest index read-file)
  "The codes of cells 0..INDEX to submit: an eval or exercise cell sends the
content of its file (READ-FILE returns it, or NIL when missing); every other
cell, and a missing file, sends \"\", as the browser does."
  (loop for i from 0 to index
        for cell = (manifest-cell manifest i)
        collect (let ((file (and cell (jstring (gethash "file" cell))))
                      (kind (and cell (gethash "kind" cell))))
                  (or (and file
                           (member kind '("code-eval" "code-exercise") :test #'string=)
                           (funcall read-file file))
                      ""))))

(defun resolve-cell-arg (arg manifest)
  "The index of the runnable cell named by ARG: \"03\", \"3\" or a file name
such as \"03-exercise.wl\".  Signals WORKSPACE-ERROR when ARG names no cell or
a cell that cannot be run."
  (let* ((digits (subseq arg 0 (or (position-if-not #'digit-char-p arg) (length arg))))
         (index (and (plusp (length digits)) (parse-integer digits)))
         (cell (and index (manifest-cell manifest index))))
    (cond
      ((null index) (workspace-error "Not a cell number or file: ~A" arg))
      ((null cell) (workspace-error "No cell ~A in this notebook" arg))
      ((not (member (gethash "kind" cell) '("code-eval" "code-exercise") :test #'string=))
       (workspace-error "Cell ~A is a ~A cell and cannot be run" arg (gethash "kind" cell)))
      (t index))))

(defun manifest->json (manifest)
  "MANIFEST as pretty-printed JSON text."
  (com.inuoe.jzon:stringify manifest :pretty t))

(defun json->manifest (text)
  "Parse manifest TEXT.  Signals WORKSPACE-ERROR when it is not a JSON object."
  (let ((data (handler-case (com.inuoe.jzon:parse text) (error () nil))))
    (unless (hash-table-p data)
      (workspace-error "Corrupt manifest .recurya/notebook.json"))
    data))
```

注: `plan-pull` のテストは `(:write ...)` / `(:keep ...)` が **セル順** で並ぶことを期待している (`nreverse` で保証)。

- [ ] **Step 4: report を実装**

`fs-write-file` で `cli/report.lisp`:

```lisp
;;;; cli/report.lisp --- Human-readable output of the recurya CLI.

(defpackage #:recurya/cli/report
  (:use #:cl)
  (:import-from #:recurya/cli/workspace
                #:cell-file-name)
  (:export #:format-run-result
           #:result-exit-code
           #:format-notebook-list
           #:format-status))

(in-package #:recurya/cli/report)

(defun jstring (value)
  (and (stringp value) value))

(defun result-exit-code (result)
  "0 when RESULT's status is \"pass\" or \"ok\", 1 otherwise."
  (if (member (gethash "status" result) '("pass" "ok") :test #'equal) 0 1))

(defun format-run-result (result width stream)
  "Write RESULT, a cell-run response, to STREAM: status line, one line per
test, print output, error (with the cell it came from), resources used, and
any solution files the run unlocked.  WIDTH numbers cells like file names."
  (let* ((status (gethash "status" result))
         (tests (coerce (gethash "tests" result) 'list))
         (failed (count-if-not (lambda (tr) (eq (gethash "passed" tr) t)) tests)))
    (cond
      ((string= status "pass")
       (format stream "PASS  all ~D test~:P passed~%" (length tests)))
      ((string= status "fail")
       (format stream "FAIL  ~D of ~D test~:P failed~%" failed (length tests)))
      ((string= status "ok")
       (format stream "OK    => ~A~%" (or (jstring (gethash "value" result)) "")))
      (t (format stream "ERROR~%")))
    (dolist (tr tests)
      (format stream "  ~:[✗~;✓~] ~A  expected ~A  got ~A~%"
              (eq (gethash "passed" tr) t)
              (gethash "input" tr)
              (gethash "expected" tr)
              (or (jstring (gethash "actual" tr))
                  (format nil "error: ~A" (or (jstring (gethash "error" tr)) "?")))))
    (let ((out (jstring (gethash "output" result))))
      (when (and out (plusp (length out)))
        (format stream "output:~%~A~&" out)))
    (let ((err (jstring (gethash "error" result)))
          (cell (gethash "error_cell_index" result)))
      (when err
        (if (integerp cell)
            (format stream "error (cell ~v,'0D): ~A~%" width cell err)
            (format stream "error: ~A~%" err))))
    (let ((m (gethash "metrics" result)))
      (when (hash-table-p m)
        (format stream "steps ~D · cons ~D · depth ~D~%"
                (gethash "steps" m) (gethash "cons" m) (gethash "depth" m))))
    (dolist (rev (coerce (gethash "revealed_solutions" result) 'list))
      (format stream "unlocked: ~A~%"
              (cell-file-name (gethash "index" rev) "code-solution" width)))))

(defun format-notebook-list (json stream)
  "One line per notebook of a GET /api/v1/notebooks response, plus paging."
  (dolist (item (coerce (gethash "items" json) 'list))
    (format stream "@~A/~A  ~A~%" (gethash "handle" item) (gethash "slug" item)
            (gethash "title" item)))
  (format stream "-- page ~D, ~D notebook~:P in total~%"
          (gethash "page" json) (gethash "total" json)))

(defun format-status (manifest modified-files stream)
  "One line per code cell of MANIFEST: file, passed or not, and whether the
file differs from what was last pulled (MODIFIED-FILES)."
  (format stream "@~A/~A  ~A~%" (gethash "handle" manifest) (gethash "slug" manifest)
          (gethash "title" manifest))
  (dolist (cell (coerce (gethash "cells" manifest) 'list))
    (let ((file (jstring (gethash "file" cell))))
      (when file
        (format stream "  ~A~30T~:[        ~;passed  ~]~:[~;modified~]~%"
                file
                (eq (gethash "passed" cell) t)
                (member file modified-files :test #'string=))))))
```

- [ ] **Step 5: テストを通す**

`run-tests` で `recurya/tests/cli/workspace` と `recurya/tests/cli/report` → PASS。

- [ ] **Step 6: Commit**

```bash
git add cli/workspace.lisp cli/report.lisp tests/cli/workspace.lisp tests/cli/report.lisp \
  tests/all.lisp recurya.asd
git commit -m "feat(cli): notebook workspace layout, pull plan and result formatting"
```

---

### Task 8: CLI の設定・HTTP クライアント・コマンドと Roswell スクリプト

**Files:**
- Create: `cli/config.lisp`, `cli/client.lisp`, `cli/main.lisp`, `roswell/recurya.ros`, `tests/cli/main.lisp`
- Modify: `recurya.asd` (tests)、`tests/all.lisp`

**Interfaces:**
- Consumes: Task 7 の全関数、API (Task 5)。
- Produces:
  - `recurya/cli/config`: `(config-dir)` (`$RECURYA_CONFIG_DIR`、なければ `$XDG_CONFIG_HOME/recurya`、なければ `~/.config/recurya/`)、`(load-config)` → hash または NIL、`(save-config server token)`、`(resolve-server explicit config)` (`--server` > `RECURYA_SERVER` > config)。
  - `recurya/cli/client`: condition `api-error` (`api-error-status`, `api-error-code`, `api-error-message`)、condition `request-failed` (`request-failed-message`)、`(fetch-me server token)`, `(fetch-notebooks server token page)`, `(fetch-notebook server token handle slug)`, `(post-cell-run server token handle slug index codes)`。
  - `recurya/cli/main`: `(main argv)` → 終了コード (0/1/2)、`(parse-args argv)` → `(values command positional options)`。

- [ ] **Step 1: 失敗するテストを書く**

`fs-write-file` で `tests/cli/main.lisp`:

```lisp
;;;; tests/cli/main.lisp --- CLI argument parsing, config and dependency boundary.

(defpackage #:recurya/tests/cli/main
  (:use #:cl #:rove)
  (:import-from #:recurya/cli/main
                #:parse-args
                #:main)
  (:import-from #:recurya/cli/config
                #:config-dir
                #:load-config
                #:save-config
                #:resolve-server)
  ;; Bare import: declares the sb-posix dependency (setenv, stat).
  (:import-from #:sb-posix))

(in-package #:recurya/tests/cli/main)

(defmacro with-temp-config-dir ((var) &body body)
  `(let ((,var (uiop:ensure-directory-pathname
                (format nil "~A/recurya-cli-test-~36R/"
                        (string-right-trim "/" (namestring (uiop:temporary-directory)))
                        (random (expt 36 8) (make-random-state t))))))
     (sb-posix:setenv "RECURYA_CONFIG_DIR" (namestring ,var) 1)
     (unwind-protect (progn ,@body)
       (sb-posix:unsetenv "RECURYA_CONFIG_DIR")
       (uiop:delete-directory-tree ,var :validate t :if-does-not-exist :ignore))))

(deftest parse-args-splits-options
  (multiple-value-bind (cmd pos opts) (parse-args '("pull" "@a/b" "dir" "--force"))
    (ok (string= "pull" cmd))
    (ok (equal '("@a/b" "dir") pos))
    (ok (eq t (getf opts :force))))
  (multiple-value-bind (cmd pos opts) (parse-args '("login" "--server" "http://x" "--token" "t"))
    (ok (string= "login" cmd))
    (ok (null pos))
    (ok (string= "http://x" (getf opts :server)))
    (ok (string= "t" (getf opts :token))))
  (multiple-value-bind (cmd pos opts) (parse-args '("list" "--page" "2"))
    (declare (ignore pos))
    (ok (string= "list" cmd))
    (ok (string= "2" (getf opts :page)))))

(deftest config-roundtrip-and-permissions
  (with-temp-config-dir (dir)
    (ok (null (load-config)))
    (save-config "http://localhost:13000" "rcy_abc")
    (let ((cfg (load-config)))
      (ok (string= "http://localhost:13000" (gethash "server" cfg)))
      (ok (string= "rcy_abc" (gethash "token" cfg))))
    (ok (uiop:directory-pathname-p (config-dir)))
    (let ((mode (sb-posix:stat-mode (sb-posix:stat (merge-pathnames "config.json" (config-dir))))))
      (ok (= #o600 (logand mode #o777)) "config file is private to the user"))))

(deftest resolve-server-precedence
  (let ((cfg (make-hash-table :test 'equal)))
    (setf (gethash "server" cfg) "http://cfg")
    (ok (string= "http://flag" (resolve-server "http://flag/" cfg)) "flag wins, trailing / dropped")
    (ok (string= "http://cfg" (resolve-server nil cfg)))
    (ok (null (resolve-server nil nil)))))

(deftest usage-errors-exit-2
  (with-temp-config-dir (dir)
    (ok (= 2 (main '())))
    (ok (= 2 (main '("frobnicate"))))
    (ok (= 2 (main '("list" "--bogus"))) "unknown option")
    (ok (= 2 (main '("list"))) "not logged in")
    (ok (= 2 (main '("run" "3"))) "not inside a pulled notebook")))

(deftest cli-does-not-load-server-systems
  (let ((seen (make-hash-table :test 'equal)))
    (labels ((walk (name)
               (unless (gethash name seen)
                 (setf (gethash name seen) t)
                 (let ((system (asdf:find-system name nil)))
                   (when system
                     (dolist (dep (asdf:system-depends-on system))
                       (when (stringp dep) (walk dep))))))))
      (walk "recurya/cli/main"))
    (loop for name being the hash-keys of seen
          do (ng (or (search "mito" name)
                     (search "recurya/db" name)
                     (search "recurya/web" name)
                     (string= "wardlisp" name))
                 (format nil "CLI must not depend on ~A" name)))))
```

asd / `tests/all.lisp` に `recurya/tests/cli/main` を追加。

- [ ] **Step 2: 失敗を確認** — package 不在の red。

- [ ] **Step 3: config を実装**

`fs-write-file` で `cli/config.lisp`:

```lisp
;;;; cli/config.lisp --- Where the CLI keeps its server URL and token.

(defpackage #:recurya/cli/config
  (:use #:cl)
  (:export #:config-dir
           #:load-config
           #:save-config
           #:resolve-server))

(in-package #:recurya/cli/config)

(defun config-dir ()
  "$RECURYA_CONFIG_DIR, else $XDG_CONFIG_HOME/recurya/, else ~/.config/recurya/."
  (let ((explicit (uiop:getenv "RECURYA_CONFIG_DIR"))
        (xdg (uiop:getenv "XDG_CONFIG_HOME")))
    (uiop:ensure-directory-pathname
     (cond ((and explicit (plusp (length explicit))) explicit)
           ((and xdg (plusp (length xdg))) (format nil "~A/recurya" xdg))
           (t (merge-pathnames ".config/recurya/" (user-homedir-pathname)))))))

(defun config-file ()
  (merge-pathnames "config.json" (config-dir)))

(defun load-config ()
  "The saved config object, or NIL when there is none or it is unreadable."
  (let ((file (config-file)))
    (when (probe-file file)
      (let ((data (ignore-errors (com.inuoe.jzon:parse (uiop:read-file-string file)))))
        (and (hash-table-p data) data)))))

(defun save-config (server token)
  "Save SERVER and TOKEN, readable by the user only (mode 600)."
  (let ((file (config-file))
        (data (make-hash-table :test 'equal)))
    (setf (gethash "server" data) server
          (gethash "token" data) token)
    (ensure-directories-exist file)
    (with-open-file (out file :direction :output :if-exists :supersede
                              :external-format :utf-8)
      (write-string (com.inuoe.jzon:stringify data :pretty t) out))
    (uiop:run-program (list "chmod" "600" (uiop:native-namestring file)))
    file))

(defun resolve-server (explicit config)
  "The server to talk to, without a trailing slash: EXPLICIT (--server), else
$RECURYA_SERVER, else CONFIG's \"server\"; NIL when none is set."
  (let ((value (or explicit
                   (let ((env (uiop:getenv "RECURYA_SERVER")))
                     (and env (plusp (length env)) env))
                   (and config (gethash "server" config)))))
    (and (stringp value) (string-right-trim "/" value))))
```

- [ ] **Step 4: client を実装**

`fs-write-file` で `cli/client.lisp`:

```lisp
;;;; cli/client.lisp --- HTTP calls to the Recurya JSON API.

(defpackage #:recurya/cli/client
  (:use #:cl)
  (:export #:api-error
           #:api-error-status
           #:api-error-code
           #:api-error-message
           #:request-failed
           #:request-failed-message
           #:fetch-me
           #:fetch-notebooks
           #:fetch-notebook
           #:post-cell-run))

(in-package #:recurya/cli/client)

(define-condition api-error (error)
  ((status :initarg :status :reader api-error-status)
   (code :initarg :code :reader api-error-code)
   (message :initarg :message :reader api-error-message))
  (:report (lambda (c stream)
             (format stream "~A (HTTP ~D)" (api-error-message c) (api-error-status c)))))

(define-condition request-failed (error)
  ((message :initarg :message :reader request-failed-message))
  (:report (lambda (c stream)
             (format stream "Request failed: ~A" (request-failed-message c)))))

(defun error-from-response (status body)
  "An API-ERROR built from an error response's STATUS and BODY text."
  (let* ((parsed (ignore-errors (com.inuoe.jzon:parse body)))
         (err (and (hash-table-p parsed) (gethash "error" parsed))))
    (make-condition 'api-error
                    :status status
                    :code (if (hash-table-p err) (gethash "code" err) "http_error")
                    :message (if (hash-table-p err)
                                 (gethash "message" err)
                                 (format nil "HTTP ~D" status)))))

(defun api-request (server token method path &key json)
  "Send METHOD PATH to SERVER with TOKEN (and JSON, a Lisp value to encode, as
the body); return the parsed JSON response.  Signals API-ERROR for an HTTP
error status and REQUEST-FAILED when no usable response arrives."
  (let ((headers `(("Authorization" . ,(format nil "Bearer ~A" token))
                   ("Accept" . "application/json")
                   ,@(when json '(("Content-Type" . "application/json"))))))
    (handler-case
        (com.inuoe.jzon:parse
         (dex:request (concatenate 'string server path)
                      :method method
                      :headers headers
                      :content (and json (com.inuoe.jzon:stringify json))
                      :force-string t))
      (dex:http-request-failed (e)
        (error (error-from-response (dex:response-status e)
                                    (let ((b (dex:response-body e)))
                                      (if (stringp b)
                                          b
                                          (babel:octets-to-string b :encoding :utf-8)))))))
      (api-error (e) (error e))
      (error (e)
        (error 'request-failed :message (princ-to-string e))))))

(defun fetch-me (server token)
  (api-request server token :get "/api/v1/me"))

(defun fetch-notebooks (server token page)
  (api-request server token :get (format nil "/api/v1/notebooks?page=~D" page)))

(defun fetch-notebook (server token handle slug)
  (api-request server token :get (format nil "/api/v1/notebooks/~A/~A" handle slug)))

(defun post-cell-run (server token handle slug index codes)
  (let ((body (make-hash-table :test 'equal)))
    (setf (gethash "codes" body) (coerce codes 'vector))
    (api-request server token :post
                 (format nil "/api/v1/notebooks/~A/~A/cells/~D/run" handle slug index)
                 :json body)))
```

- [ ] **Step 5: main を実装**

`fs-write-file` で `cli/main.lisp`:

```lisp
;;;; cli/main.lisp --- recurya command-line client: login, list, pull, run, status.

(defpackage #:recurya/cli/main
  (:use #:cl)
  (:import-from #:recurya/cli/config
                #:load-config
                #:save-config
                #:resolve-server)
  (:import-from #:recurya/cli/client
                #:api-error
                #:api-error-status
                #:api-error-message
                #:request-failed
                #:request-failed-message
                #:fetch-me
                #:fetch-notebooks
                #:fetch-notebook
                #:post-cell-run)
  (:import-from #:recurya/cli/workspace
                #:index-width
                #:render-readme
                #:plan-pull
                #:manifest-cells
                #:manifest-cell
                #:collect-codes
                #:resolve-cell-arg
                #:content-hash
                #:cell-file-name
                #:manifest->json
                #:json->manifest
                #:workspace-error
                #:workspace-error-message)
  (:import-from #:recurya/cli/report
                #:format-run-result
                #:result-exit-code
                #:format-notebook-list
                #:format-status)
  (:export #:main
           #:parse-args))

(in-package #:recurya/cli/main)

(define-condition usage-error (error)
  ((message :initarg :message :reader usage-error-message))
  (:report (lambda (c stream) (write-string (usage-error-message c) stream))))

(defun usage-error (control &rest args)
  (error 'usage-error :message (apply #'format nil control args)))

(defparameter *usage*
  "usage: recurya <command> [args]
  login [--server URL] [--token TOKEN]   save a token issued on /account
  list [--page N]                        list notebooks
  pull @handle/slug [DIR] [--force]      fetch a notebook into DIR (default: slug)
  run NN                                 run cell NN of the notebook in this directory
  status                                 show passed cells and local edits")

(defparameter *options*
  '(("--server" :server t) ("--token" :token t) ("--page" :page t) ("--force" :force nil))
  "Known options: (FLAG KEY TAKES-VALUE-P).")

(defun parse-args (argv)
  "Split ARGV into (VALUES COMMAND POSITIONAL OPTIONS); OPTIONS is a plist
keyed by keywords (--page 2 => :PAGE \"2\", --force => :FORCE T)."
  (let ((command (first argv))
        (positional '())
        (options '()))
    (loop with rest = (rest argv)
          while rest
          do (let ((arg (pop rest)))
               (let ((spec (assoc arg *options* :test #'string=)))
                 (cond
                   ((and spec (third spec))
                    (unless rest (usage-error "~A needs a value" arg))
                    (setf (getf options (second spec)) (pop rest)))
                   (spec (setf (getf options (second spec)) t))
                   ((and (> (length arg) 2) (string= "--" arg :end2 2))
                    (usage-error "Unknown option ~A" arg))
                   (t (push arg positional))))))
    (values command (nreverse positional) options)))

(defun credentials (options)
  "(VALUES SERVER TOKEN) from OPTIONS and the saved config; usage error when
not logged in."
  (let* ((config (load-config))
         (server (resolve-server (getf options :server) config))
         (token (and config (gethash "token" config))))
    (unless (and server token)
      (usage-error "Not logged in. Run: recurya login --server URL"))
    (values server token)))

(defun workspace-file (name)
  (merge-pathnames name (uiop:getcwd)))

(defun read-text (path)
  (and (probe-file path) (uiop:read-file-string path :external-format :utf-8)))

(defun write-text (path content)
  (ensure-directories-exist path)
  (with-open-file (out path :direction :output :if-exists :supersede
                            :external-format :utf-8)
    (write-string content out)))

(defun manifest-path (dir)
  (merge-pathnames ".recurya/notebook.json" dir))

(defun load-workspace ()
  "The manifest of the notebook pulled into the current directory."
  (let ((text (read-text (manifest-path (uiop:getcwd)))))
    (unless text
      (usage-error "No pulled notebook here (.recurya/notebook.json is missing). Run recurya pull first."))
    (json->manifest text)))

(defun parse-notebook-ref (ref)
  "@handle/slug (the @ is optional) => (VALUES HANDLE SLUG)."
  (let* ((s (string-left-trim "@" ref))
         (slash (position #\/ s)))
    (unless (and slash (plusp slash) (< (1+ slash) (length s)))
      (usage-error "Expected @handle/slug, got ~A" ref))
    (values (subseq s 0 slash) (subseq s (1+ slash)))))

;;; Commands

(defun cmd-login (options)
  (let* ((server (resolve-server (getf options :server) (load-config)))
         (token (or (getf options :token)
                    (progn (format *query-io* "Paste the token from ~A/account: "
                                   (or server "<server>"))
                           (force-output *query-io*)
                           (string-trim " " (read-line *query-io* nil ""))))))
    (unless server (usage-error "Give the server once: recurya login --server URL"))
    (let ((me (fetch-me server token)))
      (save-config server token)
      (format t "Logged in to ~A as @~A~%" server (gethash "handle" me))
      0)))

(defun cmd-list (options)
  (multiple-value-bind (server token) (credentials options)
    (let ((page (let ((p (getf options :page)))
                  (or (and p (parse-integer p :junk-allowed t)) 1))))
      (format-notebook-list (fetch-notebooks server token page) *standard-output*)
      0)))

(defun apply-pull (notebook server dir force)
  "Write NOTEBOOK into DIR per PLAN-PULL and report kept files."
  (let* ((width (index-width (length (gethash "cells" notebook))))
         (old (let ((text (read-text (manifest-path dir))))
                (and text (json->manifest text))))
         (existing (loop for cell across (gethash "cells" notebook)
                         for file = (cell-file-name (gethash "index" cell)
                                                    (gethash "kind" cell) width)
                         for content = (and file (read-text (merge-pathnames file dir)))
                         when content collect (cons file content))))
    (multiple-value-bind (actions manifest) (plan-pull notebook width old existing force)
      (setf (gethash "server" manifest) server)
      (write-text (merge-pathnames "README.md" dir) (render-readme notebook width))
      (dolist (action actions)
        (destructuring-bind (op file &optional content) action
          (if (eq op :write)
              (write-text (merge-pathnames file dir) content)
              (format t "kept (edited locally): ~A~%" file))))
      (write-text (manifest-path dir) (manifest->json manifest))
      (format t "Pulled @~A/~A into ~A~%" (gethash "handle" notebook)
              (gethash "slug" notebook) (uiop:native-namestring dir))
      0)))

(defun cmd-pull (positional options)
  (unless positional (usage-error "pull needs @handle/slug"))
  (multiple-value-bind (server token) (credentials options)
    (multiple-value-bind (handle slug) (parse-notebook-ref (first positional))
      (let ((dir (uiop:ensure-directory-pathname
                  (merge-pathnames (or (second positional) slug) (uiop:getcwd)))))
        (apply-pull (fetch-notebook server token handle slug) server dir
                    (getf options :force))))))

(defun cmd-run (positional options)
  (unless positional (usage-error "run needs a cell number, e.g. recurya run 03"))
  (let* ((manifest (load-workspace))
         (index (resolve-cell-arg (first positional) manifest))
         (width (gethash "width" manifest))
         (codes (collect-codes manifest index
                               (lambda (file) (read-text (workspace-file file))))))
    (multiple-value-bind (default-server token) (credentials options)
      (let* ((server (or (getf options :server) (gethash "server" manifest) default-server))
             (result (post-cell-run server token (gethash "handle" manifest)
                                    (gethash "slug" manifest) index codes)))
        (format-run-result result width *standard-output*)
        (when (string= (gethash "status" result) "pass")
          (setf (gethash "passed" (manifest-cell manifest index)) t))
        (when (plusp (length (gethash "revealed_solutions" result)))
          ;; Refresh files, README and manifest so the unlocked solution lands.
          (apply-pull (fetch-notebook server token (gethash "handle" manifest)
                                      (gethash "slug" manifest))
                      server (uiop:getcwd) nil))
        (unless (plusp (length (gethash "revealed_solutions" result)))
          (write-text (manifest-path (uiop:getcwd)) (manifest->json manifest)))
        (result-exit-code result)))))

(defun cmd-status ()
  (let* ((manifest (load-workspace))
         (modified (loop for cell in (manifest-cells manifest)
                         for file = (gethash "file" cell)
                         for content = (and (stringp file) (read-text (workspace-file file)))
                         when (and content
                                   (not (equal (content-hash content) (gethash "hash" cell))))
                           collect file)))
    (format-status manifest modified *standard-output*)
    0))

(defun main (argv)
  "Run the CLI on ARGV (a list of strings); return the exit code: 0 success,
1 a run that failed or errored, 2 a usage, auth or connection problem."
  (handler-case
      (multiple-value-bind (command positional options) (parse-args argv)
        (cond
          ((null command) (usage-error "~A" *usage*))
          ((string= command "login") (cmd-login options))
          ((string= command "list") (cmd-list options))
          ((string= command "pull") (cmd-pull positional options))
          ((string= command "run") (cmd-run positional options))
          ((string= command "status") (cmd-status))
          (t (usage-error "Unknown command ~A~%~A" command *usage*))))
    (usage-error (e) (format *error-output* "~A~%" (usage-error-message e)) 2)
    (workspace-error (e) (format *error-output* "~A~%" (workspace-error-message e)) 2)
    (api-error (e)
      (if (eql (api-error-status e) 401)
          (format *error-output* "Not authorized: ~A~%Run: recurya login~%" (api-error-message e))
          (format *error-output* "Server said: ~A~%" (api-error-message e)))
      2)
    (request-failed (e) (format *error-output* "~A~%" (request-failed-message e)) 2)))
```

- [ ] **Step 6: Roswell スクリプト**

`fs-write-file` で `roswell/recurya.ros`:

```lisp
#!/bin/sh
#|-*- mode:lisp -*-|#
#|
exec ros -Q -- $0 "$@"
|#
(progn
  (ros:ensure-asdf)
  ;; Load the CLI from the checkout this script lives in (roswell/ is at the
  ;; repository root).  The recurya/cli/* subsystems pull in only dexador,
  ;; jzon, ironclad, babel and uiop, never the server.
  (asdf:load-asd (merge-pathnames "../recurya.asd"
                                  (make-pathname :name nil :type nil
                                                 :defaults *load-pathname*)))
  #+quicklisp (ql:quickload :recurya/cli/main :silent t)
  #-quicklisp (asdf:load-system :recurya/cli/main))

(defpackage :ros.script.recurya
  (:use :cl))
(in-package :ros.script.recurya)

(defun main (&rest argv)
  (uiop:quit (uiop:symbol-call :recurya/cli/main :main argv)))
;;; vim: set ft=lisp lisp:
```

```bash
chmod +x roswell/recurya.ros
```

- [ ] **Step 7: テストを通す**

`run-tests` で `recurya/tests/cli/main` → PASS (`cli-does-not-load-server-systems` を含む)。

- [ ] **Step 8: Commit**

```bash
git add cli/config.lisp cli/client.lisp cli/main.lisp roswell/recurya.ros \
  tests/cli/main.lisp tests/all.lisp recurya.asd
git commit -m "feat(cli): recurya login/list/pull/run/status commands and roswell entry"
```

---

### Task 9: E2E・ドキュメント・仕上げ

**Files:**
- Create: `scripts/cli-e2e.sh`, `docs/CLI.md`
- Modify: `docs/DEVELOPMENT.md`, `README.md`, `.gitignore` (`roswell/recurya` バイナリ)、必要なら `docs/feedback/cl-mcp-cl-spec.md`

- [ ] **Step 1: E2E スクリプトを書く**

`scripts/cli-e2e.sh` (request-test.sh のプリミティブを再利用):

```bash
#!/usr/bin/env bash
# scripts/cli-e2e.sh --- End-to-end check of the recurya CLI against the dev server.
#
# Logs in through the dev OAuth stub, issues an API token on /account, creates
# a private draft notebook with a gated solution, then drives the CLI:
# login -> pull -> run (fail) -> edit -> run (pass, solution unlocked) ->
# status, and finally checks the browser page shows the unlocked solution.
# Needs the dev server (OAUTH_DEV_STUB on) and a stub user with a real handle.
set -uo pipefail
cd "$(dirname "$0")/.."
source scripts/request-test.sh >/dev/null   # rt_* primitives; ignore its own checks
PASS=0; FAIL=0
ROOT="$(pwd)"
qlot exec ros build roswell/recurya.ros >/dev/null 2>&1 \
  && _ok "built roswell/recurya" || { _bad "built roswell/recurya"; exit 1; }
CLI=("$ROOT/roswell/recurya")   # a binary, so it runs from any directory
WORK="$(mktemp -d)"; export RECURYA_CONFIG_DIR="$WORK/config"
trap 'rm -rf "$WORK" "$CJ" "$BODY"' EXIT
SLUG="cli-e2e-$(date +%s)"

echo "== setup: token and notebook =="
rt_reset_session; rt_login
rt_get /account >/dev/null
rt_hx_post /account/tokens 'name=cli-e2e' >/dev/null
TOKEN="$(grep -oE 'rcy_[0-9a-f]{64}' "$BODY" | head -1)"
[ -n "$TOKEN" ] && _ok "issued a token" || { _bad "issued a token"; exit 1; }
HANDLE="$(curl -s -H "Authorization: Bearer $TOKEN" "$BASE/api/v1/me" \
          | grep -oE '"handle":"[^"]+"' | cut -d'"' -f4)"
case "$HANDLE" in u-*|"") _bad "stub user has a real handle (got '$HANDLE')"; exit 1;; esac
rt_get /dashboard/notebooks/new >/dev/null
BODY_MD=$'===prose===\nCLI e2e\n\n===exercise: q===\n; replace with 3\n\n===expect===\n3\n\n===solution-locked: ans===\n(SECRET-ANSWER)'
rt_hx_post /dashboard/notebooks "title=CLI e2e" "slug=$SLUG" "summary=" \
  "body=$BODY_MD" "status=draft" "visibility=private" >/dev/null
code=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOKEN" \
       "$BASE/api/v1/notebooks/$HANDLE/$SLUG")
rt_status 200 "$code" "owner can read the draft through the API"

echo "== CLI flow =="
cd "$WORK"
"${CLI[@]}" login --server "$BASE" --token "$TOKEN" && _ok "login" || _bad "login"
"${CLI[@]}" pull "@$HANDLE/$SLUG" nb && _ok "pull" || _bad "pull"
[ -f nb/01-exercise.wl ] && _ok "exercise file written" || _bad "exercise file written"
[ ! -f nb/02-solution.wl ] && _ok "locked solution not written" || _bad "locked solution not written"
grep -q "locked" nb/README.md && _ok "README marks the locked solution" || _bad "README marks the locked solution"
cd nb
"${CLI[@]}" run 01; [ $? -eq 1 ] && _ok "unedited exercise fails (exit 1)" || _bad "unedited exercise fails (exit 1)"
echo "3" > 01-exercise.wl
"${CLI[@]}" run 01; [ $? -eq 0 ] && _ok "edited exercise passes (exit 0)" || _bad "edited exercise passes (exit 0)"
grep -q "SECRET-ANSWER" 02-solution.wl && _ok "solution file unlocked" || _bad "solution file unlocked"
"${CLI[@]}" status | grep -q "passed" && _ok "status shows passed" || _bad "status shows passed"
cd - >/dev/null

echo "== browser side =="
rt_status 200 "$(rt_get "/@$HANDLE/$SLUG")" "notebook page renders for the owner"
rt_contains "SECRET-ANSWER" "page shows the solution unlocked by the CLI run"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
```

```bash
chmod +x scripts/cli-e2e.sh
echo "/roswell/recurya" >> .gitignore
```

`request-test.sh` を `source` すると末尾のチェック群まで走る場合は、`request-test.sh` 側に `[[ "${BASH_SOURCE[0]}" != "$0" ]] && return 0` をプリミティブ定義の直後に入れて、source 時はプリミティブ定義だけで戻るようにする (既存の `./scripts/request-test.sh` 実行は不変)。

- [ ] **Step 2: E2E を実行**

`load-system recurya` (ホットリロード) 後に `./scripts/cli-e2e.sh` → 全 PASS。失敗したら原因 (サーバ / CLI / スクリプト) を切り分けて該当タスクのコードを直し、そのタスクのテストを再実行してから E2E を再実行する。作成された draft ノートブックとトークンは dev データとして残る (スクリプトの出力に slug を表示済み)。

- [ ] **Step 3: ドキュメント**

`docs/CLI.md` (新規):

```markdown
# recurya CLI

ブラウザの代わりに端末とお好みのエディタでノートブックの演習を解くためのクライアント。
進捗 (保存コード・合格・解答の解放) は Web UI と共有される。

## 導入

前提: Roswell (`ros`)。

    git clone https://github.com/masatoi/recurya.git
    cd recurya
    ./roswell/recurya.ros                 # 使い方を表示。初回は依存 (dexador, jzon, ironclad, babel) を取得
    ros build roswell/recurya.ros         # 任意: roswell/recurya バイナリを作る

`roswell/recurya.ros` (またはビルドしたバイナリ) を PATH の通った場所にリンクする。

## ログイン

1. ブラウザで `<server>/account` を開き、「API tokens」でトークンを発行する (一度しか表示されない)。
2. `recurya login --server https://<server>` を実行してトークンを貼り付ける。
   設定は `~/.config/recurya/config.json` (パーミッション 600) に保存される。

## 使い方

    recurya list                      # ノートブック一覧
    recurya pull @alice/sicp-1-1-1    # ./sicp-1-1-1/ に展開
    cd sicp-1-1-1
    $EDITOR 03-exercise.wl
    recurya run 03                    # 実行・採点・保存。合格で解答ファイルが現れる
    recurya status                    # 合格状況とローカル編集

- `README.md` に本文・演習の説明・テストケースが並ぶ。
- `run NN` はセル 0..NN のコードファイルの内容をまとめて送る (ブラウザと同じ)。
- 再 `pull` は、前回の pull 以降に編集していないファイルだけを更新する。`--force` で上書き。
- 終了コード: 0 合格/成功、1 不合格/エラー、2 使い方・認証・通信の問題。

## API

CLI が使う `/api/v1/*` は `docs/superpowers/specs/2026-10-13-learner-cli-design.md` §3 を参照。
```

`docs/DEVELOPMENT.md`: 「Verifying UI changes without a browser」節の後に「JSON API / CLI」節を追加し、(1) `/api/*` は Bearer トークン専用で CSRF・onboarding 除外であること、(2) API ハンドラテストの書き方 (`with-api-request` で env に `:recurya.api-user`)、(3) `./scripts/cli-e2e.sh` の前提と使い方、(4) `api_token` 追加時の test DB への手動適用 (`psql -d recurya_test -f db/migrations/<ts>.up.sql`) を記す。
`README.md`: 機能一覧に「CLI クライアント (`docs/CLI.md`)」を 1 行追加。

- [ ] **Step 4: 全体検証**

- `load-system recurya` を `clear_fasls: true` で (警告ゼロを確認。※ memory: clear_fasls でイメージが壊れたら `pool-kill-worker reset` で回復して再ロード)。
- `run-tests {"system":"recurya/tests","timeout_seconds":900}` → 全 PASS (478 + 追加分、Failed 0)。
- `load-system recurya/specs/all` 後、`spec-check {"symbol":"recurya/db/api-tokens:issue-api-token","profile":"normal"}` と `spec-check {"function":"recurya/db/api-tokens:normalize-token-name","trials":100}` を seed なしで再実行 → passed。`verification_gaps` を記録。
- `mallet` を変更・新規ファイルに対して実行 (`mallet models/api-token.lisp db/api-tokens.lisp web/http.lisp web/api-auth.lisp web/notebook-service.lisp web/routes-api.lisp game/notebook-gating.lisp cli/*.lisp specs/db/api-tokens.lisp tests/db/api-tokens.lisp tests/web/api-*.lisp tests/web/account-tokens.lisp tests/game/notebook-gating.lisp tests/cli/*.lisp web/routes.lisp web/ui/account.lisp web/server.lisp web/auth.lisp db/users.lisp`) → 警告ゼロ。未使用 import は `--fix` を使わず `lisp-patch-form` で手で消す。
- `./scripts/request-test.sh` → 全 PASS。`./scripts/cli-e2e.sh` → 全 PASS。
- cl-mcp / cl-spec で摩擦があれば `docs/feedback/cl-mcp-cl-spec.md` の末尾に既定形式で追記。

- [ ] **Step 5: Commit**

```bash
git add scripts/cli-e2e.sh scripts/request-test.sh docs/CLI.md docs/DEVELOPMENT.md README.md .gitignore \
  docs/feedback/cl-mcp-cl-spec.md
git commit -m "docs(cli): usage guide, API/CLI dev notes and end-to-end script"
```

- [ ] **Step 6: 報告**

ユーザーへ: 変更概要、テスト件数 (前後)、spec-check の seed / digest / verification_gaps、E2E 結果、**`/account` のトークン欄の見た目確認 (CSS) の依頼**、未対応 (パズル・novel・レート制限・device flow・有効期限) と、本番適用時に `api_token` マイグレーションを `docs/DEPLOYMENT.md` §6 の手順で流す必要があること。
