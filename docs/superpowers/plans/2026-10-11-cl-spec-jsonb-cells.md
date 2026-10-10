# cl-spec JSONB `cells` Contracts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Contract the notebook `cells` JSONB conversion (shape, JSON round trip, null/missing tolerance, cell-id preservation across edits, cell separator) with cl-spec, and make `jsonb-hash->cell` tolerant of JSON null and unknown kinds.

**Architecture:** A new contract file `specs/game/notebook-jsonb.lisp` (package `recurya/specs/game/notebook-jsonb`, never loaded by production) holds the function specs for `cell->jsonb-form` / `jsonb-hash->cell` and the round-trip and id-preservation properties; generators for arbitrary stored cells go in `specs/game/notebook.lisp`; the separator property goes in `specs/game/notebook-parser.lisp`. The existing Rove harness `tests/specs/contracts.lisp` runs everything once the names are added to its expected lists. `jsonb-hash->cell` in `game/notebook-jsonb.lisp` is rewritten after its contract is seen red.

**Tech Stack:** SBCL, cl-spec (`cl-spec/main`, check-it backend), Rove, jzon (`com.inuoe.jzon`), package-inferred ASDF, cl-mcp tools.

Design: `docs/superpowers/specs/2026-10-11-cl-spec-jsonb-cells-design.md`.

## Global Constraints

- Lisp files (`.lisp`/`.asd`) are read and edited ONLY with cl-mcp tools (`lisp-read-file`, `clgrep-search`, `lisp-edit-form`, `lisp-patch-form`, `fs-write-file` for brand-new files only, `lisp-check-parens`). Never Read/Edit/Write/grep/sed them. Call `fs-set-project-root` with `/home/wiz/recurya` first.
- Allowed shell commands: `git`, `mallet`. Run tests with the cl-mcp `run-tests` tool, never `ros`/`sbcl`.
- Do NOT use `load-system` with `clear_fasls: true` in this project: `.qlot/` lives inside the project tree, so it deletes dependency FASLs and breaks the worker. If the worker gets into a bad state, `pool-kill-worker` with `reset: true`, then `load-system` `cl-spec/check-it`.
- Do not `repl-eval` anything that touches the global DB connection (the web server runs in the same worker).
- Contract files never depend on production code being changed for them, and production `recurya` never depends on `recurya/specs/*`.
- Oracles must not call the function under test or its helpers to compute expected values; expected values come from the design doc / docstrings.
- Generators build fresh objects every trial.
- Never weaken a contract to make it pass. If a contract fails unexpectedly, stop and report.
- In a `defspec-function`, never name an `:args` parameter with a symbol imported from another package (e.g. `cell`): cl-spec resolves `result` in the parameter's home package and refuses the form (`cannot tell which symbol names the return value`). Use local names such as `input-cell`, `table`.
- Style: 2-space indent, ≤100 columns, docstrings on every defun/defparameter/generator, no `::` (use `:import-from` for internal symbols), no runtime `eval`/`intern`.
- Lint: `mallet <files>` must print `No problems found.` for every file you touch.
- Commit messages end with: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
- Branch: `feat/cl-spec-jsonb` (already checked out). Do not push.

---

### Task 1: Stored-cell generator, `cell->jsonb-form` spec and JSON round-trip property

**Files:**
- Modify: `specs/game/notebook.lisp` (defpackage exports/imports; add forms after `random-canonical-cell`)
- Create: `specs/game/notebook-jsonb.lisp`
- Modify: `specs/all.lisp` (defpackage)
- Modify: `tests/specs/contracts.lisp` (`*expected-properties*`, `*expected-function-specs*`)

**Interfaces:**
- Produces (exported from `recurya/specs/game/notebook`): `random-canonical-cell` (existing function, now exported), `test-case-view` (existing, now exported), `stored-cell` (new generator + spec name).
- Produces (in `recurya/specs/game/notebook-jsonb`): `stored-view (cell) -> (ID KIND BODY DESCRIPTION TEST-CASE-VIEWS GATED-P)`, `jsonb-round-trip (cell) -> cell`, `*kind-names*`. Tasks 2 and 3 add forms to this file and use these.

- [ ] **Step 1: Export helpers and add the stored-cell generator in `specs/game/notebook.lisp`**

