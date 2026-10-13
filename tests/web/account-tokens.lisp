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
