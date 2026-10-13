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
                #:api-token
                #:api-token-id
                #:api-token-revoked-at
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

(deftest authenticate-does-not-resurrect-revoked-token
  (with-test-db
    (let* ((user (create-test-user :email-prefix "tok"))
           (uid (users-id user)))
      (multiple-value-bind (plain row) (issue-api-token uid "a")
        (let ((stale (mito:find-dao 'api-token :id (api-token-id row))))
          (ok (revoke-api-token uid (api-token-id row)))
          (ng (authenticate-api-token plain) "refused after revocation")
          (let ((fresh (mito:find-dao 'api-token :id (api-token-id stale))))
            (ok (null->nil (api-token-revoked-at fresh)) "revoked_at is still set")
            (ng (null->nil (api-token-last-used-at fresh))
                "a refused attempt does not record last_used_at")))))))
