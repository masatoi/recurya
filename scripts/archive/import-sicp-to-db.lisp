;;;; scripts/import-sicp-to-db.lisp --- Import SICP markdown fixtures into the
;;;; notebook / course / course-notebook tables.
;;;;
;;;; Usage (from the REPL after loading recurya and a configured DB):
;;;;   (load "scripts/import-sicp-to-db.lisp")
;;;;   (scripts/import-sicp-to-db:import-sicp-to-db!)
;;;;
;;;; What this does:
;;;;   1. Find-or-create an admin user (idempotent via OAuth-style lookup).
;;;;   2. Find-or-create the "SICP" course (slug "sicp").
;;;;   3. For every docs/sicp/*.md file, sorted in chapter.section.subsection
;;;;      order:
;;;;        - Read the body markdown.
;;;;        - parse-notebook-body to obtain cells (must have no errors).
;;;;        - Convert cells to JSONB-ready hash-tables via
;;;;          recurya/web/routes::cell->jsonb-form.
;;;;        - Look up the title from the in-memory notebook registry by
;;;;          slug -> keyword id; fallback to a slug-derived title.
;;;;        - create-notebook! (idempotent: skip if slug exists).
;;;;        - add-notebook-to-course! at the next free position
;;;;          (idempotent: skip if join row already exists).
;;;;   4. Migrate any pre-existing learn_* rows that referenced the old
;;;;      sicp-X-Y-Z slug strings as notebook_id over to the freshly
;;;;      assigned UUID strings (UPDATE only matches sicp-% slugs, so it is
;;;;      safe to run repeatedly and a no-op when learn_* is empty).
;;;;
;;;; Make-everything-idempotent contract: re-running this function on a DB
;;;; that already has SICP imported MUST NOT raise, MUST NOT duplicate any
;;;; rows, and MUST NOT mutate existing user_notebook bodies.

(defpackage #:scripts/import-sicp-to-db
  (:use #:cl)
  (:import-from #:recurya/db/users
                #:find-or-create-oauth-user
                #:get-user-by-email)
  (:import-from #:recurya/db/courses #:create-course! #:get-course-by-slug)
  (:import-from #:recurya/db/notebooks
                #:create-notebook!
                #:get-notebook-by-slug)
  (:import-from #:recurya/db/course-notebooks
                #:add-notebook-to-course!
                #:list-course-notebooks)
  (:import-from #:recurya/db/core #:execute!)
  ;; Note: recurya/models/notebook:notebook-id collides with
  ;; recurya/game/notebook:notebook-id (struct accessor for the in-memory
  ;; notebook used by the parser). We import the DB accessor here and
  ;; reference the game accessor via package qualification below.
  (:import-from #:recurya/models/notebook #:notebook-id)
  (:import-from #:recurya/models/course #:course-id)
  (:import-from #:recurya/models/course-notebook #:course-notebook-notebook)
  (:import-from #:recurya/game/notebook-parser #:parse-notebook-body)
  (:import-from #:recurya/game/notebooks/registry #:all-notebooks)
  (:export #:import-sicp-to-db! #:migrate-learn-tables-for-sicp!))

(in-package #:scripts/import-sicp-to-db)

;;; ---------------------------------------------------------------------------
;;; Slug ordering: chapter.section.subsection
;;; ---------------------------------------------------------------------------

(defun parse-sicp-slug-numbers (slug)
  "Return the (CHAPTER SECTION SUBSECTION) integer triple parsed from SLUG.
   SLUG is expected to look like \"sicp-1-2-3\"; returns NIL when SLUG does
   not match the expected pattern."
  (let ((parts (cl-ppcre:split "-" slug)))
    ;; parts looks like ("sicp" "1" "2" "3").
    (when (and (= (length parts) 4)
               (string= (first parts) "sicp"))
      (let ((nums (mapcar (lambda (s)
                            (handler-case (parse-integer s)
                              (error () nil)))
                          (rest parts))))
        (when (every #'integerp nums)
          nums)))))

(defun sicp-slug< (a b)
  "Total order over SICP slugs by (chapter section subsection) numerically.
   Falls back to STRING< when either slug is not a SICP slug."
  (let ((na (parse-sicp-slug-numbers a))
        (nb (parse-sicp-slug-numbers b)))
    (cond
      ((and na nb)
       (loop for x in na for y in nb
             do (cond ((< x y) (return t))
                      ((> x y) (return nil)))
             finally (return nil)))
      (t (string< a b)))))

;;; ---------------------------------------------------------------------------
;;; Helpers
;;; ---------------------------------------------------------------------------

(defun slug-from-pathname (p)
  "Return the basename without extension (\"sicp-1-1-1\") for pathname P."
  (pathname-name p))

(defun list-sicp-markdown-files (&optional (dir #P"docs/sicp/"))
  "Return docs/sicp/*.md files sorted by their slug ordering."
  (let ((files (directory (merge-pathnames "*.md" dir))))
    (sort files #'sicp-slug< :key #'slug-from-pathname)))

(defun read-file-string (path)
  "Read PATH into a string."
  (with-open-file (s path :direction :input
                          :external-format :utf-8)
    (with-output-to-string (out)
      (loop for line = (read-line s nil nil)
            while line
            do (write-line line out)))))

(defun build-slug->title-map ()
  "Walk the in-memory notebook registry and return an EQUAL hash-table
   mapping slug strings (e.g., \"sicp-1-1-1\") to their notebook titles."
  (let ((map (make-hash-table :test 'equal)))
    (dolist (nb (all-notebooks))
      (let ((id (recurya/game/notebook:notebook-id nb)))
        (when id
          (let ((slug
                 (cond ((keywordp id) (string-downcase (symbol-name id)))
                       ((stringp id) (string-downcase id)) (t nil))))
            (when slug
              (setf (gethash slug map)
                    (recurya/game/notebook:notebook-title nb)))))))
    map))

(defun fallback-title-from-slug (slug)
  "Best-effort title when the registry has no entry for SLUG."
  (format nil "SICP ~A" slug))

(defun cells->jsonb-forms (cells)
  "Convert CELLS to JSONB-ready hash-tables via the routes helper."
  (mapcar (lambda (c)
            (funcall (find-symbol (string '#:cell->jsonb-form)
                                  '#:recurya/web/routes)
                     c))
          cells))

(defun ensure-admin-user (admin-email)
  "Return the admin USER instance, creating one idempotently if missing.
   Reuses any existing user with the same email."
  (or (get-user-by-email admin-email)
      (find-or-create-oauth-user
       :provider "bootstrap"
       :provider-uid "sicp-import"
       :email admin-email
       :display-name "SICP Import"
       :role "admin")))

(defun ensure-sicp-course (admin-dao)
  "Return the \"sicp\" course DAO, creating it idempotently if missing."
  (or (get-course-by-slug "sicp")
      (create-course!
       :title "SICP"
       :slug "sicp"
       :summary
       "Structure and Interpretation of Computer Programs (Japanese, ported to WardLisp)"
       :status "published"
       :published-at (local-time:now)
       :author admin-dao)))

(defun course-notebook-already-attached-p (course-id-uuid notebook-id-uuid)
  "Return T when the (course, notebook) join row already exists."
  (let ((rows (list-course-notebooks course-id-uuid))
        (target (princ-to-string notebook-id-uuid)))
    (some (lambda (cn)
            (let ((nb (course-notebook-notebook cn)))
              (and nb
                   (string= (princ-to-string (notebook-id nb)) target))))
          rows)))

(defun next-course-position (course-id-uuid)
  "Return the next free POSITION for the SICP course (one past the max)."
  (let ((rows (list-course-notebooks course-id-uuid)))
    (if rows
        (1+ (reduce #'max rows
                    :key (find-symbol
                          (string '#:course-notebook-position)
                          '#:recurya/models/course-notebook)))
        0)))

;;; ---------------------------------------------------------------------------
;;; learn_* migration: old slug -> new UUID string
;;; ---------------------------------------------------------------------------

(defun migrate-learn-tables-for-sicp! ()
  "Update learn_progress / learn_cell_code / learn_submission rows whose
   notebook_id still references the old sicp-X-Y-Z slug, replacing it with
   the freshly assigned UUID string from user_notebook.id::text. Idempotent:
   only rows where notebook_id LIKE 'sicp-%' are touched, so re-running
   after a successful migration is a no-op."
  (let ((updates
         '(("learn_cell_code"  . "UPDATE learn_cell_code lcc
                                    SET notebook_id = un.id::text
                                  FROM user_notebook un
                                  WHERE un.slug = lcc.notebook_id
                                    AND un.slug LIKE 'sicp-%'")
           ("learn_progress"   . "UPDATE learn_progress lp
                                    SET notebook_id = un.id::text
                                  FROM user_notebook un
                                  WHERE un.slug = lp.notebook_id
                                    AND un.slug LIKE 'sicp-%'")
           ("learn_submission" . "UPDATE learn_submission ls
                                    SET notebook_id = un.id::text
                                  FROM user_notebook un
                                  WHERE un.slug = ls.notebook_id
                                    AND un.slug LIKE 'sicp-%'"))))
    (dolist (entry updates)
      (let ((table (car entry))
            (sql (cdr entry)))
        (format t "~&[migrate-learn-tables] ~A~%" table)
        (execute! sql)))))

;;; ---------------------------------------------------------------------------
;;; Main entry point
;;; ---------------------------------------------------------------------------

(defun import-sicp-to-db!
    (&key (admin-email "admin@recurya.dev")
          (markdown-dir #P"docs/sicp/"))
  "Idempotently import every SICP markdown fixture under MARKDOWN-DIR
   into the user_notebook / course / course_notebook tables, then migrate
   any existing learn_* rows that reference the old slug-based notebook_id.

   Returns a plist summarising the run:
     :course-id      UUID string of the SICP course
     :imported       slugs newly inserted as user_notebook rows
     :skipped        slugs that already existed and were left alone
     :attached       slugs newly attached to the SICP course
     :already-attached
                     slugs already attached to the SICP course"
  (let* ((admin (ensure-admin-user admin-email))
         (course (ensure-sicp-course admin))
         (course-id-uuid (course-id course))
         (slug->title (build-slug->title-map))
         (files (list-sicp-markdown-files markdown-dir))
         (imported '())
         (skipped '())
         (attached '())
         (already-attached '()))
    (format t "~&[import-sicp-to-db] admin=~A course=~A files=~D~%"
            admin-email (princ-to-string course-id-uuid) (length files))
    (dolist (path files)
      (let* ((slug (slug-from-pathname path))
             (body-md (read-file-string path))
             (existing (get-notebook-by-slug slug)))
        (cond
          (existing
           (push slug skipped)
           (format t "~&[skip] ~A (user_notebook already present)~%" slug))
          (t
           (multiple-value-bind (cells parse-errors)
               (parse-notebook-body body-md)
             (when parse-errors
               (error "import-sicp-to-db!: parse errors in ~A: ~S"
                      slug parse-errors))
             (let* ((title (or (gethash slug slug->title)
                               (fallback-title-from-slug slug)))
                    (cells-jsonb (cells->jsonb-forms cells))
                    (nb (create-notebook!
                         :title title
                         :slug slug
                         :body-md body-md
                         :cells cells-jsonb
                         :author admin
                         :status "published"
                         :published-at (local-time:now))))
               (declare (ignore nb))
               (push slug imported)
               (format t "~&[import] ~A (~A cells, ~A)~%"
                       slug (length cells) title)))))
        ;; Attach to course (idempotent).
        (let* ((nb-row (or (get-notebook-by-slug slug)
                           (error "import-sicp-to-db!: notebook missing after import: ~A"
                                  slug)))
               (nb-uuid (notebook-id nb-row)))
          (cond
            ((course-notebook-already-attached-p course-id-uuid nb-uuid)
             (push slug already-attached))
            (t
             (add-notebook-to-course!
              course-id-uuid nb-uuid
              :position (next-course-position course-id-uuid))
             (push slug attached))))))
    (migrate-learn-tables-for-sicp!)
    (format t "~&[import-sicp-to-db] done: imported=~D skipped=~D attached=~D already-attached=~D~%"
            (length imported) (length skipped)
            (length attached) (length already-attached))
    (list :course-id (princ-to-string course-id-uuid)
          :imported (nreverse imported)
          :skipped (nreverse skipped)
          :attached (nreverse attached)
          :already-attached (nreverse already-attached))))
