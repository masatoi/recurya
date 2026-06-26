;;;; game/novel/eval.lisp --- Evaluate one scene's wardlisp source with the
;;;; reader's flags injected, returning resolved directive data.
(defpackage #:recurya/game/novel/eval
  (:use #:cl)
  (:import-from #:wardlisp #:evaluate #:make-string-value)
  (:import-from #:recurya/game/novel/value #:ward->directives)
  (:export #:eval-scene #:split-novel-cells
           #:*novel-fuel* #:*novel-max-cons*
           #:*novel-max-depth* #:*novel-timeout*))

(in-package #:recurya/game/novel/eval)

(defparameter *novel-fuel* 200000)
(defparameter *novel-max-cons* 50000)
(defparameter *novel-max-depth* 300)
(defparameter *novel-timeout* 5)

(defun %flag->binding (pair)
  "Convert a flag (keyword . value) to a wardlisp :bindings entry (name . value).
   The keyword becomes a downcased symbol name; a CL string value is boxed into
   a wardlisp string."
  (let ((name (string-downcase (symbol-name (car pair))))
        (value (cdr pair)))
    (cons name (if (stringp value) (make-string-value value) value))))

(defun eval-scene (scene-source &key prelude flags)
  "Evaluate SCENE-SOURCE (wardlisp text) with PRELUDE (shared defs, text)
   prepended and FLAGS (alist flag-keyword -> value) injected via wardlisp's
   :bindings. Returns resolved directive data (see recurya/game/novel/value)."
  (let ((code (format nil "~@[~A~%~]~A" prelude scene-source))
        (bindings (mapcar #'%flag->binding flags)))
    (multiple-value-bind (result metrics)
        (evaluate code
                  :bindings bindings
                  :fuel *novel-fuel* :max-cons *novel-max-cons*
                  :max-depth *novel-max-depth* :timeout *novel-timeout*)
      (let ((err (getf metrics :error-message)))
        (when err (error "novel scene error: ~A" err)))
      (ward->directives result))))

(defun split-novel-cells (cells)
  "Given a list of (kind . body) pairs (kind keyword, body string),
   return (values PRELUDE SCENE-BODIES) where PRELUDE is the concatenation
   of all :code-eval bodies and SCENE-BODIES is the ordered list of :scene
   bodies."
  (let ((prelude '()) (scenes '()))
    (dolist (c cells)
      (case (car c)
        (:code-eval (push (cdr c) prelude))
        (:scene (push (cdr c) scenes))))
    (values (format nil "~{~A~^~%~}" (nreverse prelude))
            (nreverse scenes))))
