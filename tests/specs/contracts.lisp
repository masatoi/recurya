;;;; tests/specs/contracts.lisp --- Run every project cl-spec contract under Rove.
;;;;
;;;; Loads RECURYA/SPECS/ALL, checks that the expected specs, properties and
;;;; function specs are registered and selected by the run filters, then runs
;;;; each one: properties with the :SMOKE profile, function specs with
;;;; *FUNCTION-SPEC-TRIALS* trials.  A run that never exercised its target
;;;; (zero trials, or every input refused by :PRE) fails: :SKIPPED is not
;;;; :PASSED.  A function spec also fails when a declared case was never
;;;; called.  A failure message carries the name, status, seed and
;;;; counterexample (and case coverage) so `spec-check' can replay it.

(defpackage #:recurya/tests/specs/contracts
  (:use #:cl #:rove)
  (:import-from #:recurya/specs/all)
  (:import-from #:cl-spec/main
                #:list-specs
                #:list-properties
                #:list-function-specs
                #:run-property
                #:check-function
                #:property-result-status
                #:property-result-trials
                #:property-result-seed
                #:property-result-counterexample
                #:function-check-result-rejected
                #:function-check-result-case-report)
  (:import-from #:alexandria
                #:starts-with-subseq))
(in-package #:recurya/tests/specs/contracts)

(defparameter *function-spec-trials* 50
  "Trials per function spec when run under Rove.")

(defparameter *expected-specs*
  '(("RECURYA/SPECS/DOMAIN" . "ARENA-ACTION")
    ("RECURYA/SPECS/DOMAIN" . "GRID-POSITION")
    ("RECURYA/SPECS/DOMAIN" . "NOTEBOOK-CELL-KIND")
    ("RECURYA/SPECS/DOMAIN" . "FENCE-KIND")
    ("RECURYA/SPECS/DB/DOMAIN" . "PUBLICATION-STATUS")
    ("RECURYA/SPECS/DB/DOMAIN" . "VISIBILITY")
    ("RECURYA/SPECS/DB/DOMAIN" . "VARCHAR-255")
    ("RECURYA/SPECS/DB/DOMAIN" . "SUMMARY-TEXT")
    ("RECURYA/SPECS/DB/DOMAIN" . "SUBMISSION-STATUS")
    ("RECURYA/SPECS/GAME/NOVEL" . "FLAG-VALUE"))
  "Named data specs that must be registered, as (PACKAGE . SYMBOL) names.")

(defparameter *expected-properties*
  '(("RECURYA/SPECS/GAME/ARENA" . "MANHATTAN-DISTANCE-METRIC")
    ("RECURYA/SPECS/GAME/ARENA" . "COPY-GRID-INDEPENDENT")
    ("RECURYA/SPECS/GAME/NOTEBOOK-PARSER" . "NOTEBOOK-ROUNDTRIP")
    ("RECURYA/SPECS/GAME/NOTEBOOK-PARSER" . "NOTEBOOK-ROUNDTRIP-IDEMPOTENT")
    ("RECURYA/SPECS/GAME/NOTEBOOK-JSONB" . "CELL-JSONB-ROUNDTRIP")
    ("RECURYA/SPECS/GAME/NOTEBOOK-JSONB" . "EDIT-PRESERVES-CELL-IDS")
    ("RECURYA/SPECS/GAME/NOTEBOOK-PARSER" . "BODY-MD-CELL-SEPARATOR")
    ("RECURYA/SPECS/DB/CORE" . "GENERATED-PLACEHOLDER-HANDLE-IS-PLACEHOLDER")
    ("RECURYA/SPECS/DB/COURSE-NOTEBOOKS" . "COURSE-NOTEBOOK-ORDER")
    ("RECURYA/SPECS/DB/LEARN" . "LEARN-PROGRESS-IS-A-SET")
    ("RECURYA/SPECS/DB/LEARN" . "CELL-CODE-LAST-WRITE-WINS")
    ("RECURYA/SPECS/DB/LEARN" . "MERGE-LOCALSTORAGE-RULES")
    ("RECURYA/SPECS/DB/LEARN" . "SUBMISSION-HISTORY")
    ("RECURYA/SPECS/DB/NOTEBOOKS" . "NOTEBOOK-CREATE-GET-ROUNDTRIP")
    ("RECURYA/SPECS/DB/NOTEBOOKS" . "COURSE-CREATE-GET-ROUNDTRIP")
    ("RECURYA/SPECS/DB/NOTEBOOKS" . "NOTEBOOK-SLUG-UNIQUE-PER-AUTHOR")
    ("RECURYA/SPECS/DB/NOTEBOOKS" . "NOTEBOOK-LIST-FILTERS")
    ("RECURYA/SPECS/DB/NOTEBOOKS" . "COURSE-LIST-FILTERS")
    ("RECURYA/SPECS/DB/NOTEBOOKS" . "NOTEBOOK-UPDATE-PARTIAL")
    ("RECURYA/SPECS/DB/USERS" . "PLACEHOLDER-HANDLE-NEVER-REAL")
    ("RECURYA/SPECS/DB/USERS" . "USER-CREATE-GET-ROUNDTRIP")
    ("RECURYA/SPECS/DB/USERS" . "OAUTH-LOGIN-RESOLUTION")
    ("RECURYA/SPECS/DB/USERS" . "USER-UPDATE-PARTIAL")
    ("RECURYA/SPECS/DB/NOVEL" . "PERSISTED-FLAGS-DRIVE-NEXT-SCENE")
    ("RECURYA/SPECS/DB/NOVEL" . "NOVEL-STATE-ROUNDTRIP")
    ("RECURYA/SPECS/DB/NOVEL" . "NOVEL-STATE-UPSERT-SEQUENCE")
    ("RECURYA/SPECS/DB/API-TOKENS" . "API-TOKEN-LIFECYCLE"))
  "Properties that must be registered, as (PACKAGE . SYMBOL) names.")

(defparameter *expected-function-specs*
  '(("RECURYA/GAME/ARENA" . "PARSE-ACTION")
    ("RECURYA/GAME/ARENA" . "ACTION->DELTA")
    ("RECURYA/GAME/ARENA" . "APPLY-MOVE")
    ("RECURYA/GAME/NOTEBOOK-PARSER" . "PARSE-FENCE-HEADER")
    ("RECURYA/GAME/NOTEBOOK-JSONB" . "CELL->JSONB-FORM")
    ("RECURYA/GAME/NOTEBOOK-JSONB" . "JSONB-HASH->CELL")
    ("RECURYA/DB/CORE" . "NIL->NULL")
    ("RECURYA/DB/CORE" . "NULL->NIL")
    ("RECURYA/DB/CORE" . "KEYWORD->DB-STRING")
    ("RECURYA/DB/CORE" . "FORMAT-TIMESTAMP-FOR-DB")
    ("RECURYA/DB/CORE" . "ENSURE-UUID")
    ("RECURYA/DB/CORE" . "UUID-STRING-P")
    ("RECURYA/UTILS/HANDLE" . "PLACEHOLDER-HANDLE-P")
    ("RECURYA/UTILS/HANDLE" . "RESERVED-HANDLE-P")
    ("RECURYA/GAME/NOVEL/INTERPRETER" . "INTERPRET-DIRECTIVES")
    ("RECURYA/DB/API-TOKENS" . "NORMALIZE-TOKEN-NAME"))
  "Function specs that must be registered, named by their target function.")

(defun resolve-name (entry)
  "Return the symbol named by ENTRY, a (PACKAGE-NAME . SYMBOL-NAME) pair, or NIL.
The symbol must be found in the package and that package must be its home
package, so an entry naming a package that merely re-exports it is stale."
  (let* ((package (find-package (car entry)))
         (symbol (and package (find-symbol (cdr entry) package))))
    (and symbol
         (eq (symbol-package symbol) package)
         symbol)))

(defun home-package-prefix-p (symbol prefix)
  "True when SYMBOL's home package name starts with PREFIX."
  (let ((package (symbol-package symbol)))
    (and package
         (starts-with-subseq prefix (package-name package)))))

(defun project-properties ()
  "Registered properties defined in a RECURYA/SPECS/ package."
  (remove-if-not (lambda (name) (home-package-prefix-p name "RECURYA/SPECS/"))
                 (list-properties)))

(defun project-function-specs ()
  "Registered function specs whose target lives in a RECURYA/ package."
  (remove-if-not (lambda (name) (home-package-prefix-p name "RECURYA/"))
                 (list-function-specs)))

(defun failure-report (name result)
  "Describe RESULT of checking NAME so the run can be replayed with spec-check."
  (format nil "~S: status=~S trials=~S seed=~A counterexample=~S"
          name
          (property-result-status result)
          (property-result-trials result)
          (property-result-seed result)
          (property-result-counterexample result)))

(defun property-passes-p (name)
  "Run property NAME at the :SMOKE profile.
Return (VALUES PASSED-P RESULT); PASSED-P needs :PASSED and at least one trial."
  (let ((result (run-property name :profile :smoke)))
    (values (and (eq (property-result-status result) :passed)
                 (plusp (property-result-trials result)))
            result)))

(defun never-called-cases (result)
  "Declared cases of the function-check RESULT that were never called.
Return (VALUES NAMES KNOWN-P).  KNOWN-P is NIL when cl-spec gave no usable
case report (for example :NOT-COLLECTED); NAMES is then NIL too, so an
unknown report alone does not fail a run, but FUNCTION-FAILURE-REPORT shows it."
  (let ((report (function-check-result-case-report result)))
    (if (and (consp report) (listp (getf report :cases)))
        (values (loop for case in (getf report :cases)
                      for called = (and (consp case) (getf case :called))
                      when (and (integerp called) (zerop called))
                        collect (getf case :name))
                t)
        (values nil nil))))

(defun function-failure-report (name result)
  "FAILURE-REPORT for a function spec, plus which declared cases were never
called, or that the case report was unavailable."
  (multiple-value-bind (uncalled known-p) (never-called-cases result)
    (format nil "~A ~:[case-report=unknown (~S)~;never-called-cases=~S~]"
            (failure-report name result)
            known-p
            (if known-p uncalled (function-check-result-case-report result)))))

(defun function-spec-passes-p (name)
  "Check the function spec of NAME with *FUNCTION-SPEC-TRIALS* trials.
Return (VALUES PASSED-P RESULT); PASSED-P needs :PASSED, at least one trial
that :PRE admitted, and no declared case that was never called.  A trial count
that is not an integer, or a rejection count that is neither NIL (none) nor an
integer, is unknown and fails the check."
  (let* ((result (check-function name :trials *function-spec-trials*))
         (trials (property-result-trials result))
         (rejected (or (function-check-result-rejected result) 0)))
    (values (and (eq (property-result-status result) :passed)
                 (integerp trials)
                 (integerp rejected)
                 (plusp (- trials rejected))
                 (null (never-called-cases result)))
            result)))

(defun registered-p (entry registered)
  "True when ENTRY resolves to a symbol present in the REGISTERED name list."
  (let ((symbol (resolve-name entry)))
    (and symbol (member symbol registered) t)))

(deftest expected-contracts-registered
  (testing "named data specs"
    (let ((registered (list-specs)))
      (dolist (entry *expected-specs*)
        (ok (registered-p entry registered)
            (format nil "spec ~A::~A is registered" (car entry) (cdr entry))))))
  (testing "properties"
    (let ((registered (list-properties)))
      (dolist (entry *expected-properties*)
        (ok (registered-p entry registered)
            (format nil "property ~A::~A is registered" (car entry) (cdr entry))))))
  (testing "function specs"
    (let ((registered (list-function-specs)))
      (dolist (entry *expected-function-specs*)
        (ok (registered-p entry registered)
            (format nil "function spec ~A::~A is registered" (car entry) (cdr entry))))))
  (testing "expected contracts are selected by the run filters"
    (let ((properties (project-properties))
          (function-specs (project-function-specs)))
      (dolist (entry *expected-properties*)
        (ok (registered-p entry properties)
            (format nil "property ~A::~A is in PROJECT-PROPERTIES"
                    (car entry) (cdr entry))))
      (dolist (entry *expected-function-specs*)
        (ok (registered-p entry function-specs)
            (format nil "function spec ~A::~A is in PROJECT-FUNCTION-SPECS"
                    (car entry) (cdr entry)))))))

(deftest project-properties-pass
  (ok (project-properties) "at least one project property is registered")
  (dolist (name (project-properties))
    (multiple-value-bind (passed-p result) (property-passes-p name)
      (ok passed-p (failure-report name result)))))

(deftest project-function-specs-pass
  (ok (project-function-specs) "at least one project function spec is registered")
  (dolist (name (project-function-specs))
    (multiple-value-bind (passed-p result) (function-spec-passes-p name)
      (ok passed-p (function-failure-report name result)))))
