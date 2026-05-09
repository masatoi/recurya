;;;; models/course.lisp --- Course (collection of user_notebook).

(defpackage #:recurya/models/course
  (:use #:cl #:mito)
  (:import-from #:recurya/models/users #:users #:users-id)
  (:export #:course
           #:course-id
           #:course-slug
           #:course-title
           #:course-summary
           #:course-status
           #:course-visibility
           #:course-published-at
           #:course-author
           #:course-author-id
           #:course-created-at
           #:course-updated-at))

(in-package #:recurya/models/course)

(deftable course ()
  ((id :col-type :uuid :initarg :id :accessor %course-id :primary-key t)
   (slug :col-type (:varchar 255) :initarg :slug :accessor course-slug)
   (title :col-type (:varchar 255) :initarg :title :accessor course-title)
   (summary :col-type (or (:varchar 500) :null)
            :initarg :summary :initform nil :accessor course-summary)
   (status :col-type (:varchar 32) :initarg :status :initform "draft"
           :accessor course-status)
   (visibility :col-type (:varchar 32) :initarg :visibility
               :initform "private" :accessor course-visibility)
   (published-at :col-type (or :timestamptz :null)
                 :initarg :published-at :initform nil
                 :accessor course-published-at)
   (author :col-type users :initarg :author :accessor course-author))
  (:auto-pk nil)
  (:unique-keys (author_id slug))
  (:keys (status :created_at)
         (author_id :created_at)
         (visibility :status))
  (:documentation "A learning course bundling user_notebook items in order."))

(defun course-id (c) (%course-id c))

(defun course-author-id (c)
  (let ((u (course-author c))) (when u (users-id u))))

(defun course-created-at (c) (mito:object-created-at c))
(defun course-updated-at (c) (mito:object-updated-at c))
