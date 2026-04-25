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

(defun mark-cell-passed (user-id notebook-id cell-id)
  "Mark CELL-ID in NOTEBOOK-ID as passed for USER-ID. Idempotent —
   if a row already exists, returns it unchanged. Returns the
   learn-progress instance."
  (or (find-dao 'learn-progress
                :user-id user-id
                :notebook-id notebook-id
                :cell-id cell-id)
      (handler-case
          (insert-dao
           (make-instance 'learn-progress
                          :user-id user-id
                          :notebook-id notebook-id
                          :cell-id cell-id
                          :passed-at (now)))
        (error ()
          (find-dao 'learn-progress
                    :user-id user-id
                    :notebook-id notebook-id
                    :cell-id cell-id)))))

(defun user-passed-cells (user-id notebook-id)
  "Return list of cell-id strings the USER-ID has passed in NOTEBOOK-ID."
  (mapcar #'learn-progress-cell-id
          (select-dao 'learn-progress
            (where (:and (:= :user-id user-id)
                         (:= :notebook-id notebook-id))))))
