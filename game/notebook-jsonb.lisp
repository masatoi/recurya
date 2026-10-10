;;;; game/notebook-jsonb.lisp --- Cell <-> JSONB hash-table conversion.
;;;;
;;;; Pure conversion between notebook cell structs and the hash-table
;;;; shape stored in the notebook.cells JSONB column. Lives at the game
;;;; layer (no web dependency) so both web/routes and the official-content
;;;; seeder can share it.

(defpackage #:recurya/game/notebook-jsonb
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:cell-id
                #:cell-kind
                #:cell-body
                #:cell-description
                #:cell-test-cases
                #:cell-gated-p
                #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case
                #:test-case-input
                #:test-case-expected
                #:test-case-description)
  (:export #:cell->jsonb-form
           #:jsonb-hash->cell))

(in-package #:recurya/game/notebook-jsonb)

(defun cell->jsonb-form (cell)
  "Convert a cell struct into a hash-table that jzon serializes as a JSON
object. Pairs with `jsonb-hash->cell' to round-trip cells through the
JSONB column while preserving stable cell ids across edits."
  (let ((h (make-hash-table :test 'equal)))
    (setf (gethash "cell-id"     h) (or (cell-id cell) "")
          (gethash "kind"        h) (string-downcase (symbol-name (cell-kind cell)))
          (gethash "body"        h) (or (cell-body cell) "")
          (gethash "description" h) (cell-description cell)
          (gethash "gated"       h) (and (cell-gated-p cell) t)
          (gethash "test-cases"  h)
          (mapcar (lambda (tc)
                    (let ((th (make-hash-table :test 'equal)))
                      (setf (gethash "input"       th) (test-case-input tc)
                            (gethash "expected"    th) (test-case-expected tc)
                            (gethash "description" th) (test-case-description tc))
                      th))
                  (cell-test-cases cell)))
    h))

(defparameter *cell-kinds-by-name*
  ;; A new cell kind must be added here too: see the `cell' struct docstring in
  ;; game/notebook.lisp and the ecase in web/ui/notebook.lisp `render-cell'.
  ;; Otherwise it reads back as :prose and loses its id carry-over.
  '(("prose" . :prose) ("code-eval" . :code-eval) ("code-exercise" . :code-exercise)
    ("code-solution" . :code-solution) ("scene" . :scene))
  "Stored kind name -> cell kind keyword, the inverse of `cell->jsonb-form'.")

(defun json-string (table key)
  "TABLE's value for KEY when it is a string; otherwise (missing, JSON null as
jzon's symbol NULL, or any other value) the empty string."
  (let ((value (gethash key table)))
    (if (stringp value) value "")))

(defun json-cell-kind (name)
  "The cell kind whose stored NAME matches ignoring case, or :prose for an
empty, unknown or non-string NAME."
  (or (and (stringp name)
           (cdr (assoc name *cell-kinds-by-name* :test #'string-equal)))
      :prose))

(defun json-list (value)
  "VALUE as a list when it is an array (a vector, as jzon parses it) or a list;
otherwise (JSON null, false, a string, a missing key) the empty list."
  (typecase value
    (string '())
    (sequence (coerce value 'list))
    (t '())))

(defun jsonb-hash->cell (h)
  "Reconstruct a cell struct from H, one object of the notebook.cells JSONB
column as jzon parses it, normally written by `cell->jsonb-form'. Used to seed
parse-notebook-body's existing-cells so cell ids stay stable across edits.

Legacy and hand-written rows are tolerated: a missing key, a JSON null (jzon's
symbol NULL) or any non-string value reads as \"\" for cell-id, body,
description and each test-case field; kind matches the five cell kind names
ignoring case and anything else reads as :prose; gated-p is T only for JSON
true (false, null, the legacy string \"false\" and a missing key read as NIL);
test-cases reads each object of an array in order, skipping other elements,
and anything else reads as no test cases."
  (make-cell
   :id (json-string h "cell-id")
   :kind (json-cell-kind (gethash "kind" h))
   :body (json-string h "body")
   :description (json-string h "description")
   :gated-p (eq (gethash "gated" h) t)
   :test-cases (loop for th in (json-list (gethash "test-cases" h))
                     when (hash-table-p th)
                       collect (make-test-case
                                :input (json-string th "input")
                                :expected (json-string th "expected")
                                :description (json-string th "description")))))
