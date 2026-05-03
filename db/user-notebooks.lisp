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
  (:import-from #:recurya/db/jsonb #:lisp->jsonb #:jsonb->lisp)
  (:import-from #:recurya/models/user-notebook
                #:user-notebook
                #:user-notebook-id
                #:user-notebook-slug
                #:user-notebook-title
                #:user-notebook-summary
                #:user-notebook-body-md
                #:user-notebook-cells
                #:user-notebook-status
                #:user-notebook-visibility
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
           #:user-notebook-visibility
           #:user-notebook-published-at
           #:user-notebook-author
           #:user-notebook-author-id
           #:user-notebook-created-at
           #:user-notebook-updated-at
           #:create-user-notebook!
           #:get-user-notebook-by-id
           #:get-user-notebook-by-slug
           #:update-user-notebook!
           #:delete-user-notebook!
           #:list-user-notebooks
           #:count-user-notebooks
           #:user-notebook-cells-parsed))

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

(defun list-user-notebooks (&key status author-id (limit 50) offset)
  "List user-notebooks, optionally filtered by status and/or author, newest first.

Arguments:
  STATUS    - Filter by status string (optional)
  AUTHOR-ID - Filter by author UUID (optional)
  LIMIT     - Maximum results (default: 50)
  OFFSET    - Number to skip (optional)

Returns:
  List of USER-NOTEBOOK instances."
  (let ((all
          (cond
            ((and status author-id)
             (select-dao 'user-notebook
               (where (:and (:= :status status) (:= :author_id author-id)))
               (order-by (:desc :created-at))))
            (status
             (select-dao 'user-notebook
               (where (:= :status status))
               (order-by (:desc :created-at))))
            (author-id
             (select-dao 'user-notebook
               (where (:= :author_id author-id))
               (order-by (:desc :created-at))))
            (t
             (select-dao 'user-notebook
               (order-by (:desc :created-at)))))))
    (cond
      ((and offset limit)
       (subseq all (min offset (length all))
               (min (+ offset limit) (length all))))
      (limit (subseq all 0 (min limit (length all))))
      (offset (subseq all (min offset (length all))))
      (t all))))

(defun count-user-notebooks (&key status author-id)
  "Count user-notebooks, optionally filtered by status and/or author.

Returns:
  Integer count."
  (let ((conditions nil)
        (binds nil))
    (when status
      (push "status = ?" conditions)
      (push status binds))
    (when author-id
      (push "author_id = ?" conditions)
      (push (princ-to-string author-id) binds))
    (let* ((where-clause
             (if conditions
                 (format nil " WHERE ~{~A~^ AND ~}" (nreverse conditions))
                 ""))
           (sql (concatenate 'string
                             "SELECT COUNT(*) as count FROM user_notebook"
                             where-clause))
           (binds (nreverse binds)))
      (let ((result (mito.db:retrieve-by-sql sql :binds binds)))
        (if result
            (getf (first result) :count)
            0)))))

(defun user-notebook-cells-parsed (nb)
  "Return the cells JSONB column of NB parsed back to Lisp data.
JSON arrays come back as vectors; JSON objects as hash-tables."
  (jsonb->lisp (user-notebook-cells nb)))
