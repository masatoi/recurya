;;;; scripts/seed-sicp.lisp --- Idempotent SICP seed for the canonical
;;;; recurya author + SICP course + notebook rows under it.
;;;;
;;;; Phase 10 / T25.
;;;;
;;;; Goal:
;;;;   Ensure that the `+sicp-author-handle+' user (handle = "recurya")
;;;;   exists in the dev/staging database and owns the published-public
;;;;   "sicp" course. The wardlisp redirects introduced in Phase 7C
;;;;   (`/wardlisp/learn` -> `/c/@recurya/sicp', `/wardlisp/learn/:id'
;;;;   -> `/@recurya/:id') depend on this user existing.
;;;;
;;;; Design notes:
;;;;
;;;;   * Idempotent: every step is a "find or create" (or, for the course
;;;;     and existing notebooks, "find or create or correct ownership").
;;;;     Re-running the seed is a no-op once the canonical state is
;;;;     reached, and previously-imported rows authored by some other
;;;;     user are re-pointed to recurya rather than duplicated.
;;;;
;;;;   * Uses only currently-live packages (recurya/db/*, recurya/models/*,
;;;;     recurya/game/notebook-parser, recurya/web/routes for cell->jsonb
;;;;     conversion). Unlike the archived `scripts/archive/import-sicp-to-db.lisp',
;;;;     this script does not touch the long-deleted in-memory notebook
;;;;     registry.
;;;;
;;;;   * Markdown source: docs/sicp/sicp-X-Y-Z.md, the same fixtures used
;;;;     by `tests/integration/sicp-canonical-solutions::load-sicp-fixtures!'.
;;;;
;;;; Usage:
;;;;
;;;;   $ docker compose exec recurya qlot exec ros run \
;;;;       -e '(asdf:load-system :recurya)' \
;;;;       -e '(load "scripts/seed-sicp.lisp")' \
;;;;       -e '(scripts/seed-sicp:seed-sicp!)' \
;;;;       -q
;;;;
;;;; Or interactively from a connected REPL:
;;;;
;;;;   (load "scripts/seed-sicp.lisp")
;;;;   (scripts/seed-sicp:seed-sicp!)

(defpackage #:scripts/seed-sicp
  (:use #:cl)
  (:import-from #:recurya/db/users
                #:get-user-by-email
                #:get-user-by-handle
                #:create-user!)
  (:import-from #:recurya/models/users
                #:users
                #:users-id
                #:users-email
                #:users-handle
                #:users-display-name)
  (:import-from #:recurya/db/courses
                #:create-course!
                #:get-course-by-slug)
  (:import-from #:recurya/models/course
                #:course-id
                #:course-slug
                #:course-status
                #:course-visibility
                #:course-published-at
                #:course-author)
  (:import-from #:recurya/db/notebooks
                #:create-notebook!
                #:get-notebook-by-slug)
  (:import-from #:recurya/models/notebook
                #:notebook-id
                #:notebook-author)
  (:import-from #:recurya/db/course-notebooks
                #:add-notebook-to-course!
                #:list-course-notebooks)
  (:import-from #:recurya/models/course-notebook
                #:course-notebook-notebook
                #:course-notebook-position)
  (:import-from #:recurya/game/notebook-parser
                #:parse-notebook-body)
  (:export #:+sicp-author-email+
           #:+sicp-author-handle+
           #:+sicp-author-display-name+
           #:+sicp-course-slug+
           #:ensure-sicp-author-user
           #:ensure-sicp-course
           #:seed-sicp!))

(in-package #:scripts/seed-sicp)

;;;----------------------------------------------------------------------
;;; Constants
;;;----------------------------------------------------------------------

(defparameter +sicp-author-handle+ "recurya"
  "Handle of the canonical SICP author user. MUST match
   recurya/web/routes:+sicp-author-handle+ used by the wardlisp redirect
   handlers — if these drift, /wardlisp/learn redirects will 404.")

(defparameter +sicp-author-email+ "recurya+sicp@example.invalid"
  "Email address attached to the canonical SICP author user. Uses the
   reserved .invalid TLD so this account cannot ever receive real mail
   or be confused with a real user signup.")

(defparameter +sicp-author-display-name+ "Recurya"
  "Display name shown on the public SICP profile page (/@recurya).")

(defparameter +sicp-course-slug+ "sicp"
  "Slug of the canonical SICP course. The wardlisp redirect targets
   /c/@<handle>/sicp, so this slug MUST be \"sicp\".")

(defparameter +sicp-course-title+ "SICP"
  "Course title for the canonical SICP course.")

(defparameter +sicp-course-summary+
  "Structure and Interpretation of Computer Programs (Japanese, ported to WardLisp)"
  "Course summary used when the SICP course row is first created.")

(defparameter +sicp-markdown-dir+ #P"docs/sicp/"
  "Directory holding the SICP markdown fixtures (sicp-X-Y-Z.md).")

;;;----------------------------------------------------------------------
;;; Slug ordering helpers (reused from the archived importer)
;;;----------------------------------------------------------------------

(defun %parse-sicp-slug-numbers (slug)
  "Return the (CHAPTER SECTION SUBSECTION) integer triple parsed from SLUG.
   SLUG is expected to look like \"sicp-1-2-3\"; returns NIL when SLUG does
   not match the expected pattern."
  (let ((parts (cl-ppcre:split "-" slug)))
    (when (and (= (length parts) 4)
               (string= (first parts) "sicp"))
      (let ((nums (mapcar (lambda (s)
                            (handler-case (parse-integer s)
                              (error () nil)))
                          (rest parts))))
        (when (every #'integerp nums)
          nums)))))

(defun %sicp-slug< (a b)
  "Total order over SICP slugs by (chapter section subsection) numerically.
   Falls back to STRING< when either slug is not a SICP slug."
  (let ((na (%parse-sicp-slug-numbers a))
        (nb (%parse-sicp-slug-numbers b)))
    (cond
      ((and na nb)
       (loop for x in na
             for y in nb
             do (cond ((< x y) (return t))
                      ((> x y) (return nil)))
             finally (return nil)))
      (t (string< a b)))))

(defun %sicp-markdown-files (&optional (dir +sicp-markdown-dir+))
  "Return docs/sicp/*.md pathnames sorted by chapter.section.subsection."
  (let ((files (directory (merge-pathnames "*.md" dir))))
    (sort files #'%sicp-slug< :key #'pathname-name)))

(defun %read-file-string (path)
  "Read PATH into a UTF-8 string."
  (with-open-file (s path :direction :input :external-format :utf-8)
    (with-output-to-string (out)
      (loop for line = (read-line s nil nil)
            while line
            do (write-line line out)))))

(defun %fallback-title (slug)
  "Best-effort human title for SLUG when no other source is available."
  (format nil "SICP ~A" slug))

(defun %cells->jsonb-forms (cells)
  "Convert CELLS (game/notebook-parser output) into JSONB-ready hash-tables
   via the recurya/web/routes helper. Done with FIND-SYMBOL to avoid pulling
   the whole web layer into the seed package's import list."
  (mapcar (lambda (c)
            (funcall (find-symbol (string '#:cell->jsonb-form)
                                  '#:recurya/web/routes)
                     c))
          cells))

;;;----------------------------------------------------------------------
;;; User
;;;----------------------------------------------------------------------

(defun ensure-sicp-author-user ()
  "Ensure the canonical SICP author user exists. Returns the USER DAO.

Lookup order:
  1. By handle (`recurya'). Wins immediately if found.
  2. By the canonical SICP-author email — if such a row exists but is
     using a different handle, it is left alone and the caller gets it
     back as-is so the operator can decide what to do (renaming a handle
     across an existing dataset is out of scope for an automatic seed).
  3. Otherwise create a fresh row with handle = `recurya', email =
     `+sicp-author-email+', display-name = `Recurya'."
  (or (get-user-by-handle +sicp-author-handle+)
      (let ((by-email (get-user-by-email +sicp-author-email+)))
        (cond
          (by-email
           (warn "ensure-sicp-author-user: a user with email ~A already ~
                  exists but its handle is ~S (expected ~S). Leaving the ~
                  row alone; please fix the handle manually."
                 +sicp-author-email+
                 (users-handle by-email)
                 +sicp-author-handle+)
           by-email)
          (t
           (create-user! :email +sicp-author-email+
                         :handle +sicp-author-handle+
                         :display-name +sicp-author-display-name+
                         :role "user"))))))

