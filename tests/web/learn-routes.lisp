;;;; tests/web/learn-routes.lisp --- Tests for /wardlisp/learn route handlers.

(defpackage #:recurya/tests/web/learn-routes
  (:use #:cl
        #:rove)
  (:import-from #:recurya/web/routes-wardlisp
                #:learn-home-handler
                #:notebook-page-handler
                #:notebook-cell-run-handler)
  (:import-from #:recurya/game/notebook
                #:make-cell
                #:make-notebook-cell-result)
  (:import-from #:recurya/db/learn
                #:user-cell-codes
                #:user-passed-cells
                #:cell-submissions)
  (:import-from #:recurya/models/users
                #:users-id)
  (:import-from #:recurya/tests/support/db
                #:with-test-db
                #:create-test-user))

(in-package #:recurya/tests/web/learn-routes)

;;; --- Response accessors (mirrors tests/web/routes.lisp) ---

(defun response-status (response)
  (first response))

(defun response-headers (response)
  (second response))

(defun response-body (response)
  (third response))

(defun header-value (response name)
  "Fetch a response header value by case-insensitive NAME (string).
   Headers are a plist of keywords on the raw response."
  (let ((target (string-upcase name)))
    (loop for (k v) on (response-headers response) by #'cddr
          when (and (keywordp k)
                    (string= target (string-upcase (symbol-name k))))
            return v)))

;;; --- Param helpers ---

(defun path-params (&rest kv)
  "Build a path-param alist: (:id . \"sicp-1-1-1\") etc. KV is flat kw/val list."
  (loop for (k v) on kv by #'cddr
        collect (cons k v)))

(defun make-codes-params (codes)
  "Build the params alist with one (\"codes[]\" . value) cons per code string,
   matching what quri:url-decode-params produces for repeated form fields."
  (loop for v in codes
        collect (cons "codes[]" v)))

(defun combine-params (&rest alists)
  "Concatenate several alists into one."
  (apply #'append alists))

;;; ---------------------------------------------------------------------------
;;; GET /wardlisp/learn
;;; ---------------------------------------------------------------------------

(deftest learn-home-ok
  (testing "GET /wardlisp/learn returns 200 and body mentions SICP"
    (let* ((response (learn-home-handler nil))
           (body (first (response-body response))))
      (ok (= 200 (response-status response)))
      (ok (search "SICP" body)
          "Landing page body contains the string SICP"))))

;;; ---------------------------------------------------------------------------
;;; GET /wardlisp/learn/:id
;;; ---------------------------------------------------------------------------

(deftest notebook-page-ok
  (testing "GET /wardlisp/learn/sicp-1-1-1 returns 200 with chapter number"
    (let* ((response (notebook-page-handler
                      (path-params :id "sicp-1-1-1")))
           (body (first (response-body response))))
      (ok (= 200 (response-status response)))
      (ok (search "1.1.1" body)
          "Notebook page contains chapter number 1.1.1"))))

(deftest notebook-page-404
  (testing "GET /wardlisp/learn/no-such-id returns 404"
    (let ((response (notebook-page-handler
                     (path-params :id "no-such-id"))))
      (ok (= 404 (response-status response))))))

;;; ---------------------------------------------------------------------------
;;; POST /wardlisp/learn/:id/cells/:index/run
;;; ---------------------------------------------------------------------------

(defun sicp-1-1-1-exercise-codes (&key user-code)
  "Build the eight codes[] entries for sicp-1-1-1, with USER-CODE in the
   exercise slot (index 7). Prose cells (indices 0, 2, 5) use empty strings;
   code-eval cells are filled with their canonical bodies so earlier cells
   still parse cleanly if run-cell evaluates them for state propagation."
  (list ""                               ;; 0 :intro   (prose)
        "486"                            ;; 1 :num
        ""                               ;; 2 :prefix  (prose)
        "(+ 137 349)"                    ;; 3 :add
        "(- 1000 334)"                   ;; 4 :more-arith
        ""                               ;; 5 :nested-prose (prose)
        "(+ (* 3 5) (- 10 6))"           ;; 6 :nested
        user-code))                      ;; 7 :ex-sum3 (code-exercise)

(deftest cell-run-exercise-pass
  (testing "POST .../cells/7/run with correct code returns :pass and HX-Trigger"
    (let* ((codes (sicp-1-1-1-exercise-codes :user-code "(+ 137 349 22)"))
           (params (combine-params
                    (path-params :id "sicp-1-1-1" :index "7")
                    (make-codes-params codes)))
           (response (notebook-cell-run-handler params))
           (body (first (response-body response))))
      (ok (= 200 (response-status response)))
      (ok (search "PASS" body)
          "Body shows PASS badge on success")
      (ok (header-value response "HX-Trigger")
          "Response carries an HX-Trigger header on pass")
      (ok (search "cell-passed"
                  (or (header-value response "HX-Trigger") ""))
          "HX-Trigger payload references the cell-passed event"))))

(deftest cell-run-index-out-of-range
  (testing "POST with index 99 returns 400"
    (let* ((params (combine-params
                    (path-params :id "sicp-1-1-1" :index "99")
                    (make-codes-params (list "" "" "" "" "" "" "" ""))))
           (response (notebook-cell-run-handler params)))
      (ok (= 400 (response-status response))))))

(deftest cell-run-prose-rejected
  (testing "POST on prose cell (index 0 is :intro) returns 400"
    (let* ((params (combine-params
                    (path-params :id "sicp-1-1-1" :index "0")
                    (make-codes-params (list ""))))
           (response (notebook-cell-run-handler params)))
      (ok (= 400 (response-status response))))))

(deftest cell-run-params-repeated-keys
  (testing "handler consumes repeated codes[] cons cells (real HTTP alist shape)"
    (let* ((raw-params `((:id . "sicp-1-1-1")
                         (:index . "7")
                         ("codes[]" . "")
                         ("codes[]" . "486")
                         ("codes[]" . "")
                         ("codes[]" . "(+ 137 349)")
                         ("codes[]" . ,(format nil "(- 1000 334)~%(* 5 99)~%(/ 10 5)"))
                         ("codes[]" . "")
                         ("codes[]" . "(+ (* 3 5) (- 10 6))")
                         ("codes[]" . "(+ 137 349 22)")))
           (response (notebook-cell-run-handler raw-params))
           (body (first (response-body response))))
      (ok (= 200 (response-status response)))
      (ok (or (search "PASS" body) (search "全テスト合格" body))))))

(deftest sync-handler-anonymous-rejects
  (testing "POST /wardlisp/learn/sync without auth returns 401"
    (let ((ningle/context:*session* nil)
          (ningle/context:*request* nil))
      (let ((response (recurya/web/routes-wardlisp::learn-sync-handler nil)))
        (ok (= 401 (response-status response)))
        (ok (search "auth required"
                    (or (first (response-body response)) "")))))))

(deftest persist-cell-run-anonymous-no-write
  (testing "%maybe-persist-cell-run with nil uid does nothing"
    (with-test-db
      (let* ((u (create-test-user))
             (uid (users-id u))
             (cell (make-cell :id :ex-sum3 :kind :code-exercise :body ""))
             (result (make-notebook-cell-result
                      :cell-id :ex-sum3 :kind :code-exercise
                      :status :pass :metrics nil :test-results nil)))
        (recurya/web/routes-wardlisp::%maybe-persist-cell-run
         nil :sicp-1-1-1 cell result "(+ 1 2)")
        ;; Scope checks to the fresh user — global tables may contain leftover
        ;; rows from prior runs, but no row should ever appear for this uid.
        (ok (null (user-cell-codes uid "sicp-1-1-1")))
        (ok (null (user-passed-cells uid "sicp-1-1-1")))
        (ok (null (cell-submissions uid "sicp-1-1-1" "ex-sum3")))))))

(deftest persist-cell-run-logged-in-saves-code
  (testing "logged-in run saves code via upsert-cell-code"
    (with-test-db
      (let* ((u (create-test-user))
             (uid (users-id u))
             (cell (make-cell :id :c1 :kind :code-eval :body ""))
             (result (make-notebook-cell-result
                      :cell-id :c1 :kind :code-eval :status :ok
                      :metrics nil :test-results nil)))
        (recurya/web/routes-wardlisp::%maybe-persist-cell-run
         uid :sicp-1-1-1 cell result "(+ 1 2)")
        (let ((rows (user-cell-codes uid "sicp-1-1-1")))
          (ok (= 1 (length rows)))
          (ok (string= "(+ 1 2)"
                       (cdr (assoc "c1" rows :test #'string=)))))))))

(deftest persist-cell-run-pass-marks-progress
  (testing "logged-in :pass on exercise marks progress"
    (with-test-db
      (let* ((u (create-test-user))
             (uid (users-id u))
             (cell (make-cell :id :ex-sum3 :kind :code-exercise :body ""))
             (result (make-notebook-cell-result
                      :cell-id :ex-sum3 :kind :code-exercise
                      :status :pass :metrics nil :test-results nil)))
        (recurya/web/routes-wardlisp::%maybe-persist-cell-run
         uid :sicp-1-1-1 cell result "(+ 137 349 22)")
        (ok (member "ex-sum3"
                    (user-passed-cells uid "sicp-1-1-1")
                    :test #'string=))))))

(deftest persist-cell-run-records-submission
  (testing "logged-in exercise run appends a submission row"
    (with-test-db
      (let* ((u (create-test-user))
             (uid (users-id u))
             (cell (make-cell :id :ex-sum3 :kind :code-exercise :body ""))
             (result (make-notebook-cell-result
                      :cell-id :ex-sum3 :kind :code-exercise
                      :status :fail :metrics nil :test-results nil)))
        (recurya/web/routes-wardlisp::%maybe-persist-cell-run
         uid :sicp-1-1-1 cell result "(bad)")
        (ok (= 1 (length (cell-submissions uid "sicp-1-1-1" "ex-sum3"))))))))