Patch the defpackage (`lisp-patch-form`, form_type `defpackage`, form_name `recurya/specs/game/notebook`):

old_text:
```lisp
  (:import-from #:recurya/game/notebook
                #:make-cell
```
new_text:
```lisp
  (:import-from #:recurya/game/notebook
                #:cell
                #:make-cell
```

old_text:
```lisp
  (:export #:canonical-cells
```
new_text:
```lisp
  (:export #:random-canonical-cell
           #:test-case-view
           #:stored-cell
           #:canonical-cells
```

Then insert after the `defun random-canonical-cell` form (`lisp-edit-form`, operation `insert_after`, form_type `defun`, form_name `random-canonical-cell`):

```lisp
(defparameter *stored-strings*
  (vector "" "x" "foo bar" (format nil "line1~%line2") "say \"hi\"" "back\\slash"
          (format nil "tab~Chere" #\Tab) "λ ラムダ" "===prose===" "  padded  " "null" "false")
  "Pieces of strings a JSONB field must carry unchanged: empty, line breaks,
quotes, backslash, tab, non-ASCII, fence-like text, outer spaces, and text
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
```

Run `lisp-check-parens` on `specs/game/notebook.lisp`.

- [ ] **Step 2: Create `specs/game/notebook-jsonb.lisp`**

Write the whole file with `fs-write-file` (new file), then `lisp-check-parens`:

```lisp
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
```

- [ ] **Step 3: Register the file and the expected names**

`specs/all.lisp` defpackage (`lisp-patch-form`, form_type `defpackage`, form_name `recurya/specs/all`):

old_text:
```lisp
  (:import-from #:recurya/specs/game/notebook-parser))
```
new_text:
```lisp
  (:import-from #:recurya/specs/game/notebook-parser)
  (:import-from #:recurya/specs/game/notebook-jsonb))
```

`tests/specs/contracts.lisp` (`lisp-patch-form`, form_type `defparameter`):

form_name `*expected-properties*`, old_text:
```lisp
    ("RECURYA/SPECS/GAME/NOTEBOOK-PARSER" . "NOTEBOOK-ROUNDTRIP-IDEMPOTENT"))
```
new_text:
```lisp
    ("RECURYA/SPECS/GAME/NOTEBOOK-PARSER" . "NOTEBOOK-ROUNDTRIP-IDEMPOTENT")
    ("RECURYA/SPECS/GAME/NOTEBOOK-JSONB" . "CELL-JSONB-ROUNDTRIP"))
```

form_name `*expected-function-specs*`, old_text:
```lisp
    ("RECURYA/GAME/NOTEBOOK-PARSER" . "PARSE-FENCE-HEADER"))
```
new_text:
```lisp
    ("RECURYA/GAME/NOTEBOOK-PARSER" . "PARSE-FENCE-HEADER")
    ("RECURYA/GAME/NOTEBOOK-JSONB" . "CELL->JSONB-FORM"))
```

- [ ] **Step 4: Load and run**

1. `load-system` `{"system":"cl-spec/check-it"}` (once per worker).
2. `load-system` `{"system":"recurya/specs/all"}` — expect success with no full WARNING.
3. `spec-check` `{"function":"recurya/game/notebook-jsonb:cell->jsonb-form","trials":200}` — expect passed.
4. `spec-check` `{"property":"recurya/specs/game/notebook-jsonb::cell-jsonb-roundtrip","profile":"normal"}` — expect passed.
5. `run-tests` `{"system":"recurya/tests/specs/contracts"}` — expect 3 passed, 0 failed.

These pass on the current implementation: `cell->jsonb-form` already matches the design, and the round trip only feeds it well-formed JSON. If either fails, stop and report the counterexample.

- [ ] **Step 5: Lint and commit**

