;;;; game/novel/interpreter.lisp --- Flatten resolved novel directives into beats.
;;;;
;;;; Pure, wardlisp-independent. Input is "directive data" (keyword-headed
;;;; lists) already resolved by the scene evaluator (so conditionals are
;;;; gone). Output is an ordered beat list plus collected flag changes.

(defpackage #:recurya/game/novel/interpreter
  (:use #:cl)
  (:export #:interpret-directives))

(in-package #:recurya/game/novel/interpreter)

(defun interpret-directives (directives)
  "DIRECTIVES: list of keyword-headed directive forms (already resolved).
   Returns (values BEATS SET-FLAGS).
   BEATS: list of plists (:type :say|:narrate ...).
   SET-FLAGS: list of (flag-keyword . value)."
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
                      (push (cons (second d) (if (cddr d) (third d) t)) set-flags))
                     (t nil))))))
      (walk directives))
    (values (nreverse beats) (nreverse set-flags))))
