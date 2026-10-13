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
