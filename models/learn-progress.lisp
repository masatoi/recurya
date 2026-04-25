;;;; models/learn-progress.lisp --- Mito table for cell pass status.

(defpackage #:recurya/models/learn-progress
  (:use #:cl #:mito)
  (:export #:learn-progress
           #:learn-progress-user-id
           #:learn-progress-notebook-id
           #:learn-progress-cell-id
           #:learn-progress-passed-at
           #:learn-progress-created-at
           #:learn-progress-updated-at))

(in-package #:recurya/models/learn-progress)

(deftable learn-progress ()
  ((user-id :col-type :uuid
            :initarg :user-id
            :accessor learn-progress-user-id)
   (notebook-id :col-type (:varchar 64)
                :initarg :notebook-id
                :accessor learn-progress-notebook-id)
   (cell-id :col-type (:varchar 64)
            :initarg :cell-id
            :accessor learn-progress-cell-id)
   (passed-at :col-type :timestamptz
              :initarg :passed-at
              :accessor learn-progress-passed-at))
  (:unique-keys (user-id notebook-id cell-id))
  (:keys (user-id notebook-id))
  (:documentation "Per-user pass record for a notebook cell. Existence = passed."))

(defun learn-progress-created-at (row) (mito:object-created-at row))
(defun learn-progress-updated-at (row) (mito:object-updated-at row))
