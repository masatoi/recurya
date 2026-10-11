;;;; game/novel/interpreter.lisp --- Flatten resolved novel directives into beats.
;;;;
;;;; Pure, wardlisp-independent. Input is "directive data" (keyword-headed
;;;; lists) already resolved by the scene evaluator (so conditionals are
;;;; gone). Output is an ordered beat list plus collected flag changes.

(defpackage #:recurya/game/novel/interpreter
  (:use #:cl)
  (:export #:interpret-directives
           #:flag-value-p
           #:invalid-flag-error
           #:invalid-flag-error-name
           #:invalid-flag-error-value))

(in-package #:recurya/game/novel/interpreter)

(define-condition invalid-flag-error (error)
  ((name :initarg :name :reader invalid-flag-error-name)
   (value :initarg :value :reader invalid-flag-error-value))
  (:report (lambda (condition stream)
             (format stream "set-flag needs a symbol name and a value that is t, nil, ~
                             an integer, a string or a symbol; got name ~S and value ~S"
                     (invalid-flag-error-name condition)
                     (invalid-flag-error-value condition))))
  (:documentation "Signalled by INTERPRET-DIRECTIVES for a set-flag whose name is
not a keyword or whose value cannot be stored and passed to the next scene
(a list, for example: wardlisp :bindings take no lists)."))

(defun flag-value-p (value)
  "True for a value a novel flag can hold: T, NIL, an integer, a string or a
keyword.  These survive storage in novel_state and injection into wardlisp."
  (or (eq value t) (null value) (integerp value) (stringp value) (keywordp value)))

(defun interpret-directives (directives)
  "DIRECTIVES: list of keyword-headed directive forms (already resolved).
   Returns (values BEATS SET-FLAGS).
   BEATS: list of plists (:type :say|:narrate ...).
   SET-FLAGS: list of (flag-keyword . value).
   Signals INVALID-FLAG-ERROR for a set-flag whose name is not a keyword or
   whose value is not FLAG-VALUE-P."
  (let ((beats '()) (set-flags '()) (current-bg nil))
    (labels ((walk (dirs)
               (dolist (d dirs)
                 (when (consp d)
                   (case (first d)
                     (:scene (walk (rest d)))
                     (:bg (setf current-bg (second d)))
                     (:narrate
                      (push (list :type :narrate :text (second d) :bg current-bg)
                            beats))
                     (:say
                      (push (list :type :say :speaker (second d) :text (third d)
                                  :bg current-bg)
                            beats))
                     (:set-flag
                      (let ((name (second d))
                            (value (if (cddr d) (third d) t)))
                        (unless (and (keywordp name) (flag-value-p value))
                          (error 'invalid-flag-error :name name :value value))
                        (push (cons name value) set-flags)))
                     (t nil))))))
      (walk directives))
    (values (nreverse beats) (nreverse set-flags))))
