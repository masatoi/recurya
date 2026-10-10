;;;; tests/specs/contracts.lisp --- Run every project cl-spec contract under Rove.
;;;;
;;;; Loads RECURYA/SPECS/ALL, checks that the expected specs, properties and
;;;; function specs are registered, then runs each one: properties with the
;;;; :SMOKE profile, function specs with *FUNCTION-SPEC-TRIALS* trials.  A run
;;;; that never exercised its target (zero trials, or every input refused by
;;;; :PRE) fails: :SKIPPED is not :PASSED.  A failure message carries the name,
;;;; status, seed and counterexample so `spec-check' can replay it.

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
                #:function-check-result-rejected))
(in-package #:recurya/tests/specs/contracts)

(defparameter *function-spec-trials* 50
  "Trials per function spec when run under Rove.")

(defparameter *expected-specs*
  '(("RECURYA/SPECS/DOMAIN" . "ARENA-ACTION")
    ("RECURYA/SPECS/DOMAIN" . "GRID-POSITION")
    ("RECURYA/SPECS/DOMAIN" . "NOTEBOOK-CELL-KIND")
    ("RECURYA/SPECS/DOMAIN" . "FENCE-KIND"))
  "Named data specs that must be registered, as (PACKAGE . SYMBOL) names.")

(defparameter *expected-properties* '()
  "Properties that must be registered, as (PACKAGE . SYMBOL) names.")

(defparameter *expected-function-specs* '()
  "Function specs that must be registered, named by their target function.")

(defun resolve-name (entry)
  "Return the symbol named by ENTRY, a (PACKAGE-NAME . SYMBOL-NAME) pair, or NIL."
  (let ((package (find-package (car entry))))
    (and package (find-symbol (cdr entry) package))))

(defun home-package-prefix-p (symbol prefix)
  "True when SYMBOL's home package name starts with PREFIX."
  (let ((package (symbol-package symbol)))
    (and package
         (alexandria:starts-with-subseq prefix (package-name package)))))

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

(defun function-spec-passes-p (name)
  "Check the function spec of NAME with *FUNCTION-SPEC-TRIALS* trials.
Return (VALUES PASSED-P RESULT); PASSED-P needs :PASSED and at least one trial
that :PRE admitted."
  (let* ((result (check-function name :trials *function-spec-trials*))
         (rejected (or (function-check-result-rejected result) 0)))
    (values (and (eq (property-result-status result) :passed)
                 (plusp (- (property-result-trials result) rejected)))
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
            (format nil "function spec ~A::~A is registered" (car entry) (cdr entry)))))))

(deftest project-properties-pass
  (dolist (name (project-properties))
    (multiple-value-bind (passed-p result) (property-passes-p name)
      (ok passed-p (failure-report name result)))))

(deftest project-function-specs-pass
  (dolist (name (project-function-specs))
    (multiple-value-bind (passed-p result) (function-spec-passes-p name)
      (ok passed-p (failure-report name result)))))
