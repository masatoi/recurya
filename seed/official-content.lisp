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

(defun natural-string< (a b)
  (declare (ignore a b))
  (error "not implemented"))

(defun ensure-official-author (spec)
  (declare (ignore spec))
  (error "not implemented"))

(defun ensure-official-course (spec author)
  (declare (ignore spec author))
  (error "not implemented"))

(defun ensure-notebooks-attached (spec course author)
  (declare (ignore spec course author))
  (error "not implemented"))

(defun seed-course! (spec &key (attach-notebooks t))
  (declare (ignore spec attach-notebooks))
  (error "not implemented"))

(defun seed-official-content! (&key (courses *official-courses*))
  (declare (ignore courses))
  (error "not implemented"))
