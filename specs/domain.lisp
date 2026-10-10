;;;; specs/domain.lisp --- Shared cl-spec value domains for Recurya contracts.
;;;;
;;;; Named specs reused across contract files.  Each enumeration is taken from
;;;; the docstring or dispatch table cited beside it, never guessed.  Not
;;;; loaded by the production system.

(defpackage #:recurya/specs/domain
  (:use #:cl)
  (:import-from #:cl-spec/main
                #:defspec
                #:defgenerator)
  ;; A bare :import-from declares the check-it backend as an ASDF dependency.
  (:import-from #:cl-spec/src/backends/check-it)
  (:export #:arena-action
           #:grid-position
           #:grid-position-p
           #:notebook-cell-kind
           #:fence-kind))
(in-package #:recurya/specs/domain)

;;; Arena

;; recurya/game/arena:*valid-action-strings*, mapped to keywords by PARSE-ACTION.
(defspec arena-action
  (member :up :down :left :right :wait :pickup))

(defun grid-position-p (value)
  "True when VALUE is a (ROW . COL) cons of non-negative integers."
  (and (consp value)
       (typep (car value) '(integer 0))
       (typep (cdr value) '(integer 0))))

(defgenerator grid-position ()
  "A position on a board of at most 20x20 cells."
  (cons (random 20) (random 20)))

(defspec grid-position
  (satisfies grid-position-p)
  (:generator grid-position))

;;; Notebook

;; Docstring of recurya/game/notebook:cell and the ECASE in RENDER-CELL.
(defspec notebook-cell-kind
  (member :prose :code-eval :code-exercise :code-solution :scene))

;; Docstring of PARSE-FENCE-HEADER: cell kinds plus the two sentinel kinds that
;; the parser's state machine consumes without storing a cell.
(defspec fence-kind
  (or notebook-cell-kind (member :code-delim :expect)))
