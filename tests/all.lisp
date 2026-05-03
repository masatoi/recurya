;;;; tests/all.lisp --- Aggregate test runner for all recurya test suites.

(defpackage #:recurya/tests/all
  (:use #:cl)
  (:export #:run-all-tests))

(in-package #:recurya/tests/all)

(defparameter *test-packages*
  '(:recurya/tests/utils/common
    :recurya/tests/utils/html-sanitize
    :recurya/tests/utils/access-control
    :recurya/tests/db/core
    :recurya/tests/db/jsonb
    :recurya/tests/db/users
    :recurya/tests/db/posts
    :recurya/tests/db/user-notebooks
    :recurya/tests/db/courses
    :recurya/tests/db/course-notebooks
    :recurya/tests/db/learn
    :recurya/tests/web/oauth
    :recurya/tests/web/routes
    :recurya/tests/web/user-notebook-routes
    :recurya/tests/web/course-routes
    :recurya/tests/web/learn-routes
    :recurya/tests/web/csrf
    ;; WardLisp integration tests
    :recurya/tests/wardlisp-integration
    ;; Game tests
    :recurya/tests/game/puzzle
    :recurya/tests/game/arena
    :recurya/tests/game/notebook
    :recurya/tests/game/notebook-parser
    ;; Integration tests
    :recurya/tests/integration/sicp-canonical-solutions)
  "List of all test packages to run.")

(defun run-all-tests ()
  "Run all test packages and return T if all pass, NIL otherwise."
  ;; Load clack-test for HTTP integration tests (system name differs from package name)
  (ql:quickload :clack-test :silent t)
  (let ((all-passed t))
    (dolist (pkg *test-packages*)
      (format t "~%=== Running tests for ~A ===~%" pkg)
      (handler-case
          (unless (rove:run pkg)
            (setf all-passed nil))
        (error (e)
          (format t "Error running ~A: ~A~%" pkg e)
          (setf all-passed nil))))
    all-passed))
