;;;; db/learn.lisp --- DB access layer for SICP notebook learning state.

(defpackage #:recurya/db/learn
  (:use #:cl #:mito #:sxql)
  (:import-from #:recurya/models/learn-progress
                #:learn-progress
                #:learn-progress-cell-id
                #:learn-progress-passed-at)
  (:import-from #:recurya/models/learn-cell-code
                #:learn-cell-code
                #:learn-cell-code-cell-id
                #:learn-cell-code-code)
  (:import-from #:recurya/models/learn-submission
                #:learn-submission)
  (:import-from #:local-time
                #:now)
  (:export #:mark-cell-passed
           #:user-passed-cells
           #:upsert-cell-code
           #:user-cell-codes
           #:record-submission
           #:cell-submissions
           #:merge-localstorage))

(in-package #:recurya/db/learn)

(defun __stub () nil)
