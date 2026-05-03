;;;; utils/access-control.lisp --- Centralised viewability rules.

(defpackage #:recurya/utils/access-control
  (:use #:cl)
  (:import-from #:recurya/db/user-notebooks
                #:user-notebook-status
                #:user-notebook-visibility
                #:user-notebook-author-id)
  (:import-from #:recurya/db/courses
                #:course-status
                #:course-visibility
                #:course-author-id)
  (:export #:can-view-notebook-p
           #:can-view-course-p
           #:publicly-listable-notebook-p
           #:publicly-listable-course-p))

(in-package #:recurya/utils/access-control)

(defun can-view-notebook-p (user notebook)
  (declare (ignore user notebook))
  (error "not implemented"))

(defun can-view-course-p (user course)
  (declare (ignore user course))
  (error "not implemented"))

(defun publicly-listable-notebook-p (notebook)
  (declare (ignore notebook))
  (error "not implemented"))

(defun publicly-listable-course-p (course)
  (declare (ignore course))
  (error "not implemented"))
