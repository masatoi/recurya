;;;; tests/web/api-routes.lisp --- JSON API handlers (/api/v1/*).

(defpackage #:recurya/tests/web/api-routes
  (:use #:cl #:rove)
  (:import-from #:recurya/tests/support/db
                #:with-test-db
                #:create-test-user)
  (:import-from #:recurya/db/users
                #:users-id
                #:users-handle
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
                #:api-cell-run-handler
                #:parse-page
                #:with-api-errors)
  ;; Bare import: the error-log test adds a log4cl appender by qualified name.
  (:import-from #:log4cl)
  (:import-from #:recurya/web/http
                #:*max-request-body-bytes*
                #:read-request-body
                #:request-body-too-large
                #:parse-bounded-positive-integer)
  (:import-from #:recurya/web/routes
                #:public-notebook-by-handle-handler
                #:learn-sync-handler))

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
                                     (list (cons :captures (list handle "g")))))))
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

(deftest handlers-refuse-without-api-user
  ;; Defence in depth: should a request reach a handler without the token
  ;; middleware having set :RECURYA.API-USER, every handler answers 401.
  (with-api-request (nil :body (run-body "" "3"))
    (dolist (res (list (api-me-handler nil)
                       (api-notebooks-handler '(("page" . "1")))
                       (api-notebook-handler '((:handle . "a") (:slug . "b")))
                       (api-cell-run-handler '((:handle . "a") (:slug . "b") (:index . "1")))))
      (ok (= 401 (status-of res)))
      (ok (string= "unauthorized" (jget (json-of res) "error" "code"))))))

(deftest api-error-log-names-path-and-user
  (let* ((out (make-string-output-stream))
         (appender (make-instance 'log4cl:fixed-stream-appender :stream out)))
    (log4cl:add-appender log4cl:*root-logger* appender)
    (unwind-protect
         (let* ((env (list :request-method :get :path-info "/api/v1/boom"
                           :headers (make-hash-table :test 'equal)
                           :recurya.api-user (list :id "user-42")))
                (ningle/context:*request* (lack/request:make-request env))
                (res (with-api-errors (error "kaboom"))))
           (ok (= 500 (status-of res)))
           (ok (string= "internal" (jget (json-of res) "error" "code")))
           (let ((logged (get-output-stream-string out)))
             (ok (search "/api/v1/boom" logged) "the log line names the path")
             (ok (search "user-42" logged) "and the user id")
             (ok (search "kaboom" logged))))
      (log4cl:remove-appender log4cl:*root-logger* appender))))

(deftest run-caps-body-and-codes
  (with-test-db
    (let* ((author (create-test-user :email-prefix "api"))
           (handle (users-handle author))
           (user (user-dao->plist author))
           (path `((:handle . ,handle) (:slug . "g") (:index . "1"))))
      (make-nb author "g")
      (let ((res (with-api-request (user :body (run-body ""
                                                         (make-string (1+ *max-request-body-bytes*)
                                                                      :initial-element #\a)))
                   (api-cell-run-handler path))))
        (ok (= 413 (status-of res)) "a body over 1 MiB is refused")
        (ok (string= "payload_too_large" (jget (json-of res) "error" "code"))))
      (let ((res (with-api-request (user :body (run-body "" "3" "" ""))
                   (api-cell-run-handler path))))
        (ok (= 422 (status-of res)) "more codes than the notebook's 3 cells")
        (ok (string= "invalid_request" (jget (json-of res) "error" "code"))))
      (let ((res (with-api-request (user :body (run-body "" (make-string (1+ (* 64 1024))
                                                                         :initial-element #\a)))
                   (api-cell-run-handler path))))
        (ok (= 422 (status-of res)) "a code over 64 KiB is refused"))
      (with-api-request (user :body (run-body "" "3" ""))
        (ok (= 200 (status-of (api-cell-run-handler path)))
            "one code per cell is still accepted")))))

(deftest page-numbers-are-bounded
  (ok (= 1 (parse-page "1000000001")) "over 10^9 falls back to page 1")
  (ok (= 1 (parse-page "99999999999999999999999999")))
  (ok (= 1000000000 (parse-page "1000000000")))
  (ok (= 3 (parse-page "3")))
  (ok (= 1 (parse-page "0")))
  (ok (= 1 (parse-page nil))))

(deftest read-request-body-is-capped
  (with-api-request (nil :body "{\"a\": 1}")
    (ok (string= "{\"a\": 1}" (read-request-body)) "a normal body reads as before")
    (ok (signals (read-request-body :max-bytes 3) 'request-body-too-large)))
  (ok (null (parse-bounded-positive-integer "1000000001")))
  (ok (= 7 (parse-bounded-positive-integer "7")))
  (ok (null (parse-bounded-positive-integer nil))))

(deftest learn-sync-refuses-oversized-body
  (let ((ningle/context:*session* (make-hash-table)))
    (setf (gethash :user ningle/context:*session*) (list :id "00000000-0000-0000-0000-000000000000"))
    (let* ((env (list :request-method :post :path-info "/learn/sync"
                      :headers (make-hash-table :test 'equal)
                      :raw-body (flexi-streams:make-in-memory-input-stream
                                 (make-array 0 :element-type '(unsigned-byte 8)))
                      ;; Declared size only: the cap is checked before reading.
                      :content-length (1+ (* 5 1024 1024))))
           (ningle/context:*request* (lack/request:make-request env))
           (res (learn-sync-handler nil)))
      (ok (= 413 (status-of res)))
      (ok (string= "payload too large" (jget (json-of res) "error"))))))

(deftest scene-cell-body-is-withheld
  (with-test-db
    (let ((author (create-test-user :email-prefix "api")))
      (make-nb author "sc" :body (format nil "===prose===~%hi~%~%===scene===~%SCENE-SECRET-BRANCH"))
      (with-api-request ((user-dao->plist author))
        (let* ((res (api-notebook-handler `((:handle . ,(users-handle author)) (:slug . "sc"))))
               (cells (jget (json-of res) "cells")))
          (ok (= 200 (status-of res)))
          (ok (string= "scene" (jget cells 1 "kind")))
          (ok (eq 'null (jget cells 1 "body")) "scene source is not exposed")
          (ok (search "hi" (jget cells 0 "body")) "other cells keep their body"))))))
