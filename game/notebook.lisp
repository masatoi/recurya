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

(defun __stub () nil)
