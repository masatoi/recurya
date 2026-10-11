;;;; specs/db/users.lisp --- cl-spec contracts for user accounts and handles.
;;;;
;;;; Handle reservation (pure) and, inside WITH-TEST-DB (recurya_test only),
;;;; user creation and lookup, OAuth login resolution and partial updates.
;;;; Design doc: docs/superpowers/specs/2026-10-11-cl-spec-db-rest-design.md

(defpackage #:recurya/specs/db/users
  (:use #:cl)
  (:import-from #:cl-spec/main
                #:defspec
                #:defspec-function
                #:defproperty
                #:defgenerator)
  (:import-from #:cl-spec/src/backends/check-it)
  (:import-from #:recurya/specs/db/domain
                #:random-element)
  (:import-from #:recurya/utils/handle
                #:valid-handle-p
                #:reserved-handle-p
                #:placeholder-handle-p)
  (:import-from #:cl-ppcre
                #:scan))
(in-package #:recurya/specs/db/users)

(defparameter *reserved-words*
  '("notebooks" "courses" "c" "n" "dashboard" "account" "login" "logout"
    "auth" "onboarding" "api" "static" "admin" "assets" "learn" "wardlisp"
    "settings" "help" "about" "new" "edit" "search" "blog" "posts"
    "register" "signup" "signin" "user" "users" "me")
  "The reserved handles, copied from utils/handle.lisp so the oracle does not
read the implementation's table.")

(defparameter *placeholder-shape* "\\Au-[a-f0-9]{8}\\z"
  "The placeholder handle shape: u- and exactly 8 lower-case hex digits.")

(defun random-hex (n)
  "A string of N random lower-case hex digits."
  (let ((digits "0123456789abcdef"))
    (coerce (loop repeat n collect (char digits (random 16))) 'string)))

(defun random-case (string)
  "STRING with each character upper-cased at random."
  (map 'string (lambda (ch) (if (zerop (random 2)) (char-upcase ch) ch)) string))

(defgenerator handle-text ()
  "A value that may or may not be an acceptable handle: a reserved word or a
placeholder shape (either in mixed case), a near miss of the placeholder
shape, a plain handle, odd strings, or a non-string."
  (case (random 8)
    (0 (random-element *reserved-words*))
    (1 (random-case (random-element *reserved-words*)))
    (2 (format nil "u-~A" (random-hex 8)))
    (3 (random-case (format nil "u-~A" (random-hex 8))))
    (4 (random-element (vector (format nil "u-~A" (random-hex 7))
                               (format nil "u-~A" (random-hex 9))
                               (format nil "u_~A" (random-hex 8))
                               (format nil "u-~Ag" (random-hex 7))
                               (format nil "x-~A" (random-hex 8))
                               (format nil "u-~A~%" (random-hex 8)))))
    (5 (random-element (vector "alice" "bob-the-builder" "user123" "abc" "a1-b2")))
    (6 (random-element (vector "" "a" "-abc" "abc-" "ab cd" "λambda"
                               (make-string 65 :initial-element #\a))))
    (t (random-element (vector nil 42 :admin)))))

(defspec handle-text t (:generator handle-text))

(defun expected-reserved-p (value)
  "The design's rule: VALUE is a string whose lower-cased form is a reserved
word or has the placeholder shape."
  (and (stringp value)
       (let ((lower (string-downcase value)))
         (or (member lower *reserved-words* :test #'string=)
             (scan *placeholder-shape* lower)))
       t))

(defspec-function reserved-handle-p
  "True exactly for a string whose lower-cased form is a reserved word or has
the placeholder shape; NIL for everything else, non-strings included."
  (:args (value handle-text))
  (:cases
    (:reserved
      (:when (expected-reserved-p value))
      (:returns (member t)))
    (:free
      (:when (not (expected-reserved-p value)))
      (:returns null))))

(defproperty placeholder-handle-never-real ((value handle-text))
  "No value is both accepted by onboarding (VALID-HANDLE-P and not
RESERVED-HANDLE-P) and a placeholder (PLACEHOLDER-HANDLE-P), so a user can
never pick a handle that keeps them in onboarding."
  (:about valid-handle-p reserved-handle-p placeholder-handle-p)
  (:kind :invariant)
  (:trials (:smoke 50 :normal 300))
  (not (and (valid-handle-p value)
            (not (reserved-handle-p value))
            (placeholder-handle-p value))))
