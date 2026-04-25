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

;; Tests follow in subsequent tasks.
