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
           #:get-user-notebook-by-slug))

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
