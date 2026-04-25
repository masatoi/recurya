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

(defun upsert-cell-code (user-id notebook-id cell-id code)
  "Insert or update the saved code for (USER-ID, NOTEBOOK-ID, CELL-ID).
   Returns the learn-cell-code instance."
  (let ((existing (find-dao 'learn-cell-code
                            :user-id user-id
                            :notebook-id notebook-id
                            :cell-id cell-id)))
    (cond
      (existing
       (setf (learn-cell-code-code existing) code)
       (save-dao existing)
       existing)
      (t
       (handler-case
           (insert-dao
            (make-instance 'learn-cell-code
                           :user-id user-id
                           :notebook-id notebook-id
                           :cell-id cell-id
                           :code code))
         (error ()
           (let ((row (find-dao 'learn-cell-code
                                :user-id user-id
                                :notebook-id notebook-id
                                :cell-id cell-id)))
             (when row
               (setf (learn-cell-code-code row) code)
               (save-dao row))
             row)))))))

(defun user-cell-codes (user-id notebook-id)
  "Return alist ((cell-id . code) ...) of saved codes for USER-ID in NOTEBOOK-ID."
  (mapcar (lambda (row)
            (cons (learn-cell-code-cell-id row)
                  (learn-cell-code-code row)))
          (select-dao 'learn-cell-code
            (where (:and (:= :user-id user-id)
                         (:= :notebook-id notebook-id))))))

(defun record-submission (user-id notebook-id cell-id code status)
  "Append an exercise submission to the history. STATUS is a string
   among \"pass\" / \"fail\" / \"error\"."
  (insert-dao
   (make-instance 'learn-submission
                  :user-id user-id
                  :notebook-id notebook-id
                  :cell-id cell-id
                  :code code
                  :status status)))

(defun cell-submissions (user-id notebook-id cell-id &key (limit 50))
  "Return list of learn-submission rows for the given cell, newest first."
  (select-dao 'learn-submission
    (where (:and (:= :user-id user-id)
                 (:= :notebook-id notebook-id)
                 (:= :cell-id cell-id)))
    (order-by (:desc :created-at))
    (sxql:limit limit)))