;;;----------------------------------------------------------------------
;;; Course
;;;----------------------------------------------------------------------

(defun %correct-course-state! (course author)
  "If COURSE exists but its author/status/visibility/published-at deviate
   from the canonical published-public-under-recurya state, mutate the
   row in place to bring it back into compliance. Returns COURSE."
  (let ((dirty nil))
    (let ((current-author (course-author course)))
      (unless (and current-author
                   (equal (princ-to-string (users-id current-author))
                          (princ-to-string (users-id author))))
        (setf (course-author course) author
              dirty t)))
    (unless (string= (course-status course) "published")
      (setf (course-status course) "published"
            dirty t))
    (unless (string= (course-visibility course) "public")
      (setf (course-visibility course) "public"
            dirty t))
    (unless (course-published-at course)
      (setf (course-published-at course) (local-time:now)
            dirty t))
    (when dirty
      (mito:save-dao course)
      (format t "~&[seed-sicp] corrected SICP course state ~
                 (status=published visibility=public author=~A)~%"
              (users-handle author)))
    course))

(defun ensure-sicp-course (author)
  "Return the canonical SICP course DAO, creating it if missing.

If a course with slug = `+sicp-course-slug+' already exists, its author,
status, visibility, and published-at are corrected in place to the
canonical published-public-under-recurya state via `%correct-course-state!'."
  (let ((existing (get-course-by-slug +sicp-course-slug+)))
    (cond
      (existing
       (%correct-course-state! existing author))
      (t
       (let ((c (create-course! :title +sicp-course-title+
                                :slug +sicp-course-slug+
                                :summary +sicp-course-summary+
                                :status "published"
                                :visibility "public"
                                :published-at (local-time:now)
                                :author author)))
         (format t "~&[seed-sicp] created SICP course (id=~A)~%"
                 (princ-to-string (course-id c)))
         c)))))

