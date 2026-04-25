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

;; Tests follow in subsequent tasks.
