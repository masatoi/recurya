;;;; models/course-notebook.lisp --- Many-to-many join: course <-> user_notebook.

(defpackage #:recurya/models/course-notebook
  (:use #:cl #:mito)
  (:import-from #:recurya/models/course #:course #:course-id)
  (:import-from #:recurya/models/notebook #:notebook #:notebook-id)
  (:export #:course-notebook
           #:course-notebook-id
           #:course-notebook-course
           #:course-notebook-course-id
           #:course-notebook-notebook
           #:course-notebook-notebook-id
           #:course-notebook-position))

(in-package #:recurya/models/course-notebook)

(deftable course-notebook ()
  ((course :col-type course :initarg :course :accessor course-notebook-course)
   (notebook :col-type notebook :initarg :notebook
             :accessor course-notebook-notebook)
   (position :col-type :integer :initarg :position
             :accessor course-notebook-position))
  (:unique-keys (course_id notebook_id))
  (:keys (course_id position))
  (:documentation "Join row mapping a notebook to a course at a given position."))

(defun course-notebook-id (cn) (mito:object-id cn))

(defun course-notebook-course-id (cn)
  (let ((c (course-notebook-course cn))) (when c (course-id c))))

(defun course-notebook-notebook-id (cn)
  (let ((n (course-notebook-notebook cn))) (when n (notebook-id n))))