;;;----------------------------------------------------------------------
;;; Notebooks
;;;----------------------------------------------------------------------

(defun %course-notebook-already-attached-p (course-id-uuid notebook-id-uuid)
  "Return T when (course, notebook) is already in course_notebook."
  (let ((rows (list-course-notebooks course-id-uuid))
        (target (princ-to-string notebook-id-uuid)))
    (some (lambda (cn)
            (let ((nb (course-notebook-notebook cn)))
              (and nb
                   (string= (princ-to-string (notebook-id nb)) target))))
          rows)))

(defun %next-course-position (course-id-uuid)
  "Return the next free POSITION for COURSE-ID-UUID (one past the max)."
  (let ((rows (list-course-notebooks course-id-uuid)))
    (if rows
        (1+ (reduce #'max rows :key #'course-notebook-position))
        0)))

(defun %ensure-notebook-row (slug body-md author)
  "Find or create a notebook row keyed by SLUG, owned by AUTHOR.

Returns (values NB CREATED-P CORRECTED-P) where CREATED-P is T iff the
row was newly inserted, and CORRECTED-P is T iff an existing row's
author was repointed to AUTHOR."
  (let ((existing (get-notebook-by-slug slug)))
    (cond
      (existing
       (let* ((current-author (notebook-author existing))
              (correct-p
                (and current-author
                     (equal (princ-to-string (users-id current-author))
                            (princ-to-string (users-id author))))))
         (cond
           (correct-p
            (values existing nil nil))
           (t
            (setf (notebook-author existing) author)
            (mito:save-dao existing)
            (values existing nil t)))))
      (t
       (multiple-value-bind (cells parse-errors)
           (parse-notebook-body body-md)
         (when parse-errors
           (error "seed-sicp: parse errors in ~A: ~S" slug parse-errors))
         (let* ((cells-jsonb (%cells->jsonb-forms cells))
                (nb (create-notebook! :title (%fallback-title slug)
                                      :slug slug
                                      :body-md body-md
                                      :cells cells-jsonb
                                      :author author
                                      :status "published"
                                      :visibility "public"
                                      :published-at (local-time:now))))
           (values nb t nil)))))))

(defun %ensure-notebooks-attached (course author markdown-dir)
  "Walk MARKDOWN-DIR/*.md and ensure each one is a published-public
   notebook owned by AUTHOR, attached to COURSE in slug-sorted order.

Returns a plist summarising the run:
  :imported      slugs newly inserted as user_notebook rows
  :corrected     slugs whose author was repointed to AUTHOR
  :skipped       slugs already present and correctly owned
  :attached      slugs newly attached to COURSE
  :already-attached
                 slugs already attached to COURSE"
  (let ((course-id-uuid (course-id course))
        (imported nil)
        (corrected nil)
        (skipped nil)
        (attached nil)
        (already-attached nil))
    (dolist (path (%sicp-markdown-files markdown-dir))
      (let* ((slug (pathname-name path))
             (body-md (%read-file-string path)))
        (multiple-value-bind (nb created-p corrected-p)
            (%ensure-notebook-row slug body-md author)
          (cond
            (created-p
             (push slug imported)
             (format t "~&[seed-sicp] imported notebook ~A~%" slug))
            (corrected-p
             (push slug corrected)
             (format t "~&[seed-sicp] corrected author for notebook ~A~%"
                     slug))
            (t
             (push slug skipped)))
          (let ((nb-uuid (notebook-id nb)))
            (cond
              ((%course-notebook-already-attached-p course-id-uuid nb-uuid)
               (push slug already-attached))
              (t
               (add-notebook-to-course!
                course-id-uuid nb-uuid
                :position (%next-course-position course-id-uuid))
               (push slug attached)
               (format t "~&[seed-sicp] attached ~A to course ~A~%"
                       slug +sicp-course-slug+)))))))
    (list :imported (nreverse imported)
          :corrected (nreverse corrected)
          :skipped (nreverse skipped)
          :attached (nreverse attached)
          :already-attached (nreverse already-attached))))

;;;----------------------------------------------------------------------
;;; Entry point
;;;----------------------------------------------------------------------

(defun seed-sicp! (&key (markdown-dir +sicp-markdown-dir+)
                        (attach-notebooks t))
  "Idempotently seed the canonical SICP author + course (+ notebooks).

Parameters:
  MARKDOWN-DIR     Directory holding SICP markdown fixtures.
                   Defaults to docs/sicp/. Pass NIL only if you know
                   what you are doing.
  ATTACH-NOTEBOOKS If true (default), also walk MARKDOWN-DIR and ensure
                   each fixture is a published-public notebook owned by
                   the SICP author, attached to the SICP course. If
                   false, only the user and course rows are seeded.

Returns a plist summarising the run:
  :user-handle   handle of the canonical SICP author
  :user-id       UUID string of the canonical SICP author
  :course-id     UUID string of the canonical SICP course
  :course-slug   slug of the canonical SICP course
  :notebooks     plist of notebook-import counts (only when
                 ATTACH-NOTEBOOKS is non-nil)

Idempotent: re-running on a clean state is a no-op."
  (let* ((author (ensure-sicp-author-user))
         (course (ensure-sicp-course author))
         (notebooks-summary
           (when attach-notebooks
             (%ensure-notebooks-attached course author markdown-dir))))
    (format t "~&[seed-sicp] done. user=@~A course=~A~%"
            (users-handle author)
            (princ-to-string (course-id course)))
    (list :user-handle (users-handle author)
          :user-id (princ-to-string (users-id author))
          :course-id (princ-to-string (course-id course))
          :course-slug (course-slug course)
          :notebooks notebooks-summary)))
