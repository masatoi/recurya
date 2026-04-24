;;;; game/notebook.lisp --- Notebook/cell model and run-cell evaluator.

(defpackage #:recurya/game/notebook
  (:use #:cl)
  (:import-from #:wardlisp
                #:evaluate
                #:print-value)
  (:import-from #:recurya/game/puzzle
                #:make-test-case
                #:test-case-input
                #:test-case-expected
                #:test-case-description)
  (:export #:notebook #:make-notebook
           #:notebook-id #:notebook-chapter #:notebook-title
           #:notebook-summary #:notebook-cells
           #:cell #:make-cell
           #:cell-id #:cell-kind #:cell-body
           #:cell-description #:cell-test-cases
           #:notebook-cell-result #:make-notebook-cell-result
           #:notebook-cell-result-cell-id
           #:notebook-cell-result-kind
           #:notebook-cell-result-status
           #:notebook-cell-result-value
           #:notebook-cell-result-print-output
           #:notebook-cell-result-error-message
           #:notebook-cell-result-metrics
           #:notebook-cell-result-test-results
           #:run-cell
           #:*notebook-fuel* #:*notebook-max-cons*
           #:*notebook-max-depth* #:*notebook-max-output*
           #:*notebook-timeout*))

(in-package #:recurya/game/notebook)

(defstruct notebook
  "A SICP-style notebook: a list of cells rendered top-down."
  (id nil :type keyword)
  (chapter "" :type string)
  (title "" :type string)
  (summary "" :type string)
  (cells nil :type list))

(defstruct cell
  "A single notebook cell. KIND is one of :prose, :code-eval, :code-exercise.
   BODY is a Spinneret DSL list for :prose cells, or a source string for code cells."
  (id nil :type keyword)
  (kind nil :type keyword)
  body               ; untyped: list for prose, string for code cells
  (description "" :type string)
  (test-cases nil :type list))

(defstruct notebook-cell-result
  "Result of running one cell."
  (cell-id nil :type keyword)
  (kind nil :type keyword)
  (status nil :type keyword)
  value              ; untyped: nil | string (print-value output)
  (print-output "" :type string)
  (error-message nil :type (or null string))
  (metrics nil :type list)
  (test-results nil :type list))

(defparameter *notebook-fuel* 20000
  "Default fuel limit for a notebook cell evaluation.")

(defparameter *notebook-max-cons* 10000
  "Default cons allocation limit for a notebook cell evaluation.")

(defparameter *notebook-max-depth* 200
  "Default call-stack depth limit for a notebook cell evaluation.")

(defparameter *notebook-max-output* 4096
  "Default captured-output byte limit for a notebook cell evaluation.")

(defparameter *notebook-timeout* 5
  "Default wall-clock timeout (seconds) for a notebook cell evaluation.")
