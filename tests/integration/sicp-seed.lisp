;;;; tests/integration/sicp-seed.lisp --- DB-backed integration tests
;;;; for the canonical SICP seed script.
;;;;
;;;; Phase 10 / T25.
;;;;
;;;; The seed creates the canonical "recurya" user that owns the
;;;; published-public SICP course. The wardlisp redirect routes
;;;; (Phase 7C) point at /c/@recurya/sicp and depend on this user
;;;; existing, so the seed needs to be exercised by tests so we don't
;;;; silently drift from the redirect target.
;;;;
;;;; Notes:
;;;;
;;;;   * The seed uses an `@example.invalid` email which is NOT swept
;;;;     by `cleanup-all-test-data' (which only deletes users matching
;;;;     `%@example.com'). Each test explicitly removes the seed user
;;;;     in an UNWIND-PROTECT so reruns are clean.
;;;;
;;;;   * The script is `load'-ed lazily (not declared in the .asd
;;;;     dependency list) so that test compilation does not require
;;;;     the seed package to exist before this file loads.

(defpackage #:recurya/tests/integration/sicp-seed
  (:use #:cl #:rove)
  (:import-from #:recurya/tests/support/db
                #:with-test-db)
  (:import-from #:recurya/db/users
                #:get-user-by-handle
                #:get-user-by-email
                #:delete-user!)
  (:import-from #:recurya/models/users
                #:users-handle
                #:users-display-name
                #:users-email)
  (:import-from #:recurya/db/courses
                #:get-course-by-slug)
  (:import-from #:recurya/models/course
                #:course-slug
                #:course-status
                #:course-visibility
                #:course-author)
  (:import-from #:recurya/web/routes
                #:+sicp-author-handle+))

(in-package #:recurya/tests/integration/sicp-seed)

;;;----------------------------------------------------------------------
;;; Lazy load of the seed script. The script lives outside the ASDF
;;; dependency graph (it is a one-shot `scripts/' file, not a system),
;;; so we LOAD it from the project root the first time a test needs it.
;;;----------------------------------------------------------------------

(defvar *seed-loaded-p* nil
  "T once `scripts/seed-sicp.lisp' has been LOAD-ed into the image.")

(defun ensure-seed-loaded ()
  "Idempotently LOAD scripts/seed-sicp.lisp from the project root."
  (unless *seed-loaded-p*
    (load (asdf:system-relative-pathname :recurya "scripts/seed-sicp.lisp"))
    (setf *seed-loaded-p* t)))

(defun seed! (&rest args)
  "Invoke the seed function via FIND-SYMBOL so the test file does not
   import a symbol that may not exist until the seed is loaded."
  (apply (find-symbol (string '#:seed-sicp!) '#:scripts/seed-sicp) args))

(defun cleanup-seed-user ()
  "Remove the seed-created user (and cascade course/notebooks) so a
   re-run starts clean. Best-effort: errors are swallowed because
   test fixtures may have already removed the row."
  (let ((email (symbol-value (find-symbol (string '#:+sicp-author-email+)
                                          '#:scripts/seed-sicp))))
    (ignore-errors (delete-user! email))))

;;;----------------------------------------------------------------------
;;; Tests
;;;----------------------------------------------------------------------

(deftest seed-creates-recurya-author-user
  (testing "ensure-sicp-author-user creates the canonical recurya user
            when the database has no SICP author"
    (with-test-db
      (ensure-seed-loaded)
      (unwind-protect
           (progn
             (seed! :attach-notebooks nil)
             (let ((u (get-user-by-handle +sicp-author-handle+)))
               (ok u "recurya user must exist after seeding")
               (ok (string= +sicp-author-handle+ (users-handle u)))
               (ok (string= "Recurya" (users-display-name u)))
               (ok (search "@example.invalid" (users-email u))
                   "seed user must use the .invalid TLD so it cannot leak real mail")))
        (cleanup-seed-user)))))

(deftest seed-creates-sicp-course-under-recurya
  (testing "ensure-sicp-course creates a published-public SICP course
            owned by the canonical recurya user"
    (with-test-db
      (ensure-seed-loaded)
      (unwind-protect
           (progn
             (seed! :attach-notebooks nil)
             (let ((c (get-course-by-slug "sicp")))
               (ok c "SICP course must exist after seeding")
               (ok (string= "sicp" (course-slug c)))
               (ok (string= "published" (course-status c))
                   "course must be published so it appears on /courses")
               (ok (string= "public" (course-visibility c))
                   "course must be public so /c/@recurya/sicp is visible
                    to anonymous visitors")
               (let ((author (course-author c)))
                 (ok author)
                 (ok (string= +sicp-author-handle+ (users-handle author))
                     "course author must be the canonical recurya user"))))
        (cleanup-seed-user)))))

(deftest seed-is-idempotent
  (testing "running seed-sicp! twice in a row resolves to the same rows
            (no duplicates, identity preserved)"
    (with-test-db
      (ensure-seed-loaded)
      (unwind-protect
           (let* ((first-result (seed! :attach-notebooks nil))
                  (first-user-id (getf first-result :user-id))
                  (first-course-id (getf first-result :course-id))
                  (second-result (seed! :attach-notebooks nil))
                  (second-user-id (getf second-result :user-id))
                  (second-course-id (getf second-result :course-id)))
             (ok (string= first-user-id second-user-id)
                 "user UUID stable across two seed runs (no duplicate insert)")
             (ok (string= first-course-id second-course-id)
                 "course UUID stable across two seed runs (no duplicate insert)")
             (ok (get-user-by-handle +sicp-author-handle+)
                 "recurya user still resolvable by handle after second run")
             (let ((c (get-course-by-slug "sicp")))
               (ok c "sicp course still resolvable by slug after second run")
               (ok (string= "published" (course-status c)))
               (ok (string= "public" (course-visibility c)))))
        (cleanup-seed-user)))))
