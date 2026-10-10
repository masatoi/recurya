;;;; specs/game/notebook.lisp --- cl-spec generators for notebook cells.
;;;;
;;;; Canonical cells are the fixed points of a render/parse round trip
;;;; (design doc F-A1/F-A2): bodies are 1-4 non-blank lines with no outer
;;;; whitespace (lines after the first may be indented), optionally separated
;;;; by one or two blank lines, and no line starts with ===; exercise
;;;; descriptions are 1-3 trimmed lines; solution descriptions and test-case
;;;; fields are single trimmed lines without "input:" or "output:".  Loose
;;;; cells add outer whitespace to the body.

(defpackage #:recurya/specs/game/notebook
  (:use #:cl)
  (:import-from #:cl-spec/main
                #:defspec
                #:defgenerator)
  (:import-from #:cl-spec/src/backends/check-it)
  (:import-from #:recurya/game/notebook
                #:cell
                #:make-cell
                #:cell-kind
                #:cell-body
                #:cell-description
                #:cell-test-cases
                #:cell-gated-p)
  (:import-from #:recurya/game/puzzle
                #:make-test-case
                #:test-case-input
                #:test-case-expected
                #:test-case-description)
  (:export #:random-canonical-cell
           #:random-stored-string
           #:test-case-view
           #:stored-cell
           #:canonical-cells
           #:loose-cells
           #:cell-view
           #:trimmed-cell-view))
(in-package #:recurya/specs/game/notebook)

(defparameter *body-words*
  #("foo" "bar" "(+ 1 2)" "x" "define" "hello world" "# Title" "- item" "42"
    "λ" "a*b" "input: 1" "  (indented)")
  "Words for cell bodies, including Markdown, Lisp, non-ASCII, inner spacing
and an input: line that only matters inside an expect block.")

(defparameter *test-case-words*
  #("foo" "bar" "(+ 1 2)" "x" "define" "hello world" "42" "λ" "a*b")
  "Words for test-case fields: no input:/output: (design doc F-A2).")

(defparameter *cell-kinds*
  #(:prose :code-eval :code-exercise :code-solution :scene)
  "The kinds of NOTEBOOK-CELL-KIND, drawn by the cell generator.")

(defun random-element (sequence)
  "Return a uniformly chosen element of the non-empty SEQUENCE."
  (elt sequence (random (length sequence))))

(defun random-line (words)
  "One line of 1-3 WORDS joined by spaces, with no outer whitespace."
  (string-trim " " (format nil "~{~A~^ ~}"
                           (loop repeat (1+ (random 3))
                                 collect (random-element words)))))

(defun random-indent ()
  "Leading spaces for a non-first body line: none about half the time."
  (random-element #("" "" "" " " "  " "    ")))

(defun canonical-body ()
  "1-4 non-blank lines, the first unindented and the rest sometimes indented,
optionally separated by one or two blank lines."
  (let ((lines '()))
    (dotimes (i (1+ (random 4)))
      (when (plusp i)
        (case (random 6)
          ((0 1) (push "" lines))
          (2 (push "" lines) (push "" lines))))
      (push (if (zerop i)
                (random-line *body-words*)
                (concatenate 'string (random-indent) (random-line *body-words*)))
            lines))
    (format nil "~{~A~^~%~}" (nreverse lines))))

(defun exercise-description ()
  "1-3 trimmed lines: a bare ===exercise=== header takes a multi-line
description up to its ===code=== line."
  (format nil "~{~A~^~%~}"
          (loop repeat (1+ (random 3)) collect (random-line *test-case-words*))))

(defun random-test-case ()
  "A canonical test case."
  (make-test-case
   :input (if (zerop (random 2)) "" (random-line *test-case-words*))
   :expected (random-line *test-case-words*)
   :description (if (zerop (random 2)) "" (random-line *test-case-words*))))

(defun random-canonical-cell ()
  "A canonical cell of a random kind."
  (let ((kind (random-element *cell-kinds*)))
    (make-cell :kind kind
               :body (canonical-body)
               :description (case kind
                              (:code-exercise (exercise-description))
                              (:code-solution (random-line *test-case-words*))
                              (t ""))
               :test-cases (when (eq kind :code-exercise)
                             (loop repeat (random 4) collect (random-test-case)))
               :gated-p (and (eq kind :code-solution) (zerop (random 2))))))

(defparameter *stored-strings*
  (vector "" "x" "foo bar" (format nil "line1~%line2") "say \"hi\"" "back\\slash"
          (format nil "tab~Chere" #\Tab) "λ ラムダ" "===prose===" "  padded  " "null" "false"
          (format nil "cr~Chere" #\Return) (string (code-char 1))
          (string (code-char #x1F600)))
  "Pieces of strings a JSONB field must carry unchanged: empty, line breaks,
quotes, backslash, tab, carriage return, a C0 control character, non-ASCII
(including an astral-plane character), fence-like text, outer spaces, and text
that looks like a JSON keyword.")

(defun random-stored-string ()
  "1-3 *STORED-STRINGS* pieces concatenated."
  (format nil "~{~A~}" (loop repeat (1+ (random 3))
                             collect (random-element *stored-strings*))))

(defun random-stored-test-case ()
  "A test case whose fields are arbitrary stored strings."
  (make-test-case :input (random-stored-string)
                  :expected (random-stored-string)
                  :description (random-stored-string)))

(defun random-stored-cell ()
  "A cell of any kind whose id is NIL, empty or an arbitrary string and whose
fields hold arbitrary strings.  Not canonical: the JSONB column stores every
field as is, so no per-kind restriction applies."
  (make-cell :id (case (random 4)
                   (0 nil)
                   (1 "")
                   (t (random-stored-string)))
             :kind (random-element *cell-kinds*)
             :body (random-stored-string)
             :description (random-stored-string)
             :test-cases (loop repeat (random 4) collect (random-stored-test-case))
             :gated-p (zerop (random 2))))

(defgenerator stored-cell ()
  "A fresh cell from RANDOM-STORED-CELL."
  (random-stored-cell))

(defspec stored-cell (type cell) (:generator stored-cell))

(defun loosen (cell)
  "Return CELL with outer whitespace added around its body."
  (setf (cell-body cell)
        (format nil "~A~A~A"
                (random-element (vector "" " " "  " (string #\Newline)))
                (cell-body cell)
                (random-element (vector "" " " (string #\Newline)
                                        (format nil "~%~%")))))
  cell)

(defgenerator canonical-cells ()
  "1-6 fresh canonical cells."
  (loop repeat (1+ (random 6)) collect (random-canonical-cell)))

(defspec canonical-cells list (:generator canonical-cells))

(defgenerator loose-cells ()
  "1-6 fresh cells whose bodies carry outer whitespace."
  (loop repeat (1+ (random 6)) collect (loosen (random-canonical-cell))))

(defspec loose-cells list (:generator loose-cells))

(defun test-case-view (test-case)
  "TEST-CASE as (INPUT EXPECTED DESCRIPTION), comparable with EQUAL."
  (list (test-case-input test-case)
        (test-case-expected test-case)
        (test-case-description test-case)))

(defun cell-view (cell)
  "CELL as (KIND BODY DESCRIPTION TEST-CASE-VIEWS GATED-P), comparable with
EQUAL.  The id is left out: the parser assigns fresh ids."
  (list (cell-kind cell)
        (cell-body cell)
        (cell-description cell)
        (mapcar #'test-case-view (cell-test-cases cell))
        (cell-gated-p cell)))

(defun trimmed-cell-view (cell)
  "CELL-VIEW of CELL with its body stripped of outer spaces, tabs and line
breaks: the canonical cell a loose cell must become after one round trip.
Computed from CELL alone, without the parser."
  (let ((view (cell-view cell)))
    (list* (first view)
           (string-trim '(#\Space #\Tab #\Newline #\Return) (second view))
           (cddr view))))
