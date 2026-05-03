;;;; models/user-notebook.lisp --- Mito ORM table definition for user-authored notebooks.
;;;;
;;;; Defines the `user_notebook` table with UUID primary key, slug, title,
;;;; summary, body markdown, parsed cells (JSONB cache), draft/published
;;;; status, and a foreign-key reference to the users table via author.

(defpackage #:recurya/models/user-notebook
  (:use #:cl
        #:mito)
  (:import-from #:recurya/models/users
                #:users
                #:users-id)
  (:export #:user-notebook
           #:user-notebook-id
           #:user-notebook-slug
           #:user-notebook-title
           #:user-notebook-summary
           #:user-notebook-body-md
           #:user-notebook-cells
           #:user-notebook-status
           #:user-notebook-published-at
           #:user-notebook-author
           #:user-notebook-author-id
           #:user-notebook-created-at
           #:user-notebook-updated-at))

(in-package #:recurya/models/user-notebook)

(deftable user-notebook ()
  ((id :col-type :uuid
       :initarg :id
       :accessor %user-notebook-id
       :primary-key t)
   (slug :col-type (:varchar 255)
         :initarg :slug
         :accessor user-notebook-slug)
   (title :col-type (:varchar 255)
          :initarg :title
          :accessor user-notebook-title)
   (summary :col-type (or (:varchar 500) :null)
            :initarg :summary
            :initform nil
            :accessor user-notebook-summary)
   (body-md :col-type :text
            :initarg :body-md
            :accessor user-notebook-body-md)
   (cells :col-type :jsonb
          :initarg :cells
          :accessor user-notebook-cells)
   (status :col-type (:varchar 32)
           :initarg :status
           :initform "draft"
           :accessor user-notebook-status)
   (published-at :col-type (or :timestamptz :null)
                 :initarg :published-at
                 :initform nil
                 :accessor user-notebook-published-at)
   (author :col-type users
           :initarg :author
           :accessor user-notebook-author))
  (:auto-pk nil)
  (:unique-keys slug)
  (:keys (status :created_at) (author_id :created_at))
  (:documentation "User-authored notebook with UUID PK, slug URLs, JSONB cell cache, and draft/published workflow."))

(defun user-notebook-id (nb)
  "Return the UUID primary key for NB."
  (%user-notebook-id nb))

(defun user-notebook-author-id (nb)
  "Return the author user UUID, or NIL."
  (let ((u (user-notebook-author nb)))
    (when u (users-id u))))

(defun user-notebook-created-at (nb)
  "Return the creation timestamp for NB."
  (mito:object-created-at nb))

(defun user-notebook-updated-at (nb)
  "Return the last-updated timestamp for NB."
  (mito:object-updated-at nb))
