;;;; seed/official-content.lisp --- Generic, idempotent seeding of
;;;; first-party ("official") courses from a declarative registry.
;;;;
;;;; Each entry in *official-courses* describes one official course: its
;;;; canonical author, course metadata, and a directory of markdown
;;;; notebook fixtures. seed-official-content! walks the registry and,
;;;; for each course, ensures the author user, the published-public
;;;; course, and the ordered notebooks all exist (find-or-create-or-
;;;; correct). It is idempotent and safe to run on every boot.
;;;;
;;;; SICP is simply the first registry entry. Adding a new official
;;;; course = add an official-course entry + drop its markdown directory.

(defpackage #:recurya/seed/official-content
  (:use #:cl)
  (:import-from #:recurya/db/users
                #:get-user-by-email
                #:get-user-by-handle
                #:create-user!)
  (:import-from #:recurya/models/users
                #:users-id
                #:users-handle)
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
  (:import-from #:recurya/game/notebook-jsonb
                #:cell->jsonb-form)
  (:import-from #:mito
                #:save-dao)
  (:export #:official-course
           #:make-official-course
           #:official-course-author-handle
           #:official-course-author-email
           #:official-course-author-display-name
           #:official-course-slug
           #:official-course-title
           #:official-course-summary
           #:official-course-content-dir
           #:official-course-order
           #:official-course-notebook-title-fn
           #:*official-courses*
           #:ensure-official-author
           #:ensure-official-course
           #:ensure-notebooks-attached
           #:seed-course!
           #:seed-official-content!))

(in-package #:recurya/seed/official-content)

;;;----------------------------------------------------------------------
;;; Data model
;;;----------------------------------------------------------------------

(defstruct official-course
  "Declarative description of one first-party (official) course."
  author-handle author-email author-display-name
  slug title summary
  content-dir                              ; system-relative pathname
  (order :natural)                         ; :natural | list of slugs
  (notebook-title-fn (lambda (slug) slug)))

;;;----------------------------------------------------------------------
;;; Registry
;;;----------------------------------------------------------------------

(defparameter *official-courses*
  (list
   (make-official-course
    :author-handle "recurya"
    :author-email "recurya+sicp@example.invalid"
    :author-display-name "Recurya"
    :slug "sicp"
    :title "SICP"
    :summary "Structure and Interpretation of Computer Programs (Japanese, ported to WardLisp)"
    :content-dir #P"docs/sicp/"
    :order :natural
    :notebook-title-fn (lambda (slug) (format nil "SICP ~A" slug))))
  "Registry of official courses. SICP is the first entry. Add a new
   official course by appending an OFFICIAL-COURSE here and placing its
   markdown notebooks under its content-dir.

   NOTE: the SICP entry's author-handle MUST stay in sync with
   RECURYA/WEB/ROUTES:+SICP-AUTHOR-HANDLE+ (the wardlisp redirect target
   /c/@recurya/sicp). A drift-guard test asserts this.")

;;;----------------------------------------------------------------------
;;; Stubs (implemented in later tasks)
;;;----------------------------------------------------------------------

(defun %split-natural (s)
  "Split S into alternating non-digit strings and integers.
   E.g. \"sicp-1-10\" -> (\"sicp-\" 1 \"-\" 10)."
  (let ((runs nil) (i 0) (n (length s)))
    (loop while (< i n) do
      (let ((digitp (and (digit-char-p (char s i)) t))
            (j i))
        (loop while (and (< j n)
                         (eq (and (digit-char-p (char s j)) t) digitp))
              do (incf j))
        (let ((chunk (subseq s i j)))
          (push (if digitp (parse-integer chunk) chunk) runs))
        (setf i j)))
    (nreverse runs)))

(defun natural-string< (a b)
  "Strict weak order over strings comparing embedded digit runs numerically,
   so \"x-2\" < \"x-10\". Ties break by overall string length."
  (loop for ra in (%split-natural a)
        for rb in (%split-natural b)
        do (cond
             ((and (integerp ra) (integerp rb))
              (when (< ra rb) (return-from natural-string< t))
              (when (> ra rb) (return-from natural-string< nil)))
             ((and (stringp ra) (stringp rb))
              (when (string< ra rb) (return-from natural-string< t))
              (when (string> ra rb) (return-from natural-string< nil)))
             ;; Different types at same position: integers sort first.
             (t (return-from natural-string< (integerp ra))))
        finally (return (< (length a) (length b)))))

(defun %same-user-p (a b)
  "T iff USER DAOs A and B denote the same row by id."
  (and a b (equal (princ-to-string (users-id a))
                  (princ-to-string (users-id b)))))

(defun %resolve-content-dir (content-dir)
  "Resolve CONTENT-DIR (system-relative pathname) against the recurya
   system root so seeding is independent of the process CWD."
  (asdf:system-relative-pathname :recurya content-dir))

(defun %content-markdown-files (content-dir order)
  "Return the *.md pathnames under CONTENT-DIR ordered by ORDER.
   ORDER is :natural (natural-string< by basename) or an explicit list
   of slugs (basenames without extension)."
  (let ((files (directory (merge-pathnames
                           "*.md" (%resolve-content-dir content-dir)))))
    (etypecase order
      (symbol
       (sort (copy-list files) #'natural-string< :key #'pathname-name))
      (list
       (let ((by-name (make-hash-table :test 'equal)))
         (dolist (f files) (setf (gethash (pathname-name f) by-name) f))
         (loop for slug in order
               for f = (gethash slug by-name)
               when f collect f))))))

(defun %read-file-string (path)
  "Read PATH into a UTF-8 string."
  (with-open-file (s path :direction :input :external-format :utf-8)
    (with-output-to-string (out)
      (loop for line = (read-line s nil nil)
            while line do (write-line line out)))))

(defun %correct-course-state! (course author)
  "Bring an existing COURSE to the canonical published-public-under-AUTHOR
   state if drifted. Returns COURSE."
  (let ((dirty nil))
    (unless (%same-user-p (course-author course) author)
      (setf (course-author course) author dirty t))
    (unless (string= (course-status course) "published")
      (setf (course-status course) "published" dirty t))
    (unless (string= (course-visibility course) "public")
      (setf (course-visibility course) "public" dirty t))
    (unless (course-published-at course)
      (setf (course-published-at course) (local-time:now) dirty t))
    (when dirty (save-dao course))
    course))

(defun %already-attached-p (course-id-uuid notebook-id-uuid)
  "T when (course, notebook) is already in course_notebook."
  (let ((target (princ-to-string notebook-id-uuid)))
    (some (lambda (cn)
            (let ((nb (course-notebook-notebook cn)))
              (and nb (string= (princ-to-string (notebook-id nb)) target))))
          (list-course-notebooks course-id-uuid))))

(defun %next-position (course-id-uuid)
  "Next free position (one past the current max) for COURSE-ID-UUID."
  (let ((rows (list-course-notebooks course-id-uuid)))
    (if rows
        (1+ (reduce #'max rows :key #'course-notebook-position))
        0)))

(defun %ensure-notebook-row (slug body-md title author)
  "Find or create a published-public notebook keyed by SLUG, owned by
   AUTHOR. Returns (values NB CREATED-P CORRECTED-P)."
  (let ((existing (get-notebook-by-slug slug)))
    (cond
      ((and existing (%same-user-p (notebook-author existing) author))
       (values existing nil nil))
      (existing
       (setf (notebook-author existing) author)
       (save-dao existing)
       (values existing nil t))
      (t
       (multiple-value-bind (cells parse-errors) (parse-notebook-body body-md)
         (when parse-errors
           (error "official-content: parse errors in ~A: ~S" slug parse-errors))
         (values (create-notebook!
                  :title title :slug slug :body-md body-md
                  :cells (mapcar #'cell->jsonb-form cells)
                  :author author :status "published" :visibility "public"
                  :published-at (local-time:now))
                 t nil))))))

(defun ensure-official-author (spec)
  "Ensure the author user for SPEC exists; return the USER DAO.
   Lookup by handle, then by email (warn if handle differs), else create."
  (or (get-user-by-handle (official-course-author-handle spec))
      (let ((by-email (get-user-by-email (official-course-author-email spec))))
        (cond
          (by-email
           (warn "ensure-official-author: a user with email ~A exists but ~
                  its handle is ~S (expected ~S); leaving it alone."
                 (official-course-author-email spec)
                 (users-handle by-email)
                 (official-course-author-handle spec))
           by-email)
          (t
           (create-user! :email (official-course-author-email spec)
                         :handle (official-course-author-handle spec)
                         :display-name (official-course-author-display-name spec)
                         :role "user"))))))

(defun ensure-official-course (spec author)
  "Return the canonical course for SPEC, creating it if missing and
   correcting its state if it already exists."
  (let ((existing (get-course-by-slug (official-course-slug spec))))
    (if existing
        (%correct-course-state! existing author)
        (create-course! :title (official-course-title spec)
                        :slug (official-course-slug spec)
                        :summary (official-course-summary spec)
                        :status "published"
                        :visibility "public"
                        :published-at (local-time:now)
                        :author author))))

(defun ensure-notebooks-attached (spec course author)
  "Ensure every markdown file under SPEC's content-dir is a published-
   public notebook owned by AUTHOR and attached to COURSE in order.
   Returns a summary plist."
  (let ((course-id-uuid (course-id course))
        (imported nil) (corrected nil) (skipped nil)
        (attached nil) (already nil))
    (dolist (path (%content-markdown-files (official-course-content-dir spec)
                                           (official-course-order spec)))
      (let* ((slug (pathname-name path))
             (body-md (%read-file-string path))
             (title (funcall (official-course-notebook-title-fn spec) slug)))
        (multiple-value-bind (nb created-p corrected-p)
            (%ensure-notebook-row slug body-md title author)
          (cond (created-p   (push slug imported))
                (corrected-p (push slug corrected))
                (t           (push slug skipped)))
          (let ((nb-uuid (notebook-id nb)))
            (if (%already-attached-p course-id-uuid nb-uuid)
                (push slug already)
                (progn
                  (add-notebook-to-course! course-id-uuid nb-uuid
                                           :position (%next-position course-id-uuid))
                  (push slug attached)))))))
    (list :imported (nreverse imported)
          :corrected (nreverse corrected)
          :skipped (nreverse skipped)
          :attached (nreverse attached)
          :already-attached (nreverse already))))

(defun seed-course! (spec &key (attach-notebooks t))
  "Idempotently seed one official course described by SPEC.
   Returns a summary plist."
  (let* ((author (ensure-official-author spec))
         (course (ensure-official-course spec author))
         (nb-summary (when attach-notebooks
                       (ensure-notebooks-attached spec course author))))
    (list :slug (official-course-slug spec)
          :user-handle (users-handle author)
          :user-id (princ-to-string (users-id author))
          :course-id (princ-to-string (course-id course))
          :notebooks nb-summary)))

(defun seed-official-content! (&key (courses *official-courses*))
  "Idempotently seed every official course in COURSES (default
   *official-courses*). Each course is isolated: a failure in one is
   logged and the rest continue. Returns per-course summaries."
  (loop for spec in courses
        collect (handler-case (seed-course! spec)
                  (error (e)
                    (format t "~&[official-content] WARN: course ~A failed: ~A~%"
                            (official-course-slug spec) e)
                    (list :slug (official-course-slug spec)
                          :error (princ-to-string e))))))
