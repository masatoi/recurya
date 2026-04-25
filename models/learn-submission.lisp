;;;; models/learn-submission.lisp --- Mito table for exercise submission history.

(defpackage #:recurya/models/learn-submission
  (:use #:cl #:mito)
  (:export #:learn-submission
           #:learn-submission-user-id
           #:learn-submission-notebook-id
           #:learn-submission-cell-id
           #:learn-submission-code
           #:learn-submission-status
           #:learn-submission-created-at))

(in-package #:recurya/models/learn-submission)

(deftable learn-submission ()
  ((user-id :col-type :uuid
            :initarg :user-id
            :accessor learn-submission-user-id)
   (notebook-id :col-type (:varchar 64)
                :initarg :notebook-id
                :accessor learn-submission-notebook-id)
   (cell-id :col-type (:varchar 64)
            :initarg :cell-id
            :accessor learn-submission-cell-id)
   (code :col-type :text
         :initarg :code
         :accessor learn-submission-code)
   (status :col-type (:varchar 16)
           :initarg :status
           :accessor learn-submission-status))
  (:keys (user-id notebook-id cell-id))
  (:documentation "Append-only history of code-exercise submissions."))

(defun learn-submission-created-at (row) (mito:object-created-at row))
