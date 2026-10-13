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
