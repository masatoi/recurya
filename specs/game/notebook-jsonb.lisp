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
                #:defgenerator
                #:validp)
  (:import-from #:cl-spec/src/backends/check-it)
  (:import-from #:recurya/specs/domain
                #:notebook-cell-kind)
  (:import-from #:recurya/specs/game/notebook
                #:stored-cell
                #:random-stored-string
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

(defun pick (sequence)
  "Return a uniformly chosen element of the non-empty SEQUENCE."
  (elt sequence (random (length sequence))))

(defun string-slot ()
  "JSON text for a string field: a string, null, or :MISSING (key left out)."
  (case (random 4)
    (0 :missing)
    (1 "null")
    (t (stringify (random-stored-string)))))

(defun kind-slot ()
  "JSON text for the kind field: a known name, a known name in other case, an
empty or unknown string, null, or :MISSING."
  (case (random 6)
    (0 :missing)
    (1 "null")
    (2 "\"\"")
    (3 (stringify (pick #("bogus" "PROSE" "Code-Eval" "solution"))))
    (t (stringify (cdr (pick *kind-names*))))))

(defun gated-slot ()
  "JSON text for the gated field, including the legacy string \"false\"."
  (pick #(:missing "null" "true" "false" "\"false\"")))

(defun json-object (members)
  "JSON object text from MEMBERS, a list of (KEY . VALUE-TEXT); a VALUE-TEXT
of :MISSING leaves the key out."
  (format nil "{~{~A~^,~}}"
          (loop for (key . text) in members
                unless (eq text :missing)
                  collect (format nil "~A:~A" (stringify key) text))))

(defun test-case-text ()
  "JSON text for one stored test-case object with string/null/missing fields."
  (json-object (list (cons "input" (string-slot))
                     (cons "expected" (string-slot))
                     (cons "description" (string-slot)))))

(defun test-cases-slot ()
  "JSON text for the test-cases field: an array of 0-3 objects, null, false
(what jzon writes for an empty list), or :MISSING."
  (case (random 5)
    (0 :missing)
    (1 "null")
    (2 "false")
    (t (format nil "[~{~A~^,~}]" (loop repeat (random 4) collect (test-case-text))))))

(defgenerator stored-hash ()
  "A fresh stored cell object as jzon parses it, each field independently
valid, null or missing."
  (parse (json-object (list (cons "cell-id" (string-slot))
                            (cons "kind" (kind-slot))
                            (cons "body" (string-slot))
                            (cons "description" (string-slot))
                            (cons "gated" (gated-slot))
                            (cons "test-cases" (test-cases-slot))))))

(defspec stored-hash (type hash-table) (:generator stored-hash))

(defun expected-string (table key)
  "The design doc's reading of a string field: its value when a string, else \"\"."
  (let ((value (gethash key table)))
    (if (stringp value) value "")))

(defun expected-kind (table)
  "The design doc's reading of kind: a name matching one of *KIND-NAMES*
ignoring case gives that kind; anything else gives :PROSE."
  (let ((value (gethash "kind" table)))
    (or (and (stringp value) (car (rassoc value *kind-names* :test #'string-equal)))
        :prose)))

(defun expected-test-cases (table)
  "The design doc's reading of test-cases, as test-case views: each object of
an array in order, else none."
  (let ((value (gethash "test-cases" table)))
    (if (and (vectorp value) (not (stringp value)))
        (map 'list (lambda (element)
                     (list (expected-string element "input")
                           (expected-string element "expected")
                           (expected-string element "description")))
             value)
        '())))

(defun expected-view (table)
  "The STORED-VIEW the design doc requires JSONB-HASH->CELL to return for TABLE."
  (list (expected-string table "cell-id")
        (expected-kind table)
        (expected-string table "body")
        (expected-string table "description")
        (expected-test-cases table)
        (eq (gethash "gated" table) t)))

(defspec-function jsonb-hash->cell
  "Any stored cell object reads back as a cell of a notebook cell kind: string
fields keep their value and read as \"\" when missing or null; kind matches the
five names ignoring case and is :PROSE otherwise; gated is T only for JSON true;
test-cases reads each object of an array in order and nothing otherwise."
  (:args (table stored-hash))
  (:returns (type recurya/game/notebook:cell))
  (:post (and (validp 'notebook-cell-kind (cell-kind result))
              (equal (stored-view result) (expected-view table)))))
