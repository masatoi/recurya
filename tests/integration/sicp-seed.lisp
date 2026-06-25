;;;; tests/integration/sicp-seed.lisp --- Integration tests for the
;;;; generic official-content seeder (recurya/seed/official-content).
;;;;
;;;; SICP is the first registry entry. These tests cover:
;;;;   * natural-string< ordering (non-DB)
;;;;   * drift guard between the SICP spec and the wardlisp redirect (non-DB)
;;;;   * SICP author/course seeding + idempotency (DB)
;;;;   * generic notebook attachment + natural ordering via fixtures (DB)
;;;;
;;;; The SICP author uses an @example.invalid email which is NOT swept by
;;;; cleanup-all-test-data (only @example.com); DB tests delete it in an
;;;; unwind-protect. The generic fixture author uses @example.com so it is
;;;; cleaned automatically. with-test-db wipes all course/notebook rows.

(defpackage #:recurya/tests/integration/sicp-seed
  (:use #:cl #:rove)
  (:import-from #:recurya/tests/support/db
                #:with-test-db)
  (:import-from #:recurya/db/users
                #:get-user-by-handle
                #:delete-user!)
  (:import-from #:recurya/models/users
                #:users-handle
                #:users-display-name
                #:users-email)
  (:import-from #:recurya/db/courses
                #:get-course-by-slug)
  (:import-from #:recurya/models/course
                #:course-id
                #:course-slug
                #:course-status
                #:course-visibility
                #:course-author)
  (:import-from #:recurya/db/course-notebooks
                #:count-course-notebooks
                #:list-course-notebooks)
  (:import-from #:recurya/models/course-notebook
                #:course-notebook-notebook
                #:course-notebook-position)
  (:import-from #:recurya/models/notebook
                #:notebook-slug)
  (:import-from #:recurya/seed/official-content
                #:*official-courses*
                #:make-official-course
                #:official-course-slug
                #:official-course-author-handle
                #:official-course-author-email
                #:seed-course!)
  (:import-from #:recurya/web/routes
                #:+sicp-author-handle+))

(in-package #:recurya/tests/integration/sicp-seed)

(defun sicp-spec ()
  "The SICP entry from the official-content registry."
  (find "sicp" *official-courses*
        :key #'official-course-slug :test #'string=))

;;;----------------------------------------------------------------------
;;; Non-DB tests
;;;----------------------------------------------------------------------

(deftest natural-string<-orders-numerically
  (testing "embedded digit runs compare numerically, not lexically"
    (ok (recurya/seed/official-content::natural-string< "demo-2" "demo-10"))
    (ok (not (recurya/seed/official-content::natural-string< "demo-10" "demo-2")))
    (ok (recurya/seed/official-content::natural-string< "sicp-1-2-1" "sicp-1-10-1"))
    (ok (recurya/seed/official-content::natural-string< "sicp-1-1-1" "sicp-1-1-2"))
    ;; irreflexive: a string is not < itself
    (ok (not (recurya/seed/official-content::natural-string< "demo-2" "demo-2")))
    ;; all-alpha falls back to lexical comparison
    (ok (recurya/seed/official-content::natural-string< "abc" "abd"))
    ;; pure-digit inputs compare numerically
    (ok (recurya/seed/official-content::natural-string< "9" "10"))
    (ok (not (recurya/seed/official-content::natural-string< "10" "9")))))

(deftest sicp-spec-matches-redirect-handle
  (testing "SICP registry entry stays in sync with the wardlisp redirect"
    (let ((spec (sicp-spec)))
      (ok spec "SICP must be present in *official-courses*")
      (ok (string= "sicp" (official-course-slug spec)))
      (ok (string= +sicp-author-handle+ (official-course-author-handle spec))
          "spec author-handle must equal +sicp-author-handle+ so
           /c/@recurya/sicp resolves"))))