```bash
mallet specs/game/notebook.lisp specs/game/notebook-jsonb.lisp specs/all.lisp tests/specs/contracts.lisp
git add specs/game/notebook.lisp specs/game/notebook-jsonb.lisp specs/all.lisp tests/specs/contracts.lisp
git commit -m "feat(specs): cell->jsonb-form shape and JSONB round-trip contracts

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: `jsonb-hash->cell` contract (red), then make it null-tolerant (green)

**Files:**
- Modify: `specs/game/notebook-jsonb.lisp` (append forms)
- Modify: `tests/specs/contracts.lisp` (`*expected-function-specs*`)
- Modify: `game/notebook-jsonb.lisp` (replace `jsonb-hash->cell`, add helpers before it)
- Modify: `utils/common.lisp` (`parse-json` docstring only)
- Modify: `tests/game/notebook.lisp` (add one deftest after `gated-survives-jsonb-json-round-trip`)
- Modify: `docs/superpowers/specs/2026-10-11-cl-spec-jsonb-cells-design.md` (kind matching wording)

**Interfaces:**
- Consumes (Task 1, same file): `*kind-names*`, `stored-view`.
- Produces: `pick (sequence)` in `recurya/specs/game/notebook-jsonb` (Task 3 uses it); `stored-hash` generator/spec; internal helpers in `recurya/game/notebook-jsonb`: `*cell-kinds-by-name*`, `json-string`, `json-cell-kind`, `json-list`.

- [ ] **Step 1: Append the stored-hash generator and the function spec**

Import edits first (`lisp-patch-form`, form_type `defpackage`):

1. `specs/game/notebook.lisp`, form_name `recurya/specs/game/notebook`: old_text `  (:export #:random-canonical-cell` → new_text
   ```
     (:export #:random-canonical-cell
              #:random-stored-string
   ```
2. `specs/game/notebook-jsonb.lisp`, form_name `recurya/specs/game/notebook-jsonb`:
   - old_text `                #:defgenerator)` → new_text
     ```
                     #:defgenerator
                     #:validp)
     ```
   - old_text `                #:stored-cell` → new_text
     ```
                     #:stored-cell
                     #:random-stored-string
     ```
   - old_text `  (:import-from #:cl-spec/src/backends/check-it)` → new_text
     ```
       (:import-from #:cl-spec/src/backends/check-it)
       (:import-from #:recurya/specs/domain
                     #:notebook-cell-kind)
     ```

Then insert after the property (`lisp-edit-form` `insert_after`, form_type `defproperty`, form_name `cell-jsonb-roundtrip`):

```lisp
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
```

NOTE on `(:returns (type recurya/game/notebook:cell))`: the package-qualified external symbol is fine (single colon). Alternatively import `cell` from `recurya/game/notebook` — but then do not use it as a parameter name.

Add to `tests/specs/contracts.lisp` `*expected-function-specs*`: old_text
```lisp
    ("RECURYA/GAME/NOTEBOOK-JSONB" . "CELL->JSONB-FORM"))
```
new_text
```lisp
    ("RECURYA/GAME/NOTEBOOK-JSONB" . "CELL->JSONB-FORM")
    ("RECURYA/GAME/NOTEBOOK-JSONB" . "JSONB-HASH->CELL"))
```

- [ ] **Step 2: Add the ordinary regression test**

`lisp-edit-form` `insert_after` in `tests/game/notebook.lisp`, form_type `deftest`, form_name `gated-survives-jsonb-json-round-trip`:

```lisp
(deftest jsonb-hash->cell-reads-null-and-unknown-as-defaults
  (testing "JSON null, missing keys and an unknown kind read as defaults, not errors"
    (let ((cell (recurya/game/notebook-jsonb:jsonb-hash->cell
                 (recurya/utils/common:parse-json
                  "{\"cell-id\":null,\"kind\":\"bogus\",\"body\":null,
                    \"description\":null,\"gated\":null,\"test-cases\":null}"))))
      (ok (equal "" (cell-id cell)))
      (ok (eq :prose (cell-kind cell)))
      (ok (equal "" (cell-body cell)))
      (ok (null (cell-gated-p cell)) "JSON null gate is NIL, not T")
      (ok (null (cell-test-cases cell))))))
```

- [ ] **Step 3: See it red**

1. `load-system` `{"system":"recurya/specs/all"}`.
2. `spec-check` `{"function":"recurya/game/notebook-jsonb:jsonb-hash->cell","trials":200}` — expect status `error` (TYPE-ERROR from a null field) or `failed`. Record the status and seed for the report.
3. `run-tests` `{"system":"recurya/tests/game/notebook"}` — expect the new test to fail.

If the function spec PASSES here, stop and report: the generator is not producing nulls.

- [ ] **Step 4: Rewrite `jsonb-hash->cell`**

In `game/notebook-jsonb.lisp`, insert before `defun jsonb-hash->cell` (`lisp-edit-form` `insert_before`, form_type `defun`, form_name `jsonb-hash->cell`):

```lisp
(defparameter *cell-kinds-by-name*
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
```

Replace `jsonb-hash->cell` (`lisp-edit-form` `replace`, form_type `defun`, form_name `jsonb-hash->cell`):

```lisp
(defun jsonb-hash->cell (h)
  "Reconstruct a cell struct from H, one object of the notebook.cells JSONB
column as jzon parses it, normally written by `cell->jsonb-form'. Used to seed
parse-notebook-body's existing-cells so cell ids stay stable across edits.

Legacy and hand-written rows are tolerated: a missing key, a JSON null (jzon's
symbol NULL) or any non-string value reads as \"\" for cell-id, body,
description and each test-case field; kind matches the five cell kind names
ignoring case and anything else reads as :prose; gated-p is T only for JSON
true (false, null, the legacy string \"false\" and a missing key read as NIL);
test-cases reads each object of an array in order, and anything else reads as
no test cases."
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
```

- [ ] **Step 5: Fix the `parse-json` docstring**

`lisp-patch-form` on `utils/common.lisp`, form_type `defun`, form_name `parse-json`:

old_text:
```
  - JSON booleans become T/NIL
  - JSON null becomes NIL
```
new_text:
```
  - JSON true becomes T and false becomes NIL
  - JSON null becomes the symbol NULL (CL:NULL), which is true: test
    fields with STRINGP and the like, not for NIL
```

- [ ] **Step 6: Update the design doc wording**

In `docs/superpowers/specs/2026-10-11-cl-spec-jsonb-cells-design.md` (a Markdown file: use the Edit tool), replace
`- kind: 既知 5 種の小文字名ならその keyword。`
with
`- kind: 5 種の名前に大小無視で一致すればその keyword (現行の string-upcase による受理を保つ)。`

- [ ] **Step 7: See it green**

1. `load-system` `{"system":"recurya"}` (force reload of the production change; no `clear_fasls`).
2. `load-system` `{"system":"recurya/specs/all"}`.
3. `spec-check` `{"function":"recurya/game/notebook-jsonb:jsonb-hash->cell","trials":300}` — expect passed.
4. `spec-check` `{"property":"recurya/specs/game/notebook-jsonb::cell-jsonb-roundtrip","profile":"normal"}` — expect passed.
5. `run-tests` `{"system":"recurya/tests/game/notebook"}` — all pass.
6. `run-tests` `{"system":"recurya/tests/specs/contracts"}` — 3 passed.

- [ ] **Step 8: Lint and commit**

```bash
mallet specs/game/notebook.lisp specs/game/notebook-jsonb.lisp tests/specs/contracts.lisp game/notebook-jsonb.lisp utils/common.lisp tests/game/notebook.lisp
git add specs/game/notebook.lisp specs/game/notebook-jsonb.lisp tests/specs/contracts.lisp game/notebook-jsonb.lisp utils/common.lisp tests/game/notebook.lisp docs/superpowers/specs/2026-10-11-cl-spec-jsonb-cells-design.md
git commit -m "fix(notebook-jsonb): read JSON null and unknown kinds as defaults (F-B1, F-B2)

Contract jsonb-hash->cell over stored objects with valid, null and missing
fields; it was red (null description/test-cases signalled TYPE-ERROR, null gated
read as T, unknown kinds were interned).  Look kinds up in a table instead of
interning, and correct parse-json's docstring about JSON null (F-B3).

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Cell-id preservation across edits, and the cell separator

**Files:**
- Modify: `specs/game/notebook-jsonb.lisp` (imports; append forms)
- Modify: `specs/game/notebook-parser.lisp` (append one property)
- Modify: `tests/specs/contracts.lisp` (`*expected-properties*`)

**Interfaces:**
- Consumes: `random-canonical-cell` (exported in Task 1), `jsonb-round-trip`, `pick` (Task 2, same file), `canonical-cells` (exported from `recurya/specs/game/notebook`, already imported by notebook-parser spec).

- [ ] **Step 1: Add the id-edit scenario and the property**

Import edits (`lisp-patch-form` on `specs/game/notebook-jsonb.lisp`, form_type `defpackage`, form_name `recurya/specs/game/notebook-jsonb`):

- old_text `                #:random-stored-string` → new_text
  ```
                  #:random-stored-string
                  #:random-canonical-cell
  ```
- old_text `  (:import-from #:com.inuoe.jzon` → new_text
  ```
    (:import-from #:recurya/game/notebook-parser
                  #:parse-notebook-body
                  #:cells->body-md)
    (:import-from #:com.inuoe.jzon
  ```

The cell accessors (`cell-id`, `cell-kind`, `cell-body`, `cell-description`) are already imported, and `setf` works through them.

Append after `defspec-function jsonb-hash->cell` (`lisp-edit-form` `insert_after`, form_type `defspec-function`, form_name `jsonb-hash->cell`):

```lisp
(defun same-match-key-p (a b)
  "True when cells A and B agree on (KIND BODY DESCRIPTION), the triple
PARSE-NOTEBOOK-BODY's docstring says carries a cell id over."
  (and (eq (cell-kind a) (cell-kind b))
       (string= (cell-body a) (cell-body b))
       (string= (cell-description a) (cell-description b))))

(defun append-word (string)
  "STRING with \" z\" appended: still canonical, but a different value."
  (concatenate 'string string " z"))

(defun near-duplicate (cell)
  "A fresh id-less copy of the canonical CELL differing in exactly one field
of its match key: the body, or the description (exercise and solution cells),
or the kind (between the description-less kinds)."
  (let ((copy (copy-structure cell))
        (kind (cell-kind cell)))
    (setf (cell-id copy) nil)
    (cond ((zerop (random 2))
           (setf (cell-body copy) (append-word (cell-body copy))))
          ((member kind '(:code-exercise :code-solution))
           (setf (cell-description copy) (append-word (cell-description copy))))
          (t
           (setf (cell-kind copy) (pick (remove kind #(:prose :code-eval :scene))))))
    copy))

(defgenerator id-edit-scenario ()
  "(CELLS NEW-CELL POSITION): 1-6 fresh canonical CELLS with ids id-0, id-1, ...
(a third of the time one of them is duplicated), a canonical NEW-CELL whose
match key differs from every cell in CELLS (half the time a near duplicate of
one of them), and the POSITION at which an author inserts it."
  (let ((cells (loop repeat (1+ (random 5)) collect (random-canonical-cell))))
    (when (zerop (random 3))
      (let ((copy (copy-structure (pick cells))))
        (push copy (cdr (nthcdr (random (length cells)) cells)))))
    (loop for cell in cells
          for i from 0
          do (setf (cell-id cell) (format nil "id-~D" i)))
    (list cells
          (loop for new = (if (zerop (random 2))
                              (random-canonical-cell)
                              (near-duplicate (pick cells)))
                unless (find new cells :test #'same-match-key-p)
                  return new)
          (random (1+ (length cells))))))

(defspec id-edit-scenario list (:generator id-edit-scenario))

(defproperty edit-preserves-cell-ids ((scenario id-edit-scenario))
  "Inserting one new cell and re-parsing, with the stored cells read back from
the JSONB column as EXISTING-CELLS, keeps every existing cell's id in order,
gives the new cell a fresh non-empty id, and leaves all ids distinct."
  (:about parse-notebook-body)
  (:kind :invariant)
  (:trials (:smoke 200 :normal 1000))
  (destructuring-bind (cells new-cell position) scenario
    (let ((existing (mapcar #'jsonb-round-trip cells))
          (edited (append (subseq cells 0 position) (list new-cell) (nthcdr position cells)))
          (old-ids (mapcar #'cell-id cells)))
      (multiple-value-bind (parsed errors)
          (parse-notebook-body (cells->body-md edited) existing)
        (let ((ids (mapcar #'cell-id parsed)))
          (and (null errors)
               (= (length ids) (length edited))
               (equal (append (subseq ids 0 position) (nthcdr (1+ position) ids))
                      old-ids)
               (let ((new-id (nth position ids)))
                 (and (stringp new-id)
                      (plusp (length new-id))
                      (not (member new-id old-ids :test #'equal))))
               (= (length ids) (length (remove-duplicates ids :test #'equal)))))))))
```

Smoke is 200 trials on purpose: a mutation that ignores the description when matching ids is caught only when a description-only near duplicate lands before its original (about 1 trial in 20); 50 trials missed it in prototyping.

- [ ] **Step 2: Add the separator property**

Append to `specs/game/notebook-parser.lisp` after `defproperty notebook-roundtrip-idempotent`:

```lisp
(defproperty body-md-cell-separator ((cells canonical-cells))
  "CELLS->BODY-MD separates cells by exactly one blank line and emits no
leading or trailing newline: the whole rendering is the single-cell renderings
joined by one blank line, and each of those starts and ends with a non-newline."
  (:about cells->body-md)
  (:kind :invariant)
  (:trials (:smoke 50 :normal 300))
  (let ((singles (mapcar (lambda (cell) (cells->body-md (list cell))) cells)))
    (and (equal (cells->body-md cells) (format nil "~{~A~^~%~%~}" singles))
         (every (lambda (single)
                  (and (plusp (length single))
                       (char/= (char single 0) #\Newline)
                       (char/= (char single (1- (length single))) #\Newline)))
                singles))))
```

- [ ] **Step 3: Expected names**

`tests/specs/contracts.lisp` `*expected-properties*`: old_text
```lisp
    ("RECURYA/SPECS/GAME/NOTEBOOK-JSONB" . "CELL-JSONB-ROUNDTRIP"))
```
new_text
```lisp
    ("RECURYA/SPECS/GAME/NOTEBOOK-JSONB" . "CELL-JSONB-ROUNDTRIP")
    ("RECURYA/SPECS/GAME/NOTEBOOK-JSONB" . "EDIT-PRESERVES-CELL-IDS")
    ("RECURYA/SPECS/GAME/NOTEBOOK-PARSER" . "BODY-MD-CELL-SEPARATOR"))
```

- [ ] **Step 4: Run**

1. `load-system` `{"system":"recurya/specs/all"}`.
2. `spec-check` `{"property":"recurya/specs/game/notebook-jsonb::edit-preserves-cell-ids","profile":"normal"}` — passed.
3. `spec-check` `{"property":"recurya/specs/game/notebook-parser::body-md-cell-separator","profile":"normal"}` — passed.
4. `run-tests` `{"system":"recurya/tests/specs/contracts"}` — 3 passed.

- [ ] **Step 5: Lint and commit**

```bash
mallet specs/game/notebook-jsonb.lisp specs/game/notebook-parser.lisp tests/specs/contracts.lisp
git add specs/game/notebook-jsonb.lisp specs/game/notebook-parser.lisp tests/specs/contracts.lisp
git commit -m "feat(specs): cell-id preservation across edits and cell separator contracts

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Mutation checks, full suite, docs and feedback

**Files:**
- Modify: `docs/feedback/cl-mcp-cl-spec.md` (append entries; Markdown — Edit/Bash heredoc append is fine)
- Modify: `docs/superpowers/specs/2026-10-11-cl-spec-jsonb-cells-design.md` (append a "検証結果" section)

- [ ] **Step 1: Mutation checks (worker only; files unchanged)**

For each mutation, redefine via `repl-eval` (save the original with `fdefinition` and restore in `unwind-protect`), run the named check, and record the status. Each must NOT be `:passed`:

| Mutation | Check |
|---|---|
| `recurya/game/notebook-jsonb:jsonb-hash->cell` back to the pre-Task-2 body (`git show main:game/notebook-jsonb.lisp`) | `check-function` jsonb-hash->cell, 200 trials |
| `cell->jsonb-form` without the `"gated"` key (wrap the original and `remhash "gated"`) | `check-function` cell->jsonb-form, 100 trials |
| `recurya/game/notebook-parser::take-matching-cell-id` ignoring DESCRIPTION (call the original with `""` and with copies of EXISTING-CELLS whose description is `""`) | `run-property` edit-preserves-cell-ids `:smoke`, 5 runs: all non-passed |
| `take-matching-cell-id` last-fit (call the original on the reversed list and reverse the remainder) | `run-property` edit-preserves-cell-ids `:smoke` |
| `cells->body-md` joining single renderings with one newline | `run-property` body-md-cell-separator `:smoke` |

`repl-eval` may use `::` for these throwaway probes only. Restore everything afterwards with `load-system` `{"system":"recurya"}` and `load-system` `{"system":"recurya/specs/all"}`, then confirm `run-tests` `recurya/tests/specs/contracts` passes.

- [ ] **Step 2: Full suite**

`run-tests` `{"system":"recurya/tests","timeout_seconds":900}` — expect all pass (471 = 470 + the new notebook test). Report the exact numbers.

- [ ] **Step 3: Record results**

Append to the design doc:

```markdown
## 検証結果

- 契約: Function Spec 2 (`cell->jsonb-form`, `jsonb-hash->cell`)、Property 3
  (`cell-jsonb-roundtrip`, `edit-preserves-cell-ids`, `body-md-cell-separator`)。
- `jsonb-hash->cell` は変更前に赤 (<status と seed を記入>)、変更後に緑。
- ミューテーション: <Step 1 の表の各結果を記入>。
- 全スイート: <passed>/<failed>。
```

Fill in the placeholders with the actual values you observed (no guessing).

Append to `docs/feedback/cl-mcp-cl-spec.md` (keep the existing entry format; append at the end):

```markdown

## 2026-10-11 — `:args` の引数名に他パッケージのシンボルを使うと `:post` の RESULT が解決できない
- **ツール/対象**: cl-spec `defspec-function`
- **分類**: docs
- **状況**: `(:args (cell stored-cell))` の `cell` が `recurya/game/notebook` から import したシンボルだった。
- **起きたこと**: `INVALID-FUNCTION-SPEC-FORM`: "cannot tell which symbol names the return value: :post uses RESULT, and the contract's own package resolves RESULT to RECURYA/GAME/NOTEBOOK::RESULT"。契約のパッケージは引数シンボルのホームパッケージから推定されるらしい。
- **期待**: 契約を書いたファイルの `*package*` で RESULT を解決する、またはエラー文で「引数名が別パッケージのシンボル」と直接指摘する。
- **回避策**: 引数名をローカルなシンボルにする (`input-cell`)。

## 2026-10-11 — ハッシュテーブルの反例が `#<hash-table ...>` としか表示されない
- **ツール/対象**: cl-spec `check-function` / `spec-check` の counterexample
- **分類**: UX
- **状況**: `jsonb-hash->cell` の契約は jzon がパースしたハッシュテーブルを引数に取る。
- **起きたこと**: 反例が `(table #<hash-table :TEST equal :COUNT 6 {...}>)` と表示され、中身が分からない。
- **期待**: ハッシュテーブル (や構造体以外の不透明オブジェクト) の中身を反例表示で展開する、または生成器が「表示用の表現」を添えられる仕組み。
- **回避策**: inspect-object で反例を辿る、または生成器の元 JSON テキストを別途再現する。

## 2026-10-11 — smoke の試行回数ではミューテーションを見逃す Property があった
- **ツール/対象**: cl-spec `defproperty` の `:trials` (recurya の契約設計の知見)
- **分類**: idea
- **状況**: `edit-preserves-cell-ids` を試作し、id 照合で description を無視する変異を入れた。
- **起きたこと**: 生成器が「description だけ違う近似重複」を作る確率が低く、smoke 50 回では緑のまま。:normal 300 回で初めて赤になった。近似重複を意図的に作る生成器に直し、smoke を 200 回にして 5 回連続で赤を確認。
- **期待**: ケースや「興味のある分布」の到達回数を Property でも報告する仕組み (Function Spec の case report に相当するもの)。
- **回避策**: 生成器で境界的な入力を明示的に作り、ミューテーションで感度を確かめる。
```

Also add any further cl-mcp/cl-spec issue you actually hit while implementing, in the same format.

- [ ] **Step 4: Commit**

```bash
git add docs/feedback/cl-mcp-cl-spec.md docs/superpowers/specs/2026-10-11-cl-spec-jsonb-cells-design.md
git commit -m "docs: record sub-project B verification and cl-spec feedback

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
