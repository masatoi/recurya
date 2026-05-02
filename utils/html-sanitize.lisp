;;;; utils/html-sanitize.lisp --- Allowlist HTML sanitizer.

(defpackage #:recurya/utils/html-sanitize
  (:use #:cl)
  (:export #:sanitize-html))

(in-package #:recurya/utils/html-sanitize)

(defun sanitize-html (html-string)
  "Sanitize HTML-STRING via tag/attribute allowlist. Stub."
  (declare (ignore html-string))
  (error "not implemented"))
