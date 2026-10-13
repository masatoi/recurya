;;;; game/notebook-gating.lisp --- Which solution cells a reader may see.
;;;;
;;;; Pure rules shared by the HTML renderer and the JSON API: a gated
;;;; :code-solution is visible only once the nearest :code-exercise before it
;;;; is passed, and passing an exercise unlocks the gated solutions that
;;;; follow it up to the next exercise.

(defpackage #:recurya/game/notebook-gating
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:cell-id
                #:cell-kind
                #:cell-gated-p)
  (:export #:cell-id-string
           #:solution-unlocked-p
           #:gated-solution-indices))

(in-package #:recurya/game/notebook-gating)

(defun cell-id-string (id)
  "Stringify a cell or notebook id, accepting both keyword (legacy SICP)
and string (UUID) representations. NIL becomes \"\"."
  (cond ((null id) "")
        ((symbolp id) (string-downcase (symbol-name id)))
        (t (string id))))

(defun solution-unlocked-p (cells index passed-cell-ids)
  "True when the cell at INDEX of CELLS may be shown in full: it is not a
gated solution, or the nearest :code-exercise before it has its id (as by
CELL-ID-STRING) in PASSED-CELL-IDS.  A gated solution with no exercise before
it stays locked."
  (let ((cell (nth index cells)))
    (or (not (cell-gated-p cell))
        (loop for i from (1- index) downto 0
              for c = (nth i cells)
              when (eq (cell-kind c) :code-exercise)
                do (return (and (member (cell-id-string (cell-id c)) passed-cell-ids
                                        :test #'string=)
                                t))
              finally (return nil)))))

(defun gated-solution-indices (cells exercise-index)
  "Indices of the gated :code-solution cells that belong to the exercise at
EXERCISE-INDEX: those after it and before the next :code-exercise."
  (loop for i from (1+ exercise-index) below (length cells)
        for c = (nth i cells)
        until (eq (cell-kind c) :code-exercise)
        when (and (eq (cell-kind c) :code-solution) (cell-gated-p c))
          collect i))
