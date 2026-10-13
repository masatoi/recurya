;;;; tests/cli/report.lisp --- CLI output formatting.

(defpackage #:recurya/tests/cli/report
  (:use #:cl #:rove)
  (:import-from #:recurya/cli/report
                #:format-run-result
                #:result-exit-code
                #:format-notebook-list))

(in-package #:recurya/tests/cli/report)

(defun jobj (&rest kv)
  (let ((h (make-hash-table :test 'equal)))
    (loop for (k v) on kv by #'cddr do (setf (gethash k h) v))
    h))

(defun result (status &key (tests #()) (error 'null) (error-cell 'null) (output "")
                           (value 'null) (revealed #()))
  (jobj "status" status "value" value "output" output "error" error
        "error_cell_index" error-cell "tests" tests
        "metrics" (jobj "steps" 12 "cons" 3 "depth" 4)
        "revealed_solutions" revealed))

(defun render (r) (with-output-to-string (s) (format-run-result r 2 s)))

(deftest pass-and-fail-summaries
  (let ((tests (vector (jobj "input" "(f 1)" "expected" "2" "actual" "2" "passed" t
                             "error" 'null "description" 'null)
                       (jobj "input" "(f 2)" "expected" "4" "actual" "3" "passed" nil
                             "error" 'null "description" 'null))))
    (let ((out (render (result "fail" :tests tests))))
      (ok (search "FAIL" out))
      (ok (search "1 of 2" out))
      (ok (search "(f 2)" out))
      (ok (search "expected 4" out))
      (ok (search "got 3" out))
      (ok (search "steps 12" out)))
    (ok (search "PASS" (render (result "pass" :tests (vector (aref tests 0))))))))

(deftest error-names-the-cell-and-ok-shows-value
  (let ((out (render (result "error" :error "Undefined variable: x" :error-cell 1))))
    (ok (search "ERROR" out))
    (ok (search "cell 01" out))
    (ok (search "Undefined variable: x" out)))
  (ok (search "=> 3" (render (result "ok" :value "3")))))

(deftest revealed-solutions-are-announced
  (ok (search "04-solution.wl"
              (render (result "pass" :revealed (vector (jobj "index" 4 "cell_id" "s" "body" "x")))))))

(deftest exit-codes
  (ok (= 0 (result-exit-code (result "pass"))))
  (ok (= 0 (result-exit-code (result "ok"))))
  (ok (= 1 (result-exit-code (result "fail"))))
  (ok (= 1 (result-exit-code (result "error")))))

(deftest notebook-list-lines
  (let ((out (with-output-to-string (s)
               (format-notebook-list
                (jobj "items" (vector (jobj "handle" "alice" "slug" "nb" "title" "T" "summary" 'null))
                      "page" 1 "per_page" 20 "total" 1)
                s))))
    (ok (search "@alice/nb" out))
    (ok (search "T" out))))
