;;;; models/learn-cell-code.lisp --- Mito table for last-saved cell code.

(defpackage #:recurya/models/learn-cell-code
  (:use #:cl #:mito)
  (:export #:learn-cell-code
           #:learn-cell-code-user-id
           #:learn-cell-code-notebook-id
           #:learn-cell-code-cell-id
           #:learn-cell-code-code
           #:learn-cell-code-created-at
           #:learn-cell-code-updated-at))

(in-package #:recurya/models/learn-cell-code)

(deftable learn-cell-code ()
  ((user-id :col-type :uuid
            :initarg :user-id
            :accessor learn-cell-code-user-id)
   (notebook-id :col-type (:varchar 64)
                :initarg :notebook-id
                :accessor learn-cell-code-notebook-id)
   (cell-id :col-type (:varchar 64)
            :initarg :cell-id
            :accessor learn-cell-code-cell-id)
   (code :col-type :text
         :initarg :code
         :accessor learn-cell-code-code))
  (:unique-keys (user-id notebook-id cell-id))
  (:keys (user-id notebook-id))
  (:documentation "Per-user last code submitted for a notebook cell."))

(defun learn-cell-code-created-at (row) (mito:object-created-at row))
(defun learn-cell-code-updated-at (row) (mito:object-updated-at row))
