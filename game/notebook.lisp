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

(defun run-cell (notebook cell-index submitted-codes)
  "Execute the cell at CELL-INDEX in NOTEBOOK.
   For :code-eval cells, concatenate SUBMITTED-CODES[0..CELL-INDEX] and
   evaluate once. For :code-exercise cells, additionally run each
   test-case by appending its input. Returns a NOTEBOOK-CELL-RESULT.
   Signals an error for :prose cells and out-of-range indices."
  (let* ((cells (notebook-cells notebook))
         (cell (nth cell-index cells)))
    (unless cell
      (error "Cell index ~A out of range for notebook ~A"
             cell-index (notebook-id notebook)))
    (when (eq (cell-kind cell) :prose)
      (error "Cannot run a prose cell (id=~A)" (cell-id cell)))
    (let* ((take (min (1+ cell-index) (length submitted-codes)))
           (codes (subseq submitted-codes 0 take))
           (combined (format nil "~{~A~^~%~}" codes)))
      (if (eq (cell-kind cell) :code-exercise)
          (run-exercise-cell cell combined)
          (run-eval-cell cell combined)))))

(defun run-eval-cell (cell combined)
  "Evaluate COMBINED as a :code-eval cell, returning a cell result."
  (multiple-value-bind (result metrics)
      (evaluate combined
                :fuel *notebook-fuel* :max-cons *notebook-max-cons*
                :max-depth *notebook-max-depth* :max-output *notebook-max-output*
                :timeout *notebook-timeout*)
    (let ((err (getf metrics :error-message)))
      (if err
          (make-notebook-cell-result
           :cell-id (cell-id cell) :kind (cell-kind cell)
           :status :error :value nil
           :print-output (or (getf metrics :output) "")
           :error-message err :metrics metrics :test-results nil)
          (make-notebook-cell-result
           :cell-id (cell-id cell) :kind (cell-kind cell)
           :status :ok :value (print-value result)
           :print-output (or (getf metrics :output) "")
           :error-message nil :metrics metrics :test-results nil)))))

(defun run-exercise-cell (cell combined)
  "Grade a :code-exercise cell against its TEST-CASES.
   Returns a NOTEBOOK-CELL-RESULT with status :pass, :fail, or :error."
  (multiple-value-bind (user-result user-metrics)
      (evaluate combined
                :fuel *notebook-fuel* :max-cons *notebook-max-cons*
                :max-depth *notebook-max-depth* :max-output *notebook-max-output*
                :timeout *notebook-timeout*)
    (declare (ignore user-result))
    (let ((user-error (getf user-metrics :error-message)))
      (if user-error
          (make-notebook-cell-result
           :cell-id (cell-id cell) :kind :code-exercise
           :status :error :value nil
           :print-output (or (getf user-metrics :output) "")
           :error-message user-error
           :metrics user-metrics
           :test-results nil)
          (let ((test-results nil)
                (all-pass t))
            (dolist (tc (cell-test-cases cell))
              (let ((full-code (format nil "~A~%~A" combined (test-case-input tc))))
                (multiple-value-bind (result metrics)
                    (evaluate full-code
                              :fuel *notebook-fuel* :max-cons *notebook-max-cons*
                              :max-depth *notebook-max-depth*
                              :max-output *notebook-max-output*
                              :timeout *notebook-timeout*)
                  (let* ((terr (getf metrics :error-message))
                         (expected-str (test-case-expected tc))
                         (actual-str (unless terr (print-value result)))
                         (passed (and (not terr)
                                      (string= actual-str expected-str))))
                    (unless passed (setf all-pass nil))
                    (push (list :input (test-case-input tc)
                                :description (test-case-description tc)
                                :expected expected-str
                                :actual actual-str
                                :passed passed
                                :error terr)
                          test-results)))))
            (make-notebook-cell-result
             :cell-id (cell-id cell) :kind :code-exercise
             :status (if all-pass :pass :fail)
             :value nil
             :print-output (or (getf user-metrics :output) "")
             :error-message nil
             :metrics user-metrics
             :test-results (nreverse test-results)))))))
