;;;; game/novel/value.lisp --- Convert wardlisp result values into plain
;;;; directive data (keyword-headed lists, CL strings, integers).
(defpackage #:recurya/game/novel/value
  (:use #:cl)
  (:import-from #:wardlisp
                #:ocons-p #:ocons-ocar #:ocons-ocdr
                #:string-value-p #:string-value)
  (:export #:ward->directives #:+max-walk-depth+))

(in-package #:recurya/game/novel/value)

(defparameter +max-walk-depth+ 200
  "Maximum nesting depth when walking a wardlisp result tree.")

(defun %sym->keyword (s)
  "Convert a wardlisp symbol (CL string) to an uppercased keyword tag."
  (intern (string-upcase s) :keyword))

(defun %value->data (v depth)
  "Convert a single wardlisp value V to plain Lisp data."
  (when (> depth +max-walk-depth+)
    (error "novel/value: result nesting exceeds ~D" +max-walk-depth+))
  (cond
    ((ocons-p v) (%list->data v depth))
    ((string-value-p v) (string-value v))   ; wardlisp string -> CL string
    ((integerp v) v)
    ((null v) nil)
    ((eq v t) t)
    ((stringp v) (%sym->keyword v))          ; wardlisp symbol -> keyword
    (t v)))

(defun %list->data (v depth)
  "Convert a wardlisp ocons chain V to a CL list of plain data."
  (loop while (ocons-p v)
        collect (%value->data (ocons-ocar v) (1+ depth))
        do (setf v (ocons-ocdr v))))

(defun ward->directives (value)
  "Convert a wardlisp result VALUE (an ocons list of directive forms) into
   a CL list of keyword-headed directive forms with CL-string text."
  (if (ocons-p value)
      (%list->data value 0)
      ;; A non-list result is treated as a single (possibly empty) program.
      (let ((d (%value->data value 0)))
        (if (consp d) (list d) nil))))
