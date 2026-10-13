;;;; cli/report.lisp --- Human-readable output of the recurya CLI.

(defpackage #:recurya/cli/report
  (:use #:cl)
  (:import-from #:recurya/cli/workspace
                #:cell-file-name)
  (:export #:format-run-result
           #:result-exit-code
           #:format-notebook-list
           #:format-status))

(in-package #:recurya/cli/report)

(defun jstring (value)
  (and (stringp value) value))

(defun result-exit-code (result)
  "0 when RESULT's status is \"pass\" or \"ok\", 1 otherwise."
  (if (member (gethash "status" result) '("pass" "ok") :test #'equal) 0 1))

(defun format-run-result (result width stream)
  "Write RESULT, a cell-run response, to STREAM: status line, one line per
test, print output, error (with the cell it came from), resources used, and
any solution files the run unlocked.  WIDTH numbers cells like file names."
  (let* ((status (gethash "status" result))
         (tests (coerce (gethash "tests" result) 'list))
         (failed (count-if-not (lambda (tr) (eq (gethash "passed" tr) t)) tests)))
    (cond
      ((string= status "pass")
       (format stream "PASS  all ~D test~:P passed~%" (length tests)))
      ((string= status "fail")
       (format stream "FAIL  ~D of ~D test~:P failed~%" failed (length tests)))
      ((string= status "ok")
       (format stream "OK    => ~A~%" (or (jstring (gethash "value" result)) "")))
      (t (format stream "ERROR~%")))
    (dolist (tr tests)
      (format stream "  ~:[✗~;✓~] ~A  expected ~A  got ~A~%"
              (eq (gethash "passed" tr) t)
              (gethash "input" tr)
              (gethash "expected" tr)
              (or (jstring (gethash "actual" tr))
                  (format nil "error: ~A" (or (jstring (gethash "error" tr)) "?")))))
    (let ((out (jstring (gethash "output" result))))
      (when (and out (plusp (length out)))
        (format stream "output:~%~A~&" out)))
    (let ((err (jstring (gethash "error" result)))
          (cell (gethash "error_cell_index" result)))
      (when err
        (if (integerp cell)
            (format stream "error (cell ~v,'0D): ~A~%" width cell err)
            (format stream "error: ~A~%" err))))
    (let ((m (gethash "metrics" result)))
      (when (hash-table-p m)
        (format stream "steps ~D · cons ~D · depth ~D~%"
                (gethash "steps" m) (gethash "cons" m) (gethash "depth" m))))
    (dolist (rev (coerce (gethash "revealed_solutions" result) 'list))
      (format stream "unlocked: ~A~%"
              (cell-file-name (gethash "index" rev) "code-solution" width)))))

(defun format-notebook-list (json stream)
  "One line per notebook of a GET /api/v1/notebooks response, plus paging."
  (dolist (item (coerce (gethash "items" json) 'list))
    (format stream "@~A/~A  ~A~%" (gethash "handle" item) (gethash "slug" item)
            (gethash "title" item)))
  (format stream "-- page ~D, ~D notebook~:P in total~%"
          (gethash "page" json) (gethash "total" json)))

(defun format-status (manifest modified-files stream)
  "One line per code cell of MANIFEST: file, passed or not, and whether the
file differs from what was last pulled (MODIFIED-FILES)."
  (format stream "@~A/~A  ~A~%" (gethash "handle" manifest) (gethash "slug" manifest)
          (gethash "title" manifest))
  (dolist (cell (coerce (gethash "cells" manifest) 'list))
    (let ((file (jstring (gethash "file" cell))))
      (when file
        (format stream "  ~A~30T~:[        ~;passed  ~]~:[~;modified~]~%"
                file
                (eq (gethash "passed" cell) t)
                (member file modified-files :test #'string=))))))
