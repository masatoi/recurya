;;;; models/notebook.lisp --- Mito ORM table definition for user-authored notebooks.
;;;;
;;;; Defines the `user_notebook` table with UUID primary key, slug, title,
;;;; summary, body markdown, parsed cells (JSONB cache), draft/published
;;;; status, and a foreign-key reference to the users table via author.

(defpackage #:recurya/models/notebook
  (:use #:cl
        #:mito)
  (:import-from #:recurya/models/users
                #:users
                #:users-id)
  (:export #:notebook
           #:notebook-id
           #:notebook-slug
           #:notebook-title
           #:notebook-summary
           #:notebook-body-md
           #:notebook-cells
           #:notebook-status
           #:notebook-visibility
           #:notebook-published-at
           #:notebook-author
           #:notebook-author-id
           #:notebook-created-at
           #:notebook-updated-at))

(in-package #:recurya/models/notebook)

(deftable notebook ()
  ((id :col-type :uuid
       :initarg :id
       :accessor %notebook-id
       :primary-key t)
   (slug :col-type (:varchar 255)
         :initarg :slug
         :accessor notebook-slug)
   (title :col-type (:varchar 255)
          :initarg :title
          :accessor notebook-title)
   (summary :col-type (or (:varchar 500) :null)
            :initarg :summary
            :initform nil
            :accessor notebook-summary)
   (body-md :col-type :text
            :initarg :body-md
            :accessor notebook-body-md)
   (cells :col-type :jsonb
          :initarg :cells
          :accessor notebook-cells)
   (status :col-type (:varchar 32)
           :initarg :status
           :initform "draft"
           :accessor notebook-status)
   (visibility :col-type (:varchar 32)
               :initarg :visibility
               :initform "private"
               :accessor notebook-visibility)
   (published-at :col-type (or :timestamptz :null)
                 :initarg :published-at
                 :initform nil
                 :accessor notebook-published-at)
   (author :col-type users
           :initarg :author
           :accessor notebook-author))
  (:auto-pk nil)
  (:unique-keys (author_id slug))
  (:keys (status :created_at)
         (author_id :created_at)
         (visibility :status))
  (:documentation "User-authored notebook with UUID PK, slug URLs, JSONB cell cache, and draft/published workflow."))

(defun notebook-id (nb)
  "Return the UUID primary key for NB."
  (%notebook-id nb))

(defun notebook-author-id (nb)
  "Return the author user UUID, or NIL."
  (let ((u (notebook-author nb)))
    (when u (users-id u))))

(defun notebook-created-at (nb)
  "Return the creation timestamp for NB."
  (mito:object-created-at nb))

(defun notebook-updated-at (nb)
  "Return the last-updated timestamp for NB."
  (mito:object-updated-at nb))
