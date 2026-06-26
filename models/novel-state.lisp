;;;; models/novel-state.lisp --- Per-reader novel progress (flags + position).
(defpackage #:recurya/models/novel-state
  (:use #:cl #:mito)
  (:export #:novel-state
           #:novel-state-user-id
           #:novel-state-notebook-id
           #:novel-state-flags
           #:novel-state-scene-index
           #:novel-state-created-at
           #:novel-state-updated-at))

(in-package #:recurya/models/novel-state)

(deftable novel-state ()
  ((user-id :col-type :uuid :initarg :user-id :accessor novel-state-user-id)
   (notebook-id :col-type (:varchar 64) :initarg :notebook-id
                :accessor novel-state-notebook-id)
   (flags :col-type :text :initarg :flags :initform "{}"
          :accessor novel-state-flags)              ; JSON object string
   (scene-index :col-type :integer :initarg :scene-index :initform 0
                :accessor novel-state-scene-index))
  (:unique-keys (user-id notebook-id))
  (:keys (user-id notebook-id))
  (:documentation "Per-(user, notebook) novel playthrough state."))

(defun novel-state-created-at (row) (mito:object-created-at row))
(defun novel-state-updated-at (row) (mito:object-updated-at row))
