;;;; db/user-notebooks.lisp --- CRUD operations for user-authored notebooks.

(defpackage #:recurya/db/user-notebooks
  (:use #:cl)
  (:import-from #:mito
                #:find-dao
                #:select-dao
                #:insert-dao
                #:save-dao
                #:delete-dao)
  (:import-from #:sxql #:where #:order-by #:limit)
  (:import-from #:recurya/db/core #:generate-uuid #:ensure-uuid)
  (:import-from #:recurya/db/posts #:slugify)
  (:import-from #:recurya/db/jsonb #:lisp->jsonb)
  (:import-from #:recurya/models/user-notebook
                #:user-notebook
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
                #:user-notebook-updated-at)
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
           #:user-notebook-updated-at
           #:create-user-notebook!
           #:get-user-notebook-by-id
           #:get-user-notebook-by-slug
           #:update-user-notebook!
           #:delete-user-notebook!))

(in-package #:recurya/db/user-notebooks)

(defun create-user-notebook!
    (&key title body-md cells slug summary
       (status "draft") published-at author notebook-id)
  "Create a new user-authored notebook and return the created instance.

Arguments:
  TITLE         - Notebook title (required)
  BODY-MD       - Body markdown text with cell fences (required)
  CELLS         - Parsed cell list serialized to JSONB (required; '() becomes \"[]\")
  SLUG          - URL slug (auto-generated from title if omitted)
  SUMMARY       - Short summary, max 500 chars (optional)
  STATUS        - \"draft\" or \"published\" (default: \"draft\")
  PUBLISHED-AT  - Timestamp when published (optional)
  AUTHOR        - Users instance (required, FK is NOT NULL)
  NOTEBOOK-ID   - Pre-generated UUID (optional)

Returns:
  The newly created USER-NOTEBOOK instance."
  (let ((id (or notebook-id (generate-uuid)))
        (slug (or slug (slugify title)))
        (cells-json (if (null cells) "[]" (lisp->jsonb cells))))
    (insert-dao
     (make-instance 'user-notebook
                    :id id
                    :slug slug
                    :title title
                    :summary summary
                    :body-md body-md
                    :cells cells-json
                    :status status
                    :published-at published-at
                    :author author))))

(defun get-user-notebook-by-id (id)
  "Fetch a user-notebook by UUID.

Returns:
  USER-NOTEBOOK instance if found, NIL otherwise."
  (find-dao 'user-notebook :id (ensure-uuid id)))

(defun get-user-notebook-by-slug (slug)
  "Fetch a user-notebook by slug.

Returns:
  USER-NOTEBOOK instance if found, NIL otherwise."
  (find-dao 'user-notebook :slug slug))

(defun update-user-notebook! (notebook-id &key title slug summary body-md cells
                                            status published-at)
  "Update user-notebook attributes. Only provided fields are updated.

CELLS, when provided, is JSON-serialized via lisp->jsonb before write
(an empty list serializes to \"[]\").

Returns:
  The updated USER-NOTEBOOK instance, or NIL if not found."
  (let ((nb (find-dao 'user-notebook :id (ensure-uuid notebook-id))))
    (when nb
      (when title (setf (user-notebook-title nb) title))
      (when slug (setf (user-notebook-slug nb) slug))
      (when summary (setf (user-notebook-summary nb) summary))
      (when body-md (setf (user-notebook-body-md nb) body-md))
      (when cells
        (setf (user-notebook-cells nb)
              (if (null cells) "[]" (lisp->jsonb cells))))
      (when status (setf (user-notebook-status nb) status))
      (when published-at (setf (user-notebook-published-at nb) published-at))
      (save-dao nb))
    nb))

(defun delete-user-notebook! (notebook-id)
  "Delete a user-notebook by UUID.

Returns:
  T if deleted, NIL if not found."
  (let ((nb (find-dao 'user-notebook :id (ensure-uuid notebook-id))))
    (when nb (delete-dao nb) t)))
