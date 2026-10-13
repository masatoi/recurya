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
                #:api-path-p
                #:*token-authenticator*)
  (:import-from #:recurya/web/server
                #:csrf-with-skip
                #:build-app)
  (:import-from #:lack/test
                #:generate-env)
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

(deftest auth-failure-is-503-not-401
  ;; A failing token check (database down) must not tell clients to log in again.
  (multiple-value-bind (app seen) (capturing-app)
    (let ((*token-authenticator* (lambda (token)
                                   (declare (ignore token))
                                   (error "database is down"))))
      (let ((res (funcall (api-token-auth app)
                          (make-env "/api/v1/me" :authorization "Bearer rcy_whatever"))))
        (ok (= 503 (first res)))
        (ok (search "unavailable" (body-of res)))
        (ng (funcall seen) "inner app not called")))))

;;; The whole Lack stack, as BUILD-APP assembles it.
(defun set-cookie-p (response)
  "True when RESPONSE's headers set a cookie."
  (getf (second response) :set-cookie))

(defun stack-env (path &key (method :get) bearer cookie)
  (let ((headers '()))
    (when bearer (push (cons "authorization" (format nil "Bearer ~A" bearer)) headers))
    (when cookie (push (cons "cookie" cookie) headers))
    (generate-env path :method method :headers headers)))

(deftest build-app-api-stack-is-session-free
  (with-test-db
    (let* ((app (build-app :session-store
                           (lack/middleware/session/store/memory:make-memory-store)))
           (user (create-test-user :email-prefix "stack"))
           (plain (issue-api-token (users-id user) "stack")))
      (let ((res (funcall app (stack-env "/api/v1/me" :cookie "lack.session=forged"))))
        (ok (= 401 (first res)) "a cookie alone does not reach /api")
        (ng (set-cookie-p res)))
      (let ((res (funcall app (stack-env "/api/v1/me" :bearer plain))))
        (ok (= 200 (first res)) "bearer token works without a CSRF token")
        (ok (search (users-handle user) (body-of res)))
        (ng (set-cookie-p res) "no session cookie is issued under /api"))
      (let ((res (funcall app (stack-env "/api/v1/notebooks/x/y/cells/0/run"
                                         :method :post :bearer plain))))
        (ng (= 400 (first res)) "API POSTs are not blocked by CSRF")
        (ng (set-cookie-p res)))
      (let ((res (funcall app (stack-env "/login"))))
        (ok (= 200 (first res)))
        (ok (set-cookie-p res) "browser pages still get a session (control)"))
      (let ((res (funcall app (stack-env "/logout" :method :post))))
        (ok (= 400 (first res)) "a non-API POST still requires the CSRF token")))))

(deftest build-app-caps-request-bodies
  ;; Lack parses a JSON body when the request object is made, so the cap must
  ;; act in middleware, before the router and before the token lookup.
  (let ((app (build-app :session-store
                        (lack/middleware/session/store/memory:make-memory-store)))
        (big-json (format nil "{\"codes\": [\"~A\"]}"
                          (make-string (* 1024 1024) :initial-element #\a))))
    (let ((res (funcall app (generate-env "/api/v1/notebooks/x/y/cells/0/run"
                                          :method :post
                                          :headers '(("content-type" . "application/json")
                                                     ("authorization" . "Bearer rcy_unchecked"))
                                          :content big-json))))
      (ok (= 413 (first res)) "an API body over 1 MiB is refused before parsing")
      (ok (search "payload_too_large" (body-of res))))
    (let ((env (generate-env "/api/v1/notebooks/x/y/cells/0/run" :method :post)))
      (setf (gethash "transfer-encoding" (getf env :headers)) "chunked")
      (let ((res (funcall app env)))
        (ok (= 411 (first res)) "a chunked API body without Content-Length is refused")
        (ok (search "length_required" (body-of res)))))
    (let ((res (funcall app (generate-env "/learn/sync" :method :post
                                          :headers '(("content-type" . "application/json"))
                                          :content (make-string (1+ (* 5 1024 1024))
                                                                :initial-element #\a)))))
      (ok (= 413 (first res)) "/learn/sync is capped too (5 MiB)")
      (ng (set-cookie-p res) "refused before a session is made"))))
