;;;; web/routes-wardlisp.lisp --- WardLisp puzzle and arena routes.

(defpackage #:recurya/web/routes-wardlisp
  (:use #:cl)
  (:import-from #:recurya/game/puzzle
                #:run-puzzle)
  (:import-from #:recurya/game/puzzles/registry
                #:get-puzzle
                #:all-puzzles)
  (:import-from #:recurya/game/puzzle
                #:puzzle-id)
  (:import-from #:spinneret
                #:with-html-string)
  (:import-from #:recurya/web/ui/wardlisp-home)
  (:import-from #:recurya/web/ui/puzzle)
  (:import-from #:recurya/game/arena
                #:simulate-arena
                #:arena-result-error)
  (:import-from #:recurya/game/scenario
                #:default-scenario)
  (:import-from #:recurya/web/ui/arena)
  (:import-from #:recurya/web/ui/reference)
  (:import-from #:recurya/web/ui/playground)
  (:import-from #:wardlisp
                #:evaluate
                #:print-value)
  (:import-from #:recurya/game/notebook
                #:run-cell
                #:notebook-cells
                #:cell-id
                #:cell-kind
                #:notebook-cell-result-cell-id
                #:notebook-cell-result-status)
  (:import-from #:recurya/db/learn
                #:mark-cell-passed
                #:upsert-cell-code
                #:record-submission)
  (:import-from #:recurya/game/notebooks/registry
                #:get-notebook
                #:all-notebooks)
  (:import-from #:recurya/web/ui/learn-home)
  (:import-from #:recurya/web/ui/notebook)
  (:export #:setup-wardlisp-routes))

(in-package #:recurya/web/routes-wardlisp)

;;; --- Response Helpers (same pattern as web/routes.lisp) ---

(defun %current-user-id ()
  "Return the current user's UUID from the Ningle session, or nil if anonymous."
  (let* ((session ningle/context:*session*)
         (user (and session (gethash :user session))))
    (and user (getf user :id))))

(defun html-response (body &key (status 200))
  "Create an HTML response."
  (list status '(:content-type "text/html; charset=utf-8") (list body)))

(defun html-response-with-headers (body headers &key (status 200))
  "Like HTML-RESPONSE but also includes HEADERS (alist of (name . value))
   in the response. Returns a Clack/Lack ring-style response list."
  (list status
        (append '(:content-type "text/html; charset=utf-8")
                (loop for (k . v) in headers
                      collect (intern (string-upcase k) :keyword)
                      collect v))
        (list body)))

(defun get-param (params key)
  "Get a parameter value from the alist."
  (cdr (assoc key params :test #'string-equal)))

(defun get-path-param (params key)
  "Get a path parameter (keyword) from the alist."
  (cdr (assoc key params)))

;;; --- Handlers ---

(defun wardlisp-home-handler (params)
  "GET /wardlisp/ - Puzzle listing page."
  (declare (ignore params))
  (html-response
   (recurya/web/ui/wardlisp-home:render (all-puzzles))))

(defun puzzle-page-handler (params)
  "GET /wardlisp/puzzle/:id - Puzzle page with editor."
  (let* ((id-str (get-path-param params :id))
         (id (intern (string-upcase id-str) :keyword))
         (puzzle (get-puzzle id)))
    (if puzzle
        (html-response (recurya/web/ui/puzzle:render puzzle))
        (html-response "<h1>Puzzle not found</h1>" :status 404))))

(defun puzzle-run-handler (params)
  "POST /wardlisp/puzzle/:id/run - Execute and grade user code (HTMX fragment)."
  (let* ((id-str (get-path-param params :id))
         (id (intern (string-upcase id-str) :keyword))
         (code (get-param params "code"))
         (puzzle (get-puzzle id)))
    (if puzzle
        (let ((puzzle-result (run-puzzle puzzle (or code ""))))
          ;; Evaluate user code standalone to show its output
          (multiple-value-bind (eval-result eval-metrics)
              (handler-case
                  (evaluate (or code "")
                            :fuel 100000 :max-depth 200
                            :max-cons 10000 :max-output 10000
                            :max-integer 100000000000 :timeout 5)
                (error (e)
                  (values nil (list :error-message (format nil "~A" e)))))
            (let ((eval-error (getf eval-metrics :error-message))
                  (eval-output (print-value eval-result))
                  (print-output (getf eval-metrics :output)))
              (html-response
               (recurya/web/ui/puzzle:render-result
                puzzle-result
                :eval-output eval-output
                :eval-error eval-error
                :print-output print-output)))))
        (html-response "<div class=\"error\">Puzzle not found</div>"
                       :status 404))))

(defun arena-page-handler (params)
  "GET /wardlisp/arena - Arena page with code editor."
  (declare (ignore params))
  (html-response (recurya/web/ui/arena:render)))

(defun arena-run-handler (params)
  "POST /wardlisp/arena/run - Execute arena simulation (HTMX fragment)."
  (let* ((code (get-param params "code"))
         (result (simulate-arena (or code "") (default-scenario))))
    (html-response (recurya/web/ui/arena:render-result result))))

(defun reference-page-handler (params)
  "GET /wardlisp/reference - Language reference page."
  (declare (ignore params))
  (html-response (recurya/web/ui/reference:render)))

;;; --- Dynamic dispatch ---

(defun playground-handler (params)
  "GET /wardlisp/playground - Free-form code evaluation page."
  (declare (ignore params))
  (html-response (recurya/web/ui/playground:render)))

(defun playground-run-handler (params)
  "POST /wardlisp/playground/run - Evaluate user code (HTMX fragment)."
  (let ((code (get-param params "code")))
    (html-response (recurya/web/ui/playground:render-result (or code "")))))

(defun make-dynamic-handler (handler-symbol)
  "Create a handler that looks up the function by symbol at call time."
  (lambda (params)
    (funcall (symbol-function handler-symbol) params)))

;;; --- Route Setup ---

(defun %coerce-notebook-id (raw)
  "Normalize an incoming :id path-param value to a keyword.
   Ningle supplies path params as strings; direct test calls may pass keywords."
  (typecase raw
    (keyword raw)
    (string (and (plusp (length raw)) (intern (string-upcase raw) :keyword)))
    (symbol (intern (string-upcase (symbol-name raw)) :keyword))
    (t nil)))

(defun learn-home-handler (params)
  "GET /wardlisp/learn - SICP course index."
  (declare (ignore params))
  (html-response (recurya/web/ui/learn-home:render (all-notebooks))))

(defun notebook-page-handler (params)
  "GET /wardlisp/learn/:id - Notebook page."
  (let* ((id (%coerce-notebook-id (get-path-param params :id)))
         (nb (and id (get-notebook id))))
    (cond
      ((not nb) (html-response "<h1>404</h1>" :status 404))
      (t
       (let* ((session ningle/context:*session*)
              (user (and session (gethash :user session)))
              (uid (and user (getf user :id)))
              (nb-id-str (string-downcase (symbol-name id)))
              (saved-codes (and uid (recurya/db/learn:user-cell-codes uid nb-id-str)))
              (passed-cells (and uid (recurya/db/learn:user-passed-cells uid nb-id-str))))
         (html-response (recurya/web/ui/notebook:render
                         nb
                         :user user
                         :saved-codes saved-codes
                         :passed-cells passed-cells)))))))

(defun %maybe-persist-cell-run (uid nb-id-keyword cell result code)
  "If UID is non-nil (logged in), persist cell run state to DB.
   DB failures are logged and silenced — the user-facing response stays intact."
  (when uid
    (handler-case
        (let* ((nb-id-str (string-downcase (symbol-name nb-id-keyword)))
               (cell-id-str (string-downcase (symbol-name (cell-id cell))))
               (status (notebook-cell-result-status result))
               (kind (cell-kind cell)))
          (upsert-cell-code uid nb-id-str cell-id-str (or code ""))
          (when (eq kind :code-exercise)
            (record-submission uid nb-id-str cell-id-str (or code "")
                               (string-downcase (symbol-name status)))
            (when (eq status :pass)
              (mark-cell-passed uid nb-id-str cell-id-str))))
      (error (e)
        (log:warn "Failed to persist cell run: ~A" e)))))

(defun notebook-cell-run-handler (params)
  "POST /wardlisp/learn/:id/cells/:index/run — HTMX fragment."
  (let* ((id (%coerce-notebook-id (get-path-param params :id)))
         (nb (and id (get-notebook id)))
         (index-str (get-path-param params :index))
         (index (and index-str
                     (typecase index-str
                       (string (parse-integer index-str :junk-allowed t))
                       (integer index-str)
                       (t nil))))
         (codes-list (loop for (k . v) in params
                           when (and (stringp k) (string= k "codes[]"))
                             collect v)))
    (cond
      ((not nb) (html-response "Notebook not found" :status 404))
      ((not index) (html-response "Invalid index" :status 400))
      ((or (< index 0) (>= index (length (notebook-cells nb))))
       (html-response "Index out of range" :status 400))
      ((eq (cell-kind (nth index (notebook-cells nb))) :prose)
       (html-response "Cannot run a prose cell" :status 400))
      (t
       (let* ((result (run-cell nb index codes-list))
              (body (recurya/web/ui/notebook:render-cell-result result)))
         (%maybe-persist-cell-run
          (%current-user-id)
          id
          (nth index (notebook-cells nb))
          result
          (nth index codes-list))
         (if (eq (notebook-cell-result-status result) :pass)
             (html-response-with-headers
              body
              `(("HX-Trigger"
                 . ,(format nil
                            "{\"cell-passed\":{\"notebook\":\"~A\",\"cell\":\"~A\"}}"
                            (string-downcase (symbol-name id))
                            (string-downcase
                             (symbol-name
                              (notebook-cell-result-cell-id result)))))))
             (html-response body)))))))

(defun setup-wardlisp-routes (app)
  "Register all WardLisp routes on the Ningle app."
  (setf (ningle/app:route app "/wardlisp/")
        (make-dynamic-handler 'wardlisp-home-handler))
  (setf (ningle/app:route app "/wardlisp/puzzle/:id")
        (make-dynamic-handler 'puzzle-page-handler))
  (setf (ningle/app:route app "/wardlisp/puzzle/:id/run" :method :post)
        (make-dynamic-handler 'puzzle-run-handler))
  (setf (ningle/app:route app "/wardlisp/arena")
        (make-dynamic-handler 'arena-page-handler))
  (setf (ningle/app:route app "/wardlisp/arena/run" :method :post)
        (make-dynamic-handler 'arena-run-handler))
  (setf (ningle/app:route app "/wardlisp/reference")
        (make-dynamic-handler 'reference-page-handler))
  (setf (ningle/app:route app "/wardlisp/learn")
        (make-dynamic-handler 'learn-home-handler))
  (setf (ningle/app:route app "/wardlisp/learn/:id")
        (make-dynamic-handler 'notebook-page-handler))
  (setf (ningle/app:route app "/wardlisp/learn/:id/cells/:index/run" :method :post)
        (make-dynamic-handler 'notebook-cell-run-handler))
  (setf (ningle/app:route app "/wardlisp/playground")
        (make-dynamic-handler 'playground-handler))
  (setf (ningle/app:route app "/wardlisp/playground/run" :method :post)
        (make-dynamic-handler 'playground-run-handler))
  app)
