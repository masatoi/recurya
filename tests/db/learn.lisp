;;;; tests/db/learn.lisp --- Tests for the SICP notebook DB layer.

(defpackage #:recurya/tests/db/learn
  (:use #:cl #:rove)
  (:import-from #:recurya/tests/support/db
                #:with-test-db
                #:create-test-user)
  (:import-from #:recurya/models/users
                #:users-id)
  (:import-from #:recurya/db/learn
                #:mark-cell-passed
                #:user-passed-cells
                #:upsert-cell-code
                #:user-cell-codes
                #:record-submission
                #:cell-submissions
                #:merge-localstorage))

(in-package #:recurya/tests/db/learn)

(deftest mark-cell-passed-inserts-once
  (testing "calling mark-cell-passed twice for same cell does not duplicate"
    (with-test-db
      (let* ((u (create-test-user))
             (uid (users-id u)))
        (mark-cell-passed uid "sicp-1-1-1" "ex-sum3")
        (mark-cell-passed uid "sicp-1-1-1" "ex-sum3")
        (let ((rows (mito:retrieve-dao 'recurya/models/learn-progress:learn-progress
                                       :user-id uid)))
          (ok (= 1 (length rows))))))))

(deftest user-passed-cells-returns-cell-ids
  (testing "user-passed-cells returns cell-id strings for the given notebook"
    (with-test-db
      (let* ((u (create-test-user))
             (uid (users-id u)))
        (mark-cell-passed uid "sicp-1-1-1" "ex-sum3")
        (mark-cell-passed uid "sicp-1-1-1" "ex-square")
        (mark-cell-passed uid "sicp-1-1-2" "ex-other")
        (let ((cells (sort (copy-list (user-passed-cells uid "sicp-1-1-1"))
                           #'string<)))
          (ok (equal cells '("ex-square" "ex-sum3"))))))))

(deftest upsert-cell-code-inserts-then-updates
  (testing "first call inserts, second call updates the same row"
    (with-test-db
      (let* ((u (create-test-user)) (uid (users-id u)))
        (upsert-cell-code uid "sicp-1-1-1" "ex-sum3" "(+ 1 2)")
        (upsert-cell-code uid "sicp-1-1-1" "ex-sum3" "(+ 137 349 22)")
        (let ((rows (mito:retrieve-dao 'recurya/models/learn-cell-code:learn-cell-code
                                       :user-id uid)))
          (ok (= 1 (length rows)))
          (ok (string= "(+ 137 349 22)"
                       (recurya/models/learn-cell-code:learn-cell-code-code
                        (first rows)))))))))

(deftest user-cell-codes-returns-alist
  (testing "user-cell-codes returns (cell-id . code) alist"
    (with-test-db
      (let* ((u (create-test-user)) (uid (users-id u)))
        (upsert-cell-code uid "sicp-1-1-1" "ex-sum3" "code-A")
        (upsert-cell-code uid "sicp-1-1-1" "ex-square" "code-B")
        (upsert-cell-code uid "sicp-1-1-2" "ex-other" "code-C")
        (let ((alist (user-cell-codes uid "sicp-1-1-1")))
          (ok (= 2 (length alist)))
          (ok (string= "code-A" (cdr (assoc "ex-sum3" alist :test #'string=))))
          (ok (string= "code-B" (cdr (assoc "ex-square" alist :test #'string=)))))))))

(deftest record-submission-appends-each-call
  (testing "each call inserts a new row"
    (with-test-db
      (let* ((u (create-test-user)) (uid (users-id u)))
        (record-submission uid "sicp-1-1-1" "ex-sum3" "(bad)" "fail")
        (record-submission uid "sicp-1-1-1" "ex-sum3" "(+ 1)" "fail")
        (record-submission uid "sicp-1-1-1" "ex-sum3" "(+ 137 349 22)" "pass")
        (let ((rows (mito:retrieve-dao 'recurya/models/learn-submission:learn-submission
                                       :user-id uid)))
          (ok (= 3 (length rows))))))))

(deftest cell-submissions-newest-first
  (testing "cell-submissions returns rows ordered newest-first"
    (with-test-db
      (let* ((u (create-test-user)) (uid (users-id u)))
        (record-submission uid "sicp-1-1-1" "ex-sum3" "v1" "fail")
        (sleep 0.05)
        (record-submission uid "sicp-1-1-1" "ex-sum3" "v2" "fail")
        (sleep 0.05)
        (record-submission uid "sicp-1-1-1" "ex-sum3" "v3" "pass")
        (let* ((rows (cell-submissions uid "sicp-1-1-1" "ex-sum3"))
               (codes (mapcar #'recurya/models/learn-submission:learn-submission-code rows)))
          (ok (equal codes '("v3" "v2" "v1"))))))))

(deftest merge-localstorage-or-passed
  (testing "merge unions passed cells (DB ∪ payload)"
    (with-test-db
      (let* ((u (create-test-user)) (uid (users-id u)))
        (mark-cell-passed uid "sicp-1-1-1" "ex-old")
        (let ((summary (merge-localstorage
                        uid
                        '((:notebook-id "sicp-1-1-1"
                           :passed ("ex-new" "ex-old")
                           :codes ())))))
          (ok (= 1 (getf summary :passed-merged)))
          (let ((cells (sort (copy-list (user-passed-cells uid "sicp-1-1-1"))
                             #'string<)))
            (ok (equal cells '("ex-new" "ex-old")))))))))

(deftest merge-localstorage-keeps-existing-code
  (testing "merge does not overwrite existing DB code (DB wins)"
    (with-test-db
      (let* ((u (create-test-user)) (uid (users-id u)))
        (upsert-cell-code uid "sicp-1-1-1" "ex-sum3" "DB-code")
        (let ((summary (merge-localstorage
                        uid
                        '((:notebook-id "sicp-1-1-1"
                           :passed ()
                           :codes (("ex-sum3" . "LOCAL-code")))))))
          (ok (= 0 (getf summary :codes-merged)))
          (ok (= 1 (getf summary :codes-skipped)))
          (let ((codes (user-cell-codes uid "sicp-1-1-1")))
            (ok (string= "DB-code"
                         (cdr (assoc "ex-sum3" codes :test #'string=))))))))))

(deftest merge-localstorage-inserts-new-code
  (testing "merge inserts code when DB has no row for the cell"
    (with-test-db
      (let* ((u (create-test-user)) (uid (users-id u)))
        (let ((summary (merge-localstorage
                        uid
                        '((:notebook-id "sicp-1-1-1"
                           :passed ()
                           :codes (("ex-sum3" . "LOCAL-code")))))))
          (ok (= 1 (getf summary :codes-merged)))
          (ok (= 0 (getf summary :codes-skipped)))
          (let ((codes (user-cell-codes uid "sicp-1-1-1")))
            (ok (string= "LOCAL-code"
                         (cdr (assoc "ex-sum3" codes :test #'string=))))))))))

;; Tests follow in subsequent tasks.
