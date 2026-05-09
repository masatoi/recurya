(defpackage #:recurya/utils/handle
  (:use #:cl)
  (:export #:valid-handle-p
           #:reserved-handle-p
           #:+handle-min-length+
           #:+handle-max-length+))

(in-package #:recurya/utils/handle)

(defparameter +handle-min-length+ 3)
(defparameter +handle-max-length+ 64)

(defparameter *handle-regex*
  (cl-ppcre:create-scanner "^[a-z0-9][a-z0-9-]{1,62}[a-z0-9]$"))

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

(defun reserved-handle-p (s)
  "True if S is in the reserved-handles list (case-insensitive)."
  (and (stringp s)
       (member (string-downcase s) *reserved-handles* :test #'string=)
       t))
