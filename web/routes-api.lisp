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
