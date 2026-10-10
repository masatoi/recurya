;;;; specs/game/notebook-jsonb.lisp --- cl-spec contracts for the cells JSONB cache.
;;;;
;;;; The notebook.cells JSONB column caches parsed cells: CELL->JSONB-FORM
;;;; writes one JSON object per cell, jzon stringifies and parses it, and
;;;; JSONB-HASH->CELL reads it back.  Read-back cells seed
;;;; PARSE-NOTEBOOK-BODY's EXISTING-CELLS so cell ids (the keys of learner
;;;; progress) survive edits.  Design doc:
;;;; docs/superpowers/specs/2026-10-11-cl-spec-jsonb-cells-design.md

(defpackage #:recurya/specs/game/notebook-jsonb
  (:use #:cl)
  (:import-from #:cl-spec/main
                #:defspec
                #:defspec-function
                #:defproperty
                #:defgenerator)
  (:import-from #:cl-spec/src/backends/check-it)
  (:import-from #:recurya/specs/game/notebook
                #:stored-cell
                #:cell-view
                #:test-case-view)
  (:import-from #:recurya/game/notebook
                #:cell-id
                #:cell-kind
                #:cell-body
                #:cell-description
                #:cell-test-cases
                #:cell-gated-p)
  (:import-from #:recurya/game/notebook-jsonb
                #:cell->jsonb-form
                #:jsonb-hash->cell)
  (:import-from #:com.inuoe.jzon
                #:stringify
                #:parse)
  (:import-from #:alexandria
                #:hash-table-keys))
(in-package #:recurya/specs/game/notebook-jsonb)

(defparameter *kind-names*
  '((:prose . "prose") (:code-eval . "code-eval") (:code-exercise . "code-exercise")
    (:code-solution . "code-solution") (:scene . "scene"))
  "JSON name of each notebook cell kind: the keyword's name in lower case, the
strings the cell editor (resources/static/js/cell-editor.js) switches on.")

(defparameter *cell-keys*
  '("body" "cell-id" "description" "gated" "kind" "test-cases")
  "The keys of one stored cell object, sorted.")

(defparameter *test-case-keys*
  '("description" "expected" "input")
  "The keys of one stored test-case object, sorted.")

(defun sorted-keys (table)
  "TABLE's keys as a sorted list of strings."
  (sort (hash-table-keys table) #'string<))

(defun test-case-form-matches-p (form test-case)
  "True when FORM stores exactly TEST-CASE's input, expected and description."
  (and (hash-table-p form)
       (equal (sorted-keys form) *test-case-keys*)
       (equal (list (gethash "input" form)
                    (gethash "expected" form)
                    (gethash "description" form))
              (test-case-view test-case))))

(defun jsonb-form-matches-p (form cell)
  "True when FORM is the stored object the design doc specifies for CELL."
  (and (hash-table-p form)
       (equal (sorted-keys form) *cell-keys*)
       (equal (gethash "cell-id" form) (or (cell-id cell) ""))
       (equal (gethash "kind" form) (cdr (assoc (cell-kind cell) *kind-names*)))
       (equal (gethash "body" form) (cell-body cell))
       (equal (gethash "description" form) (cell-description cell))
       (eq (gethash "gated" form) (cell-gated-p cell))
       (let ((forms (gethash "test-cases" form)))
         (and (listp forms)
              (= (length forms) (length (cell-test-cases cell)))
              (every #'test-case-form-matches-p forms (cell-test-cases cell))))))

(defspec-function cell->jsonb-form
  "A cell is stored as an object with exactly the keys cell-id, kind, body,
description, gated and test-cases: the id (\"\" for NIL), the kind's lower-case
name, the body and description unchanged, gated as T or NIL, and the test cases
in order as objects with exactly input, expected and description."
  (:args (input-cell stored-cell))
  (:returns (type hash-table))
  (:post (jsonb-form-matches-p result input-cell)))

(defun stored-view (cell)
  "CELL as (ID KIND BODY DESCRIPTION TEST-CASE-VIEWS GATED-P), comparable with
EQUAL; a NIL id reads as \"\", as the JSONB column stores it."
  (cons (or (cell-id cell) "") (cell-view cell)))

(defun jsonb-round-trip (cell)
  "CELL written as the JSONB column stores it and read back: CELL->JSONB-FORM,
jzon stringify, jzon parse, JSONB-HASH->CELL."
  (jsonb-hash->cell (parse (stringify (cell->jsonb-form cell)))))

(defproperty cell-jsonb-roundtrip ((input-cell stored-cell))
  "A cell written to the JSONB column and read back keeps its id, kind, body,
description, test cases and gate, whatever strings its fields hold."
  (:about cell->jsonb-form)
  (:kind :roundtrip)
  (:trials (:smoke 100 :normal 500))
  (equal (stored-view (jsonb-round-trip input-cell)) (stored-view input-cell)))
