(defpackage #:recurya/utils/handle
  (:use #:cl)
  (:export #:valid-handle-p
           #:reserved-handle-p
           #:placeholder-handle-p
           #:+handle-min-length+
           #:+handle-max-length+))

(in-package #:recurya/utils/handle)

(defparameter +handle-min-length+ 3)
(defparameter +handle-max-length+ 64)

(defparameter *handle-regex*
  (cl-ppcre:create-scanner "\\A[a-z0-9][a-z0-9-]{1,62}[a-z0-9]\\z"))

(defparameter *reserved-handles*
  '("notebooks" "courses" "c" "n" "dashboard" "account" "login" "logout"
    "auth" "onboarding" "api" "static" "admin" "assets" "learn" "wardlisp"
    "settings" "help" "about" "new" "edit" "search" "blog" "posts"
    "register" "signup" "signin" "user" "users" "me"))

(defun valid-handle-p (s)
  "True if S is a syntactically valid handle (does not check reservation)."
  (and (stringp s)
       (>= (length s) +handle-min-length+)
       (<= (length s) +handle-max-length+)
       (cl-ppcre:scan *handle-regex* s)
       t))

(defun placeholder-handle-p (handle)
  "True if HANDLE is a Phase-5-style placeholder (u-<hex>) requiring onboarding.

RESERVED-HANDLE-P refuses this shape, so a real handle never matches it.

The placeholder format is 'u-XXXXXXXX' where X is exactly 8 lowercase hex
digits, as produced by RECURYA/DB/USERS::%GENERATE-PLACEHOLDER-HANDLE.

Arguments:
  HANDLE - The handle string to test.

Returns:
  T if HANDLE matches the placeholder pattern; NIL otherwise."
  (and (stringp handle)
       (cl-ppcre:scan "\\Au-[a-f0-9]{8}\\z" handle)
       t))

(defun reserved-handle-p (s)
  "True if S may not be chosen as a handle: its lower-cased form is in the
reserved-handles list, or has the placeholder shape (PLACEHOLDER-HANDLE-P)
that marks a user who has not picked a handle yet.  The placeholder shape also
satisfies VALID-HANDLE-P, so without this a user could choose it and be sent
back to onboarding on every request."
  (and (stringp s)
       (let ((lower (string-downcase s)))
         (or (member lower *reserved-handles* :test #'string=)
             (placeholder-handle-p lower)))
       t))
