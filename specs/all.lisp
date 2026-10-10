;;;; specs/all.lisp --- Load every Recurya cl-spec contract file.
;;;;
;;;; An umbrella with no code of its own: each :IMPORT-FROM pulls in one
;;;; contract file so `load-system recurya/specs/all' registers them all.
;;;; The production system never depends on this.

(defpackage #:recurya/specs/all
  (:use #:cl)
  (:import-from #:recurya/specs/domain))

(in-package #:recurya/specs/all)
