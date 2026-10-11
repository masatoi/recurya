# cl-spec Remaining Tables (users / novel-state / learn-submission) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Contract the DB layer of `users`, `novel_state` and `learn_submission` with cl-spec, and fix the two bugs the design found: F-D1 (a placeholder-shaped handle can be chosen at onboarding) and F-D2 (novel flag values with symbols do not survive storage and injection; list values are refused at set-flag time).

**Architecture:** Same as sub-project C. New contract files under `specs/` (packages `recurya/specs/*`, never loaded by production). Every DB-touching contract is a `defproperty` whose body wraps each trial in `recurya/tests/support/db:with-test-db`, which touches only `recurya_test`. Pure functions get Function Specs. Generators return plans; rows are created inside the body. The existing harness `tests/specs/contracts.lisp` runs everything listed in its expected lists.

**Tech Stack:** SBCL, cl-spec (`cl-spec/main`, check-it backend), Rove, Mito, cl-dbi, PostgreSQL (`recurya_test`), jzon (via `recurya/utils/common`), wardlisp, cl-ppcre, package-inferred ASDF, cl-mcp tools.

Design: `docs/superpowers/specs/2026-10-11-cl-spec-db-rest-design.md`.

## Global Constraints

- Lisp files (`.lisp`/`.asd`) are read and edited ONLY with cl-mcp tools (`lisp-read-file`, `clgrep-search`, `lisp-edit-form`, `lisp-patch-form`, `fs-write-file` for brand-new files only, `lisp-check-parens`). Never Read/Edit/Write/grep/sed them. Call `fs-set-project-root` with `/home/wiz/recurya` first.
- Allowed shell commands: `git`, `mallet`. Run tests with the cl-mcp `run-tests` tool, never `ros`/`sbcl`. Markdown files are edited with the Edit tool.
- Do NOT use `load-system` with `clear_fasls: true` (`.qlot/` is inside the project; it breaks the worker). If the worker gets into a bad state: `pool-kill-worker` with `reset: true`, then `load-system` `cl-spec/check-it`.
- NEVER touch the application DB connection from `repl-eval` (the web server runs in the same worker; using the global connection hangs the worker). Any DB access in a contract or a probe goes through `recurya/tests/support/db:with-test-db`.
- Do NOT modify any `deftable` (models/*.lisp).
- Production `recurya` never depends on `recurya/specs/*`; contract files may import from `recurya/tests/support/db`.
- Oracles must not call the function under test or its helpers to compute expected values; expected values come from the design doc, docstrings, schema and Lisp-side models.
- Generators build fresh values every trial; DB rows are created inside the property body (inside `with-test-db`), never in a generator. Outcome-relevant randomness lives in generators (`with-test-db` rebinds `*random-state*`).
- `with-test-db` deletes only users whose email ends in `@example.com`: every user a contract creates must have such an email.
- Never weaken a contract to make it pass. If a contract fails unexpectedly, stop and report the counterexample.
- In a `defspec-function`, never name an `:args` parameter with a symbol imported from another package (cl-spec then cannot resolve `result`). Use local names (`value`, `directives`).
- cl-spec `member` specs compare with `eql`: never write a string domain as `(member "a" "b")`; use `(satisfies pred)` with a `defgenerator`.
- Style: 2-space indent, ≤100 columns, docstrings on every defun/defparameter/generator/condition, no `::` in files (use `:import-from`, including for internal symbols), no new runtime `eval`/`intern` except in `db/novel`, where reading flags back interns keywords for flag names (existing) and for symbol values (Task 4) — the design requires keywords there, and the scene evaluator already interns every wardlisp symbol it sees.
- Lint: `mallet <files>` must print `No problems found.` for every Lisp file you touch.
- Commit messages end with: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
- Branch: `feat/cl-spec-db-rest` (already checked out). Do not push.

---

### Task 1: Handles — move `placeholder-handle-p`, reserve the placeholder shape (F-D1)

**Files:**
- Modify: `utils/handle.lisp` (defpackage, new `placeholder-handle-p`, `reserved-handle-p`)
- Modify: `db/users.lisp` (defpackage: import `placeholder-handle-p` from `recurya/utils/handle`; delete its defun)
- Create: `specs/db/users.lisp`
- Modify: `specs/all.lisp`, `tests/specs/contracts.lisp`
- Test: `tests/utils/handle.lisp`, `tests/web/onboarding.lisp`

**Interfaces:**
- Produces: `recurya/utils/handle:placeholder-handle-p (handle) -> boolean` (the same symbol is still exported by `recurya/db/users`); `recurya/utils/handle:reserved-handle-p (s) -> boolean` now also true for the placeholder shape.
- Produces (in `specs/db/users.lisp`, used by Task 2): `random-hex (n) -> string`.

- [ ] **Step 1: Move `placeholder-handle-p` to `utils/handle` (behaviour-preserving)**

In `utils/handle.lisp`, add `#:placeholder-handle-p` to the `:export` list and insert before `reserved-handle-p` (`lisp-edit-form` `insert_before` on `defun reserved-handle-p`):

```lisp
(defun placeholder-handle-p (handle)
  "True if HANDLE is a Phase-5-style placeholder (u-<hex>) requiring onboarding.

The placeholder format is 'u-XXXXXXXX' where X is exactly 8 lowercase hex
digits, as produced by RECURYA/DB/USERS::%GENERATE-PLACEHOLDER-HANDLE.

Arguments:
  HANDLE - The handle string to test.

Returns:
  T if HANDLE matches the placeholder pattern; NIL otherwise."
  (and (stringp handle)
       (cl-ppcre:scan "\\Au-[a-f0-9]{8}\\z" handle)
       t))
```

In `db/users.lisp`: add `(:import-from #:recurya/utils/handle #:placeholder-handle-p)` to the defpackage (keep `#:placeholder-handle-p` in `:export`), and remove the `defun placeholder-handle-p` form with `lisp-edit-form` `operation: "delete"` (`form_type` `defun`, `form_name` `placeholder-handle-p`). It must go: once the symbol is imported, a defun left in db/users would redefine `recurya/utils/handle:placeholder-handle-p`.

The running worker still holds the old `recurya/db/users::placeholder-handle-p` symbol, so reloading would hit a package name conflict. Reset it: `pool-kill-worker` `{"reset": true}`, then `load-system` `cl-spec/check-it`, `load-system` `recurya`.

Run: `run-tests` `{"system":"recurya/tests/utils/handle"}`, `{"system":"recurya/tests/web/onboarding"}`, `{"system":"recurya/tests/specs/contracts"}` — all pass (nothing changed in behaviour).

- [ ] **Step 2: Write the handle contracts**

Create `specs/db/users.lisp` with `fs-write-file`, then `lisp-check-parens`:

```lisp
;;;; specs/db/users.lisp --- cl-spec contracts for user accounts and handles.
;;;;
;;;; Handle reservation (pure) and, inside WITH-TEST-DB (recurya_test only),
;;;; user creation and lookup, OAuth login resolution and partial updates.
;;;; Design doc: docs/superpowers/specs/2026-10-11-cl-spec-db-rest-design.md

(defpackage #:recurya/specs/db/users
  (:use #:cl)
  (:import-from #:cl-spec/main
                #:defspec
                #:defspec-function
                #:defproperty
                #:defgenerator)
  (:import-from #:cl-spec/src/backends/check-it)
  (:import-from #:recurya/specs/db/domain
                #:random-element)
  (:import-from #:recurya/utils/handle
                #:valid-handle-p
                #:reserved-handle-p
                #:placeholder-handle-p)
  (:import-from #:cl-ppcre
                #:scan))
(in-package #:recurya/specs/db/users)

(defparameter *reserved-words*
  '("notebooks" "courses" "c" "n" "dashboard" "account" "login" "logout"
    "auth" "onboarding" "api" "static" "admin" "assets" "learn" "wardlisp"
    "settings" "help" "about" "new" "edit" "search" "blog" "posts"
    "register" "signup" "signin" "user" "users" "me")
  "The reserved handles, copied from utils/handle.lisp so the oracle does not
read the implementation's table.")

(defparameter *placeholder-shape* "\\Au-[a-f0-9]{8}\\z"
  "The placeholder handle shape: u- and exactly 8 lower-case hex digits.")

(defun random-hex (n)
  "A string of N random lower-case hex digits."
  (let ((digits "0123456789abcdef"))
    (coerce (loop repeat n collect (char digits (random 16))) 'string)))

(defun random-case (string)
  "STRING with each character upper-cased at random."
  (map 'string (lambda (ch) (if (zerop (random 2)) (char-upcase ch) ch)) string))

(defgenerator handle-text ()
  "A value that may or may not be an acceptable handle: a reserved word or a
placeholder shape (either in mixed case), a near miss of the placeholder
shape, a plain handle, odd strings, or a non-string."
  (case (random 8)
    (0 (random-element *reserved-words*))
    (1 (random-case (random-element *reserved-words*)))
    (2 (format nil "u-~A" (random-hex 8)))
    (3 (random-case (format nil "u-~A" (random-hex 8))))
    (4 (random-element (vector (format nil "u-~A" (random-hex 7))
                               (format nil "u-~A" (random-hex 9))
                               (format nil "u_~A" (random-hex 8))
                               (format nil "u-~Ag" (random-hex 7))
                               (format nil "x-~A" (random-hex 8))
                               (format nil "u-~A~%" (random-hex 8)))))
    (5 (random-element (vector "alice" "bob-the-builder" "user123" "abc" "a1-b2")))
    (6 (random-element (vector "" "a" "-abc" "abc-" "ab cd" "λambda"
                               (make-string 65 :initial-element #\a))))
    (t (random-element (vector nil 42 :admin)))))

(defspec handle-text t (:generator handle-text))

(defun expected-reserved-p (value)
  "The design's rule: VALUE is a string whose lower-cased form is a reserved
word or has the placeholder shape."
  (and (stringp value)
       (let ((lower (string-downcase value)))
         (or (member lower *reserved-words* :test #'string=)
             (scan *placeholder-shape* lower)))
       t))

(defspec-function reserved-handle-p
  "True exactly for a string whose lower-cased form is a reserved word or has
the placeholder shape; NIL for everything else, non-strings included."
  (:args (value handle-text))
  (:cases
    (:reserved
      (:when (expected-reserved-p value))
      (:returns (member t)))
    (:free
      (:when (not (expected-reserved-p value)))
      (:returns null))))

(defproperty placeholder-handle-never-real ((value handle-text))
  "No value is both accepted by onboarding (VALID-HANDLE-P and not
RESERVED-HANDLE-P) and a placeholder (PLACEHOLDER-HANDLE-P), so a user can
never pick a handle that keeps them in onboarding."
  (:about valid-handle-p reserved-handle-p placeholder-handle-p)
  (:kind :invariant)
  (:trials (:smoke 50 :normal 300))
  (not (and (valid-handle-p value)
            (not (reserved-handle-p value))
            (placeholder-handle-p value))))
```

Register it: add `(:import-from #:recurya/specs/db/users)` to `specs/all.lisp`'s defpackage (after `recurya/specs/db/notebooks`). In `tests/specs/contracts.lisp`:
- `*expected-properties*`: add `("RECURYA/SPECS/DB/USERS" . "PLACEHOLDER-HANDLE-NEVER-REAL")`.
- `*expected-function-specs*`: replace `("RECURYA/DB/USERS" . "PLACEHOLDER-HANDLE-P")` with `("RECURYA/UTILS/HANDLE" . "PLACEHOLDER-HANDLE-P")` (its home package is now utils/handle) and add `("RECURYA/UTILS/HANDLE" . "RESERVED-HANDLE-P")`.

- [ ] **Step 3: Confirm red**

1. `load-system` `{"system":"recurya/specs/all"}`.
2. `spec-check` `{"function":"recurya/utils/handle:reserved-handle-p","trials":200}` — expect `failed` in case `:reserved` on a placeholder-shaped string (e.g. `"u-3fa9c01b"` returned NIL). Record status and seed.
3. `spec-check` `{"property":"recurya/specs/db/users::placeholder-handle-never-real","profile":"normal"}` — expect `failed` with a lower-case placeholder string. Record status and seed.
If either passes, stop and report.

- [ ] **Step 4: Fix `reserved-handle-p`**

`lisp-edit-form` `replace` on `defun reserved-handle-p`:

```lisp
(defun reserved-handle-p (s)
  "True if S may not be chosen as a handle: its lower-cased form is in the
reserved-handles list, or has the placeholder shape (PLACEHOLDER-HANDLE-P)
that marks a user who has not picked a handle yet.  The placeholder shape also
satisfies VALID-HANDLE-P, so without this a user could choose it and be sent
back to onboarding on every request."
  (and (stringp s)
       (let ((lower (string-downcase s)))
         (or (member lower *reserved-handles* :test #'string=)
             (placeholder-handle-p lower)))
       t))
```

In `placeholder-handle-p`'s docstring, after the first paragraph, add: `RESERVED-HANDLE-P refuses this shape, so a real handle never matches it.`

- [ ] **Step 5: Regression tests**

In `tests/utils/handle.lisp` add (read the file first; use `lisp-edit-form` `insert_after` on the last deftest):

```lisp
(deftest placeholder-shapes-are-reserved
  (testing "the onboarding placeholder shape cannot be chosen as a handle"
    (ok (recurya/utils/handle:reserved-handle-p "u-deadbeef"))
    (ok (recurya/utils/handle:reserved-handle-p "U-DEADBEEF"))
    (ng (recurya/utils/handle:reserved-handle-p "u-deadbee"))
    (ng (recurya/utils/handle:reserved-handle-p "u-deadbeef0"))))
```

In `tests/web/onboarding.lisp` insert after `onboarding-create-rejects-reserved`:

```lisp
(deftest onboarding-create-rejects-placeholder-shape
  (testing "POST /onboarding/handle rejects a handle shaped like a placeholder"
    (with-test-db
      (let* ((dao (create-test-user :handle "u-deadbeef"))
             (user (mk-user-plist dao)))
        (with-mock-session (make-session :user user)
          (let ((res (onboarding-handle-create-handler
                      '(("handle" . "u-12345678")))))
            (ok (= 400 (response-status res))
                "placeholder-shaped handle must be rejected")
            (ok (search "reserved" (first (response-body res)))
                "error must mention reserved"))
          (let ((fresh (get-user-by-id (getf user :id))))
            (ok (string= "u-deadbeef" (users-handle fresh))
                "placeholder-shaped handle must NOT be saved")))))))
```

- [ ] **Step 6: Verify green**

1. `load-system` `{"system":"recurya"}`; `load-system` `{"system":"recurya/specs/all"}`.
2. `spec-check` `{"function":"recurya/utils/handle:reserved-handle-p","trials":300}` — passed, both cases called.
3. `spec-check` `{"property":"recurya/specs/db/users::placeholder-handle-never-real","profile":"normal"}` — passed.
4. `spec-check` `{"function":"recurya/utils/handle:placeholder-handle-p","trials":200}` — passed (the Function Spec in specs/db/core still resolves).
5. `run-tests` `{"system":"recurya/tests/utils/handle"}`, `{"system":"recurya/tests/web/onboarding"}`, `{"system":"recurya/tests/specs/contracts"}` — all pass.

- [ ] **Step 7: Lint and commit**

```bash
mallet utils/handle.lisp db/users.lisp specs/db/users.lisp specs/all.lisp tests/specs/contracts.lisp tests/utils/handle.lisp tests/web/onboarding.lisp
git add utils/handle.lisp db/users.lisp specs/db/users.lisp specs/all.lisp tests/specs/contracts.lisp tests/utils/handle.lisp tests/web/onboarding.lisp
git commit -m "fix(handle): reserve the placeholder handle shape (F-D1); handle contracts

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Users DB contracts

**Files:**
- Modify: `specs/db/users.lisp` (defpackage imports; new forms appended)
- Modify: `tests/specs/contracts.lisp`

**Interfaces:**
- Consumes: `random-hex (n)` from Task 1 (same file); `recurya/specs/db/domain`: `random-element`, `random-db-text`, `id-string`.
- Produces: nothing used later.

- [ ] **Step 1: Imports**

Extend the defpackage of `specs/db/users.lisp`:
- `recurya/specs/db/domain`: add `#:random-db-text #:id-string`.
- add:

```lisp
  (:import-from #:recurya/tests/support/db
                #:with-test-db)
  (:import-from #:recurya/db/core
                #:execute-one)
  (:import-from #:recurya/db/users
                #:create-user!
                #:get-user-by-id
                #:get-user-by-email
                #:get-user-by-handle
                #:find-or-create-oauth-user
                #:update-user!
                #:users-id
                #:users-email
                #:users-handle
                #:users-display-name
                #:users-role
                #:users-password-hash
                #:users-password-salt
                #:users-language
                #:users-timezone
                #:users-provider
                #:users-provider-uid)
  (:import-from #:uuid
                #:make-v4-uuid)
```

- [ ] **Step 2: Append the three properties**

Append (`lisp-edit-form` `insert_after` the last form):

```lisp
;;; Create and look up

(defun example-user-count ()
  "The number of users rows WITH-TEST-DB owns (email ending in @example.com)."
  (second (execute-one "SELECT count(*) AS n FROM users WHERE email LIKE '%@example.com'")))

(defgenerator user-values ()
  "CREATE-USER! arguments for one user: a unique @example.com email, a real
handle, and a display name and password fields that may be NIL."
  (let ((tag (random-hex 8)))
    (list :email (format nil "user-~A@example.com" tag)
          :handle (format nil "user-~A" tag)
          :display-name (random-element (vector nil "" "Alice" "ラムダ λ" "say \"hi\""
                                                (random-db-text 255)))
          :role (random-element #("user" "admin"))
          :password-hash (random-element #(nil "hash"))
          :password-salt (random-element #(nil "salt")))))

(defspec user-values list (:generator user-values))

(defproperty user-create-get-roundtrip ((row-values user-values))
  "A user created with in-domain values is found by id, email and handle as
the same row with every column equal; a NIL display name becomes the email.
Unknown emails and handles, and an empty or NIL handle, find nothing."
  (:about create-user! get-user-by-id get-user-by-email get-user-by-handle)
  (:kind :roundtrip)
  (:trials (:smoke 20 :normal 100))
  (with-test-db
    (let* ((created (apply #'create-user! row-values))
           (id (id-string (users-id created))))
      (and (every (lambda (user)
                    (and user
                         (string= (id-string (users-id user)) id)
                         (equal (users-email user) (getf row-values :email))
                         (equal (users-handle user) (getf row-values :handle))
                         (equal (users-display-name user)
                                (or (getf row-values :display-name)
                                    (getf row-values :email)))
                         (equal (users-role user) (getf row-values :role))
                         (equal (users-password-hash user) (getf row-values :password-hash))
                         (equal (users-password-salt user) (getf row-values :password-salt))))
                  (list (get-user-by-id id)
                        (get-user-by-email (getf row-values :email))
                        (get-user-by-handle (getf row-values :handle))))
           (null (get-user-by-email "nobody@example.com"))
           (null (get-user-by-handle "nobody-here"))
           (null (get-user-by-handle ""))
           (null (get-user-by-handle nil))))))

;;; OAuth login resolution

(defparameter *oauth-providers* #("google" "github")
  "The OAuth providers; identity I is provider (floor I 3), uid (mod I 3).")

(defun oauth-email (index)
  "The email address with INDEX (0-2) used by the OAuth scenarios."
  (format nil "oauth-~D@example.com" index))

(defgenerator oauth-scenario ()
  "(IDENTITY-EMAILS EXISTING LOGINS): the email index (0-2) of each of the six
identities (provider x uid), fixed for the whole scenario; existing users as
(EMAIL-INDEX DISPLAY-NAME) for emails 0 and 1, each present with probability
1/2 and a display name of \"\" or \"Existing\"; and 1-8 logins as (IDENTITY
DISPLAY-NAME) with a display name that may be NIL."
  (list (loop repeat 6 collect (random 3))
        (loop for e below 2
              when (zerop (random 2))
                collect (list e (random-element #("" "Existing"))))
        (loop repeat (1+ (random 8))
              collect (list (random 6) (random-element (vector nil "Alice" "ラムダ"))))))

(defspec oauth-scenario list (:generator oauth-scenario))

(defproperty oauth-login-resolution ((scenario oauth-scenario))
  "Each OAuth login returns a user carrying that login's provider, uid and
email.  Logins with the same email resolve to the same user (an existing one
if there is one) and different emails to different users, so the users are
exactly one per email seen.  A new user gets a placeholder handle and the
login's display name (the email when NIL).  An existing user's display name
changes only when a login links a new identity to it by email (not when the
identity already linked logs in again), and only while it is empty."
  (:about find-or-create-oauth-user)
  (:kind :invariant)
  (:trials (:smoke 20 :normal 100))
  (destructuring-bind (identity-emails existing logins) scenario
    (with-test-db
      (let ((owners (make-hash-table))   ; email index -> user id string
            (names (make-hash-table))    ; email index -> expected display name
            (linked (make-hash-table)))  ; email index -> identity now linked
        (loop for (e name) in existing
              do (let ((user (create-user! :email (oauth-email e)
                                           :handle (format nil "existing-~D" e)
                                           :display-name name)))
                   (setf (gethash e owners) (id-string (users-id user))
                         (gethash e names) name)))
        (loop for (identity name) in logins
              always
              (let* ((e (nth identity identity-emails))
                     (provider (aref *oauth-providers* (floor identity 3)))
                     (uid (format nil "uid-~D" (mod identity 3)))
                     (email (oauth-email e))
                     (known (gethash e owners))
                     ;; The provider lookup finds the user only while this
                     ;; identity is the one linked to it; otherwise the login
                     ;; goes through the email merge (or creates the user).
                     (relinked (not (eql (gethash e linked) identity)))
                     (id (id-string (users-id (find-or-create-oauth-user
                                               :provider provider :provider-uid uid
                                               :email email :display-name name))))
                     (user (get-user-by-id id)))
                (if known
                    (when (and relinked name (equal (gethash e names) ""))
                      (setf (gethash e names) name))
                    (setf (gethash e owners) id
                          (gethash e names) (or name email)))
                (setf (gethash e linked) identity)
                (and user
                     (if known (string= id known) t)
                     (equal (users-provider user) provider)
                     (equal (users-provider-uid user) uid)
                     (equal (users-email user) email)
                     (equal (users-display-name user) (gethash e names))
                     (or known (and (scan *placeholder-shape* (users-handle user)) t))
                     (let ((ids (loop for v being the hash-values of owners collect v)))
                       (= (length (remove-duplicates ids :test #'string=))
                          (hash-table-count owners)
                          (example-user-count))))))))))

;;; Partial update

(defparameter *user-update-fields*
  '(:password-hash :password-salt :display-name :role :language :timezone)
  "UPDATE-USER! keyword arguments covered by USER-UPDATE-PARTIAL.")

(defparameter *user-column-defaults* '(:language "en" :timezone "UTC")
  "Column initforms (models/users.lisp) for the fields CREATE-USER! cannot set.")

(defun random-user-fields ()
  "A plist of in-domain values for every field in *USER-UPDATE-FIELDS*."
  (list :password-hash (format nil "hash-~A" (random-hex 6))
        :password-salt (format nil "salt-~A" (random-hex 6))
        :display-name (random-db-text 255)
        :role (random-element #("user" "admin"))
        :language (random-element #("en" "ja"))
        :timezone (random-element #("UTC" "Asia/Tokyo" "America/New_York"))))

(defgenerator user-update-plan ()
  "(BEFORE OTHER CHANGES): creation values for the target user and for a
bystander, and a random subset of *USER-UPDATE-FIELDS* with new values."
  (let ((after (random-user-fields)))
    (list (random-user-fields)
          (random-user-fields)
          (loop for field in *user-update-fields*
                when (zerop (random 2))
                  append (list field (getf after field))))))

(defspec user-update-plan list (:generator user-update-plan))

(defun create-plan-user (fields tag)
  "Create a user from FIELDS (CREATE-USER! takes all but language and
timezone) with an email and handle derived from TAG; return its id string."
  (id-string (users-id (create-user! :email (format nil "update-~A@example.com" tag)
                                     :handle (format nil "update-~A" tag)
                                     :password-hash (getf fields :password-hash)
                                     :password-salt (getf fields :password-salt)
                                     :display-name (getf fields :display-name)
                                     :role (getf fields :role)))))

(defun user-field (user field)
  "USER's value for the *USER-UPDATE-FIELDS* keyword FIELD."
  (ecase field
    (:password-hash (users-password-hash user))
    (:password-salt (users-password-salt user))
    (:display-name (users-display-name user))
    (:role (users-role user))
    (:language (users-language user))
    (:timezone (users-timezone user))))

(defun user-fields-hold-p (user before changes)
  "True when every field of USER equals its CHANGES value, else its creation
value from BEFORE (or the column default for language and timezone)."
  (and user
       (loop for field in *user-update-fields*
             always (equal (user-field user field)
                           (getf changes field
                                 (getf *user-column-defaults* field
                                       (getf before field)))))))

(defproperty user-update-partial ((plan user-update-plan))
  "UPDATE-USER! sets exactly the fields it is given and leaves the user's
other fields, and every other user, as they were; for an unknown id it returns
NIL and changes nothing."
  (:about update-user!)
  (:kind :invariant)
  (:trials (:smoke 20 :normal 100))
  (destructuring-bind (before other changes) plan
    (with-test-db
      (let* ((target (create-plan-user before "target"))
             (bystander (create-plan-user other "bystander"))
             (missing (apply #'update-user! (id-string (make-v4-uuid)) changes))
             (updated (apply #'update-user! target changes)))
        (and (null missing)
             updated
             (string= (id-string (users-id updated)) target)
             (user-fields-hold-p (get-user-by-id target) before changes)
             (user-fields-hold-p (get-user-by-id bystander) other nil))))))
```

Note the defaults lookup in `user-fields-hold-p`: `(getf *user-column-defaults* field (getf before field))` gives the default for `:language`/`:timezone` and the creation value for the rest, because CREATE-USER! never sets language or timezone.

Add to `*expected-properties*`: `("RECURYA/SPECS/DB/USERS" . "USER-CREATE-GET-ROUNDTRIP")`, `("RECURYA/SPECS/DB/USERS" . "OAUTH-LOGIN-RESOLUTION")`, `("RECURYA/SPECS/DB/USERS" . "USER-UPDATE-PARTIAL")`.

- [ ] **Step 3: Verify**

1. `load-system` `{"system":"recurya/specs/all"}`.
2. `spec-check` each with `profile` `normal`, `timeout_seconds` 180: `recurya/specs/db/users::user-create-get-roundtrip`, `recurya/specs/db/users::oauth-login-resolution`, `recurya/specs/db/users::user-update-partial` — expect passed (they hold on the current implementation). If one fails, stop and report the counterexample: decide with the controller whether it is an implementation bug or a contract error before changing anything.
3. `run-tests` `{"system":"recurya/tests/specs/contracts"}` — 3 passed.

- [ ] **Step 4: Lint and commit**

```bash
mallet specs/db/users.lisp tests/specs/contracts.lisp
git add specs/db/users.lisp tests/specs/contracts.lisp
git commit -m "feat(specs): user creation, OAuth resolution and partial update contracts

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: set-flag validation (F-D2, interpreter side)

**Files:**
- Modify: `game/novel/interpreter.lisp`
- Create: `specs/game/novel.lisp`
- Modify: `specs/all.lisp`, `tests/specs/contracts.lisp`
- Test: `tests/game/novel/interpreter.lisp`

**Interfaces:**
- Produces (production, `recurya/game/novel/interpreter`): condition `invalid-flag-error` (subclass of `error`, readers `invalid-flag-error-name`, `invalid-flag-error-value`); `flag-value-p (value) -> boolean`.
- Produces (`recurya/specs/game/novel`, exported, used by Task 4): `*flag-names*` (vector of keywords), `storable-flag-value-p (value)`, `random-flag-value ()`, `random-flags (min max) -> alist`, spec/generator `flag-value`.

- [ ] **Step 1: Write the contract file**

Create `specs/game/novel.lisp` (`fs-write-file`, then `lisp-check-parens`):

```lisp
;;;; specs/game/novel.lisp --- cl-spec contracts for novel flags (pure).
;;;;
;;;; The flag-value domain (values a novel flag can hold and carry to the next
;;;; scene) and the set-flag check in INTERPRET-DIRECTIVES.  Design doc:
;;;; docs/superpowers/specs/2026-10-11-cl-spec-db-rest-design.md

(defpackage #:recurya/specs/game/novel
  (:use #:cl)
  (:import-from #:cl-spec/main
                #:defspec
                #:defspec-function
                #:defgenerator)
  (:import-from #:cl-spec/src/backends/check-it)
  (:import-from #:recurya/specs/db/domain
                #:random-element)
  (:import-from #:recurya/game/novel/interpreter
                #:interpret-directives
                #:invalid-flag-error)
  (:export #:*flag-names*
           #:storable-flag-value-p
           #:random-flag-value
           #:random-flags
           #:flag-value))
(in-package #:recurya/specs/game/novel)

(defparameter *flag-names* #(:met-alice :mood :count :flag-a :flag-b :flag-c)
  "Flag names as the scene evaluator makes them: upper-case keywords from
wardlisp symbols.  None names a wardlisp builtin, so each can be bound.")

(defparameter *symbol-values* #(:happy :sad :sym-x :ready-for-exercise)
  "Symbol flag values (keywords), named unlike t and nil.")

(defparameter *flag-strings*
  (vector "" "hi" "ラムダ λ" "say \"hi\"" "back\\slash" (format nil "two~%lines") "HAPPY")
  "String flag values: empty, non-ASCII, quotes, backslash, newline, and one
spelled like a symbol value's stored name.")

(defun storable-flag-value-p (value)
  "The design's flag-value domain: T, NIL, an integer, a string or a keyword."
  (or (eq value t) (null value) (integerp value) (stringp value) (keywordp value)))

(defun random-flag-value ()
  "A value in the flag-value domain."
  (case (random 5)
    (0 t)
    (1 nil)
    (2 (- (random 2001) 1000))
    (3 (random-element *flag-strings*))
    (t (random-element *symbol-values*))))

(defgenerator flag-value ()
  "A value in the flag-value domain."
  (random-flag-value))

(defspec flag-value (satisfies storable-flag-value-p) (:generator flag-value))

(defun random-flags (min max)
  "An alist of MIN..MAX (at most 6) flags with distinct names from
*FLAG-NAMES* and values in the flag-value domain."
  (let ((names (coerce *flag-names* 'list)))
    (loop repeat (+ min (random (1+ (- max min))))
          collect (let ((name (random-element names)))
                    (setf names (remove name names))
                    (cons name (random-flag-value))))))

(defparameter *bad-flag-names* (vector "mood" 3 nil)
  "Set-flag names that are not keywords.")

(defparameter *bad-flag-values* (vector (list 1 2) (list :a "b") 1.5 (vector 1 2))
  "Set-flag values outside the flag-value domain.")

(defun random-set-flag ()
  "A set-flag directive: usually a keyword name with an omitted or storable
value; sometimes a non-keyword name or a value outside the domain."
  (let ((name (if (zerop (random 12))
                  (random-element *bad-flag-names*)
                  (random-element *flag-names*))))
    (case (random 10)
      ((0 1 2) (list :set-flag name))
      (3 (list :set-flag name (random-element *bad-flag-values*)))
      (t (list :set-flag name (random-flag-value))))))

(defun random-directive ()
  "A say, narrate, bg or set-flag directive."
  (case (random 6)
    (0 (list :say "アリス" (random-element *flag-strings*)))
    (1 (list :narrate "text"))
    (2 (list :bg "room"))
    (t (random-set-flag))))

(defgenerator directive-list ()
  "0-6 directives; a third of the time the tail is wrapped in a (:scene ...)
group."
  (let ((dirs (loop repeat (random 7) collect (random-directive))))
    (if (and dirs (zerop (random 3)))
        (let ((k (random (1+ (length dirs)))))
          (append (subseq dirs 0 k) (list (cons :scene (subseq dirs k)))))
        dirs)))

(defspec directive-list list (:generator directive-list))

(defun set-flag-forms (directives)
  "The set-flag directives of DIRECTIVES in order, looking inside :scene groups."
  (loop for d in directives
        append (case (first d)
                 (:scene (set-flag-forms (rest d)))
                 (:set-flag (list d)))))

(defun beat-count (directives)
  "The number of say and narrate directives in DIRECTIVES, :scene groups included."
  (loop for d in directives
        sum (case (first d)
              (:scene (beat-count (rest d)))
              ((:say :narrate) 1)
              (t 0))))

(defun valid-set-flag-p (directive)
  "True when DIRECTIVE, a set-flag, has a keyword name and an omitted or
storable value."
  (and (keywordp (second directive))
       (or (null (cddr directive))
           (storable-flag-value-p (third directive)))))

(defspec-function interpret-directives
  "Set-flags with a keyword name and an omitted or storable value are
collected in order as (NAME . VALUE), an omitted value as T, and every say and
narrate becomes a beat; any other set-flag signals INVALID-FLAG-ERROR."
  (:args (directives directive-list))
  (:cases
    (:valid
      (:when (every #'valid-set-flag-p (set-flag-forms directives)))
      (:returns (values list list))
      (:post-values (beats set-flags)
        (and (= (length beats) (beat-count directives))
             (equal set-flags
                    (mapcar (lambda (d) (cons (second d) (if (cddr d) (third d) t)))
                            (set-flag-forms directives))))))
    (:invalid
      (:when (notevery #'valid-set-flag-p (set-flag-forms directives)))
      (:signals (type invalid-flag-error)))))
```

Because `invalid-flag-error` does not exist yet, first add the condition and its exports to `game/novel/interpreter.lisp` WITHOUT the check (Step 2) so the contract compiles and runs red.

- [ ] **Step 2: Add the condition and predicate (no check yet)**

In `game/novel/interpreter.lisp`, extend the `:export` list with `#:flag-value-p #:invalid-flag-error #:invalid-flag-error-name #:invalid-flag-error-value`, and insert before `defun interpret-directives`:

```lisp
(define-condition invalid-flag-error (error)
  ((name :initarg :name :reader invalid-flag-error-name)
   (value :initarg :value :reader invalid-flag-error-value))
  (:report (lambda (condition stream)
             (format stream "set-flag needs a symbol name and a value that is t, nil, ~
                             an integer, a string or a symbol; got name ~S and value ~S"
                     (invalid-flag-error-name condition)
                     (invalid-flag-error-value condition))))
  (:documentation "Signalled by INTERPRET-DIRECTIVES for a set-flag whose name is
not a keyword or whose value cannot be stored and passed to the next scene
(a list, for example: wardlisp :bindings take no lists)."))

(defun flag-value-p (value)
  "True for a value a novel flag can hold: T, NIL, an integer, a string or a
keyword.  These survive storage in novel_state and injection into wardlisp."
  (or (eq value t) (null value) (integerp value) (stringp value) (keywordp value)))
```

Register: `(:import-from #:recurya/specs/game/novel)` in `specs/all.lisp` (after `recurya/specs/game/notebook-jsonb`). In `tests/specs/contracts.lisp`: `*expected-specs*` add `("RECURYA/SPECS/GAME/NOVEL" . "FLAG-VALUE")`; `*expected-function-specs*` add `("RECURYA/GAME/NOVEL/INTERPRETER" . "INTERPRET-DIRECTIVES")`.

- [ ] **Step 3: Confirm red**

`load-system` `recurya`, then `recurya/specs/all`. `spec-check` `{"function":"recurya/game/novel/interpreter:interpret-directives","trials":200}` — expect `failed` in case `:invalid` (a set-flag with a list or non-keyword name returned normally). Record status and seed. If it passes, stop and report.

- [ ] **Step 4: Add the check**

Replace the `(:set-flag ...)` clause of `interpret-directives` (`lisp-patch-form`):

```lisp
                     (:set-flag
                      (let ((name (second d))
                            (value (if (cddr d) (third d) t)))
                        (unless (and (keywordp name) (flag-value-p value))
                          (error 'invalid-flag-error :name name :value value))
                        (push (cons name value) set-flags)))
```

Add to its docstring: `Signals INVALID-FLAG-ERROR for a set-flag whose name is not a keyword or whose value is not FLAG-VALUE-P.`

- [ ] **Step 5: Regression test**

Append to `tests/game/novel/interpreter.lisp` (and add `#:invalid-flag-error` to its `:import-from`):

```lisp
(deftest set-flag-rejects-unstorable-flags
  (testing "a symbol value is collected"
    (multiple-value-bind (beats set-flags)
        (interpret-directives '((:set-flag :mood :happy)))
      (declare (ignore beats))
      (ok (equal set-flags '((:mood . :happy))))))
  (testing "a list value or a non-symbol name signals invalid-flag-error"
    (ok (signals (interpret-directives '((:set-flag :xs (1 2)))) 'invalid-flag-error))
    (ok (signals (interpret-directives '((:set-flag "mood" 1))) 'invalid-flag-error))))
```

- [ ] **Step 6: Verify green**

1. `load-system` `recurya`, then `recurya/specs/all`.
2. `spec-check` `{"function":"recurya/game/novel/interpreter:interpret-directives","trials":300}` — passed, both cases called.
3. `run-tests` `{"system":"recurya/tests/game/novel/interpreter"}`, `{"system":"recurya/tests/integration/novel-sample"}`, `{"system":"recurya/tests/integration/novel-recursion-lesson"}`, `{"system":"recurya/tests/specs/contracts"}` — all pass.

- [ ] **Step 7: Lint and commit**

```bash
mallet game/novel/interpreter.lisp specs/game/novel.lisp specs/all.lisp tests/specs/contracts.lisp tests/game/novel/interpreter.lisp
git add game/novel/interpreter.lisp specs/game/novel.lisp specs/all.lisp tests/specs/contracts.lisp tests/game/novel/interpreter.lisp
git commit -m "fix(novel): refuse set-flag values that cannot reach the next scene (F-D2)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Flag storage and injection, novel-state contracts (F-D2)

**Files:**
- Modify: `db/novel.lisp`
- Modify: `game/novel/eval.lisp` (`%flag->binding`)
- Create: `specs/db/novel.lisp`
- Modify: `specs/all.lisp`, `tests/specs/contracts.lisp`
- Test: `tests/db/novel.lisp`, `tests/game/novel/eval.lisp`

**Interfaces:**
- Consumes: `recurya/specs/game/novel`: `random-flags (min max)`; `recurya/specs/db/domain`: `fresh-user-id`, `set-equal-p`.
- Produces: internal `recurya/db/novel::%flags->json (flags) -> string` (imported by the contract file).

- [ ] **Step 1: Extract `%flags->json` (behaviour-preserving)**

In `db/novel.lisp`, replace `defun %alist->ht` with:

```lisp
(defun %flags->json (flags)
  "Serialize FLAGS, an alist (flag-keyword -> value), to the flags JSON object
stored in novel_state: keys are the lower-case flag names."
  (let ((h (make-hash-table :test 'equal)))
    (dolist (pair flags)
      (setf (gethash (string-downcase (symbol-name (car pair))) h) (cdr pair)))
    (json->string h)))
```

and in `upsert-novel-state` change `(flags-json (json->string (%alist->ht flags)))` to `(flags-json (%flags->json flags))`. `load-system` `recurya`; `run-tests` `{"system":"recurya/tests/db/novel"}` — passes.

- [ ] **Step 2: Write the contracts**

Create `specs/db/novel.lisp` (`fs-write-file`, then `lisp-check-parens`):

```lisp
;;;; specs/db/novel.lisp --- cl-spec contracts for per-reader novel state.
;;;;
;;;; Flags written to the novel_state JSON come back unchanged and, injected
;;;; into the next scene, equal their values (no database); upserts keep one
;;;; row per (reader, notebook) with the last flags and scene index given
;;;; (inside WITH-TEST-DB, recurya_test only).  Design doc:
;;;; docs/superpowers/specs/2026-10-11-cl-spec-db-rest-design.md

(defpackage #:recurya/specs/db/novel
  (:use #:cl)
  (:import-from #:cl-spec/main
                #:defspec
                #:defproperty
                #:defgenerator)
  (:import-from #:cl-spec/src/backends/check-it)
  (:import-from #:recurya/specs/db/domain
                #:fresh-user-id
                #:set-equal-p)
  (:import-from #:recurya/specs/game/novel
                #:random-flags)
  (:import-from #:recurya/tests/support/db
                #:with-test-db)
  (:import-from #:recurya/db/core
                #:execute-one)
  (:import-from #:recurya/db/novel
                #:get-novel-state
                #:upsert-novel-state
                #:novel-state-flags-alist
                ;; Internal helper under contract.
                #:%flags->json)
  (:import-from #:recurya/models/novel-state
                #:novel-state
                #:novel-state-scene-index)
  (:import-from #:recurya/game/novel/eval
                #:eval-scene))
(in-package #:recurya/specs/db/novel)

;;; Stored flags drive the next scene (no database)

(defgenerator stored-flags ()
  "1-4 flags with distinct names and values in the flag-value domain."
  (random-flags 1 4))

(defspec stored-flags list (:generator stored-flags))

(defun wardlisp-literal (value)
  "VALUE as a wardlisp literal: t, nil, a decimal integer, a string literal
with backslash and double quote escaped, or a quoted lower-case symbol."
  (cond ((eq value t) "t")
        ((null value) "nil")
        ((integerp value) (format nil "~D" value))
        ((stringp value)
         (with-output-to-string (out)
           (write-char #\" out)
           (loop for ch across value
                 do (when (member ch '(#\" #\\)) (write-char #\\ out))
                    (write-char ch out))
           (write-char #\" out)))
        (t (format nil "'~(~A~)" (symbol-name value)))))

(defun probe-scene (flags)
  "A scene that, for each flag, says yes when the injected flag is EQUAL? to
its value's literal and no otherwise; the speaker is the flag's name."
  (format nil "(list ~{~A~^ ~})"
          (loop for (name . value) in flags
                collect (format nil "(list 'say \"~(~A~)\" (if (equal? ~(~A~) ~A) \"yes\" \"no\"))"
                                (symbol-name name) (symbol-name name)
                                (wardlisp-literal value)))))

(defproperty persisted-flags-drive-next-scene ((flags stored-flags))
  "Flags written as the novel_state JSON and read back are the same flags, and
injected into a scene each one is EQUAL? to its value's literal: a flag set in
one scene drives the branches of the next.  No database access."
  (:about novel-state-flags-alist eval-scene)
  (:kind :roundtrip)
  (:trials (:smoke 30 :normal 200))
  (let ((read-back (novel-state-flags-alist
                    (make-instance 'novel-state :flags (%flags->json flags)))))
    (and (set-equal-p read-back flags)
         (= (length read-back) (length flags))
         (equal (eval-scene (probe-scene read-back))
                (loop for (name) in read-back
                      collect (list :say (string-downcase (symbol-name name)) "yes"))))))

;;; Round trip through the table

(defgenerator novel-state-plan ()
  "(FLAGS SCENE-INDEX): 0-5 flags and a scene index 0-20."
  (list (random-flags 0 5) (random 21)))

(defspec novel-state-plan list (:generator novel-state-plan))

(defproperty novel-state-roundtrip ((plan novel-state-plan))
  "A reader's first upsert reads back with the same scene index and flags."
  (:about upsert-novel-state get-novel-state novel-state-flags-alist)
  (:kind :roundtrip)
  (:trials (:smoke 20 :normal 100))
  (destructuring-bind (flags scene-index) plan
    (with-test-db
      (let ((user (fresh-user-id)))
        (upsert-novel-state user "nb-0" :flags flags :scene-index scene-index)
        (let ((row (get-novel-state user "nb-0")))
          (and row
               (= (novel-state-scene-index row) scene-index)
               (set-equal-p (novel-state-flags-alist row) flags)
               (= (length (novel-state-flags-alist row)) (length flags))))))))

;;; Upsert sequences

(defgenerator novel-upsert-ops ()
  "1-8 upserts (USER NOTEBOOK FLAGS SCENE-INDEX): USER and NOTEBOOK are indices
0-1, FLAGS is NIL (keep) or 1-3 flags, SCENE-INDEX is NIL (keep) or 0-20."
  (loop repeat (1+ (random 8))
        collect (list (random 2) (random 2)
                      (if (zerop (random 3)) nil (random-flags 1 3))
                      (if (zerop (random 3)) nil (random 21)))))

(defspec novel-upsert-ops list (:generator novel-upsert-ops))

(defun last-given (ops u n key)
  "The last non-NIL value at KEY (2 = flags, 3 = scene index) among OPS for
user U and notebook N, or NIL."
  (let ((found nil))
    (loop for op in ops
          when (and (= (first op) u) (= (second op) n) (nth key op))
            do (setf found (nth key op)))
    found))

(defproperty novel-state-upsert-sequence ((ops novel-upsert-ops))
  "After a sequence of upserts each (reader, notebook) that was upserted has
exactly one row, whose flags are the last non-NIL flags given (none if never
given) and whose scene index is the last non-NIL index given (0 if never)."
  (:about upsert-novel-state get-novel-state)
  (:kind :invariant)
  (:trials (:smoke 20 :normal 100))
  (with-test-db
    (let ((users (vector (fresh-user-id) (fresh-user-id)))
          (notebooks #("nb-0" "nb-1")))
      (loop for (u n flags scene-index) in ops
            do (upsert-novel-state (aref users u) (aref notebooks n)
                                   :flags flags :scene-index scene-index))
      (and (= (second (execute-one "SELECT count(*) AS n FROM novel_state"))
              (length (remove-duplicates (mapcar (lambda (op) (list (first op) (second op)))
                                                 ops)
                                         :test #'equal)))
           (loop for u below 2
                 always (loop for n below 2
                              always (let ((row (get-novel-state (aref users u)
                                                                 (aref notebooks n)))
                                           (touched (find-if (lambda (op)
                                                               (and (= (first op) u)
                                                                    (= (second op) n)))
                                                             ops)))
                                       (if touched
                                           (and row
                                                (set-equal-p (novel-state-flags-alist row)
                                                             (last-given ops u n 2))
                                                (= (novel-state-scene-index row)
                                                   (or (last-given ops u n 3) 0)))
                                           (null row)))))))))
```

Register: `(:import-from #:recurya/specs/db/novel)` in `specs/all.lisp` (after `recurya/specs/db/users`). Add to `*expected-properties*`: `("RECURYA/SPECS/DB/NOVEL" . "PERSISTED-FLAGS-DRIVE-NEXT-SCENE")`, `("RECURYA/SPECS/DB/NOVEL" . "NOVEL-STATE-ROUNDTRIP")`, `("RECURYA/SPECS/DB/NOVEL" . "NOVEL-STATE-UPSERT-SEQUENCE")`.

- [ ] **Step 3: Confirm red**

`load-system` `recurya/specs/all`. With `profile` `normal`, `timeout_seconds` 180:
- `spec-check` `{"property":"recurya/specs/db/novel::persisted-flags-drive-next-scene",...}` — expect `failed` (a symbol value read back as an upper-case string, e.g. `:happy` → `"HAPPY"`). Record status and seed.
- `spec-check` `{"property":"recurya/specs/db/novel::novel-state-roundtrip",...}` — expect `failed` for the same reason. Record.
- `spec-check` `{"property":"recurya/specs/db/novel::novel-state-upsert-sequence",...}` — record the status (it also compares flags, so it is expected to fail too).
If the first two pass, stop and report.

- [ ] **Step 4: Fix storage and injection**

In `db/novel.lisp`, insert before `%flags->json`:

```lisp
(defun %flag-value->json (value)
  "VALUE as stored in the flags JSON: a keyword as {\"symbol\": <lower-case
name>}; T, NIL, integers and strings as themselves (true, false, numbers,
strings)."
  (if (keywordp value)
      (let ((h (make-hash-table :test 'equal)))
        (setf (gethash "symbol" h) (string-downcase (symbol-name value)))
        h)
      value))

(defun %json->flag-value (json)
  "Read one stored flag value.  Returns (VALUES VALUE T) for true, false, an
integer, a string, or a {\"symbol\": name} object (a keyword); (VALUES NIL NIL)
for anything else (arrays, floats, null, other objects), which the reader
drops."
  (cond ((eq json t) (values t t))
        ((null json) (values nil t))
        ((integerp json) (values json t))
        ((stringp json) (values json t))
        ((and (hash-table-p json)
              (= (hash-table-count json) 1)
              (stringp (gethash "symbol" json)))
         (values (intern (string-upcase (gethash "symbol" json)) :keyword) t))
        (t (values nil nil))))
```

In `%flags->json`, store `(%flag-value->json (cdr pair))` instead of `(cdr pair)` and extend its docstring: `Values are written by %FLAG-VALUE->JSON.`

Replace `novel-state-flags-alist`:

```lisp
(defun novel-state-flags-alist (row)
  "Parse ROW's flags JSON back to an alist (flag-keyword -> value).  Values
come back as %FLAGS->JSON wrote them: T, NIL, integers, strings and keywords.
A stored value of any other shape (an array written before symbol values were
tagged, a float, null) is dropped with its flag.  NIL when the column does not
hold a JSON object."
  (let ((ht (parse-json (novel-state-flags row))))
    (when (hash-table-p ht)
      (loop for k being the hash-keys of ht using (hash-value v)
            for (value ok) = (multiple-value-list (%json->flag-value v))
            when ok
              collect (cons (intern (string-upcase k) :keyword) value)))))
```

Update `upsert-novel-state`'s docstring: `FLAGS is an alist (flag-keyword -> T, NIL, integer, string or keyword) stored as JSON by %FLAGS->JSON; a NIL FLAGS or SCENE-INDEX leaves an existing row's value unchanged.`

In `game/novel/eval.lisp`, replace `%flag->binding`:

```lisp
(defun %flag->binding (pair)
  "Convert a flag (keyword . value) to a wardlisp :bindings entry (name . value).
The keyword becomes a downcased symbol name.  A CL string value is boxed into a
wardlisp string and a keyword value becomes a wardlisp symbol (its downcased
name); T, NIL and integers pass through."
  (let ((name (string-downcase (symbol-name (car pair))))
        (value (cdr pair)))
    (cons name (cond ((stringp value) (make-string-value value))
                     ((keywordp value) (string-downcase (symbol-name value)))
                     (t value)))))
```

- [ ] **Step 5: Regression tests**

Append to `tests/db/novel.lisp`:

```lisp
(deftest symbol-flag-values-roundtrip
  (with-test-db
    (let ((uid (users-id (create-test-user))))
      (upsert-novel-state uid "nb-sym" :flags '((:mood . :happy) (:name . "HAPPY")))
      (let ((fl (novel-state-flags-alist (get-novel-state uid "nb-sym"))))
        (ok (eq :happy (cdr (assoc :mood fl))) "a symbol value comes back as a keyword")
        (ok (equal "HAPPY" (cdr (assoc :name fl))) "a string value stays a string")))))

(deftest unreadable-flag-values-are-dropped
  (with-test-db
    (let ((uid (users-id (create-test-user))))
      (upsert-novel-state uid "nb-old" :flags '((:ok . t)))
      (execute! "UPDATE novel_state SET flags = $1 WHERE notebook_id = $2"
                "{\"xs\":[1,2],\"ok\":true,\"f\":1.5}" "nb-old")
      (ok (equal '((:ok . t))
                 (novel-state-flags-alist (get-novel-state uid "nb-old")))
          "arrays and floats from old rows are dropped"))))
```

Add `(:import-from #:recurya/db/core #:execute!)` to the test file's defpackage.

Append to `tests/game/novel/eval.lisp`:

```lisp
(deftest keyword-flag-value-binds-as-symbol
  (let ((dirs (eval-scene "(list (list 'say \"a\" (if (equal? mood 'happy) \"yes\" \"no\")))"
                          :flags '((:mood . :happy)))))
    (ok (equal dirs '((:say "a" "yes"))))))
```

- [ ] **Step 6: Verify green**

1. `load-system` `recurya`, then `recurya/specs/all`.
2. Re-run each Step 3 check with its recorded seed (copy the `Replay:` line) — passed; then each again without a seed at `normal` — passed.
3. `run-tests` `{"system":"recurya/tests/db/novel"}`, `{"system":"recurya/tests/game/novel/eval"}`, `{"system":"recurya/tests/web/novel-routes"}`, `{"system":"recurya/tests/integration/novel-sample"}`, `{"system":"recurya/tests/specs/contracts"}` — all pass.

- [ ] **Step 7: Lint and commit**

```bash
mallet db/novel.lisp game/novel/eval.lisp specs/db/novel.lisp specs/all.lisp tests/specs/contracts.lisp tests/db/novel.lisp tests/game/novel/eval.lisp
git add db/novel.lisp game/novel/eval.lisp specs/db/novel.lisp specs/all.lisp tests/specs/contracts.lisp tests/db/novel.lisp tests/game/novel/eval.lisp
git commit -m "fix(novel): symbol flag values survive storage and reach the next scene (F-D2)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Submission history contract

**Files:**
- Modify: `specs/db/domain.lisp` (submission-status domain)
- Modify: `specs/db/learn.lisp`
- Modify: `tests/specs/contracts.lisp`

**Interfaces:**
- Produces (exported from `recurya/specs/db/domain`): `*submission-statuses*`, `submission-status-p`, spec/generator `submission-status`.

- [ ] **Step 1: Domain**

In `specs/db/domain.lisp` export `#:*submission-statuses* #:submission-status #:submission-status-p`, and append:

```lisp
(defparameter *submission-statuses* '("pass" "fail" "error")
  "Exercise submission statuses: RUN-EXERCISE-CELL's :pass, :fail and :error,
lower-cased by %MAYBE-PERSIST-NOTEBOOK-CELL-RUN (web/routes.lisp).")

(defun submission-status-p (value)
  "True when VALUE is one of *SUBMISSION-STATUSES*."
  (and (stringp value) (member value *submission-statuses* :test #'string=) t))

(defgenerator submission-status ()
  "One of *SUBMISSION-STATUSES*."
  (random-element *submission-statuses*))

(defspec submission-status (satisfies submission-status-p)
  (:generator submission-status))
```

Add `("RECURYA/SPECS/DB/DOMAIN" . "SUBMISSION-STATUS")` to `*expected-specs*`.

- [ ] **Step 2: Property**

In `specs/db/learn.lisp`: add `#:random-element #:*submission-statuses*` to the `recurya/specs/db/domain` import, `#:record-submission #:cell-submissions` to the `recurya/db/learn` import, and

```lisp
  (:import-from #:recurya/models/learn-submission
                #:learn-submission-code
                #:learn-submission-status)
```

Append:

```lisp
(defgenerator submission-plan ()
  "(SUBMISSIONS LIMIT): 1-10 submissions (USER NOTEBOOK CELL CODE STATUS) as
indices into two users, *NOTEBOOK-KEYS*, the first two *CELL-KEYS* and
*CODES*, with STATUS from *SUBMISSION-STATUSES*; LIMIT is :DEFAULT (argument
omitted) or 1-12."
  (list (loop repeat (1+ (random 10))
              collect (list (random 2) (random 2) (random 2)
                            (random (length *codes*))
                            (random-element *submission-statuses*)))
        (if (zerop (random 3)) :default (1+ (random 12)))))

(defspec submission-plan list (:generator submission-plan))

(defproperty submission-history ((plan submission-plan))
  "Every submission is kept: for each (user, notebook, cell),
CELL-SUBMISSIONS returns that cell's submissions newest first, at most LIMIT
of them (50 by default), and none of another cell's."
  (:about record-submission cell-submissions)
  (:kind :invariant)
  (:trials (:smoke 20 :normal 100))
  (destructuring-bind (submissions limit) plan
    (with-test-db
      (let ((users (two-users)))
        (loop for (u n c k status) in submissions
              do (record-submission (aref users u) (aref *notebook-keys* n)
                                    (aref *cell-keys* c) (aref *codes* k) status))
        (loop for u below 2
              always
              (loop for n below 2
                    always
                    (loop for c below 2
                          always
                          (let* ((args (list (aref users u) (aref *notebook-keys* n)
                                             (aref *cell-keys* c)))
                                 (rows (if (eq limit :default)
                                           (apply #'cell-submissions args)
                                           (apply #'cell-submissions
                                                  (append args (list :limit limit)))))
                                 (newest-first
                                   (reverse (loop for (su sn sc k status) in submissions
                                                  when (and (= su u) (= sn n) (= sc c))
                                                    collect (list (aref *codes* k) status)))))
                            (equal (mapcar (lambda (row)
                                             (list (learn-submission-code row)
                                                   (learn-submission-status row)))
                                           rows)
                                   (subseq newest-first 0
                                           (min (length newest-first)
                                                (if (eq limit :default) 50 limit))))))))))))
```

The order relies on `created_at`, which PostgreSQL stores with microseconds (measured while designing), so consecutive submissions sort apart; the DAO reads it back to the second, which is why the oracle uses the insertion order, not the DAO timestamps.

Add `("RECURYA/SPECS/DB/LEARN" . "SUBMISSION-HISTORY")` to `*expected-properties*`.

- [ ] **Step 3: Verify**

1. `load-system` `recurya/specs/all`.
2. `spec-check` `{"property":"recurya/specs/db/learn::submission-history","profile":"normal","timeout_seconds":180}` — expect passed. If it fails, stop and report.
3. `run-tests` `{"system":"recurya/tests/specs/contracts"}` — 3 passed.

- [ ] **Step 4: Lint and commit**

```bash
mallet specs/db/domain.lisp specs/db/learn.lisp tests/specs/contracts.lisp
git add specs/db/domain.lisp specs/db/learn.lisp tests/specs/contracts.lisp
git commit -m "feat(specs): exercise submission history contract

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Mutation checks, full suite, docs and feedback

**Files:**
- Modify: `docs/superpowers/specs/2026-10-11-cl-spec-db-rest-design.md` (append 検証結果; Markdown — use Edit)
- Modify: `docs/feedback/cl-mcp-cl-spec.md` (append entries)

- [ ] **Step 1: Mutation checks (worker only; files unchanged)**

Redefine via `repl-eval` (save the original with `fdefinition`, restore in `unwind-protect`), run the check, record the status. Each must NOT be `:passed`. Use `cl-spec/main:run-property` / `cl-spec/main:check-function` and `cl-spec/main:property-result-status`; `::` is fine inside these throwaway probes only.

| Mutation | Check |
|---|---|
| `recurya/utils/handle:reserved-handle-p` back to the reserved list only (`git show main:utils/handle.lisp`) | `check-function` reserved-handle-p, 300 trials; `run-property` placeholder-handle-never-real `:normal` |
| `recurya/db/novel::%flag-value->json` as identity (keywords stored as jzon writes them) | `run-property` persisted-flags-drive-next-scene `:normal`; novel-state-roundtrip `:smoke` |
| `recurya/game/novel/eval::%flag->binding` passing keyword values through unchanged | `run-property` persisted-flags-drive-next-scene `:normal` |
| `recurya/game/novel/interpreter:interpret-directives` back to the pre-Task-3 body (`git show main:game/novel/interpreter.lisp`) | `check-function` interpret-directives, 300 trials |
| `recurya/db/learn:cell-submissions` returning `(reverse (original ...))` | `run-property` submission-history `:normal` |
| `recurya/db/learn:cell-submissions` ignoring `:limit` (call the original with `:limit 50`) | `run-property` submission-history `:normal` |
| `recurya/db/users:update-user!` that always also passes `:language "ja"` | `run-property` user-update-partial `:normal` |
| `recurya/db/users:find-or-create-oauth-user` without the email branch: `(or (get-user-by-provider provider provider-uid) (insert-dao (make-instance 'users :id (generate-uuid) :email (or email "") :handle (%generate-placeholder-handle) :display-name (or display-name email "User") :role role :provider provider :provider-uid provider-uid)))` | `run-property` oauth-login-resolution `:normal` |

A mutation whose check signals (e.g. a unique-violation from the DB) counts as not passed; record the status. Restore with `load-system` `recurya` then `recurya/specs/all`, and confirm `run-tests` `recurya/tests/specs/contracts` passes. If a mutation stays `:passed`, report it (do not change the contract on your own).

- [ ] **Step 2: Full suite**

`run-tests` `{"system":"recurya/tests","timeout_seconds":900}` — expect all pass. Report the exact numbers and the contracts harness duration. Run `mallet` over every Lisp file changed on the branch (`git diff --name-only main -- '*.lisp'`) — `No problems found.`

- [ ] **Step 3: Record results**

Append a 検証結果 section to the design doc:

```markdown
## 検証結果

- 契約: Function Spec 2 (`reserved-handle-p`、`interpret-directives`)、Property 8
  (users 4、novel 3、learn 1)、値域 defspec 2 (`flag-value`、`submission-status`)。
- 変更前に赤: reserved-handle-p (<status と seed>)、placeholder-handle-never-real (<status と seed>)、
  interpret-directives (<status と seed>)、persisted-flags-drive-next-scene (<status と seed>)、
  novel-state-roundtrip (<status と seed>)。変更後に緑。
- ミューテーション: <Step 1 の表の各結果>。
- 全スイート: <passed>/<failed>、契約ハーネス所要時間 <ms>。
```

Fill the placeholders with the values actually observed (the implementer reports of Tasks 1, 3 and 4 record the red statuses and seeds; ask the controller if you do not have them).

Append to `docs/feedback/cl-mcp-cl-spec.md` (existing entry format, at the end) an entry for every cl-mcp/cl-spec friction actually hit during Tasks 1-6 (the controller passes the implementers' notes). In particular, if the Task 1 package move needed `pool-kill-worker` because a reload hit a name conflict, record that (moving a symbol between packages in a package-inferred system cannot be reloaded in place).

- [ ] **Step 4: Commit**

```bash
git add docs/feedback/cl-mcp-cl-spec.md docs/superpowers/specs/2026-10-11-cl-spec-db-rest-design.md
git commit -m "docs: record sub-project D verification and cl-spec feedback

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
