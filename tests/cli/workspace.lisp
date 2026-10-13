;;;; tests/cli/workspace.lisp --- CLI workspace layout, manifest and pull plan.

(defpackage #:recurya/tests/cli/workspace
  (:use #:cl #:rove)
  (:import-from #:recurya/cli/workspace
                #:index-width
                #:cell-file-name
                #:initial-code
                #:content-hash
                #:render-readme
                #:plan-pull
                #:manifest-cell
                #:collect-codes
                #:resolve-cell-arg
                #:manifest->json
                #:json->manifest
                #:workspace-error))

(in-package #:recurya/tests/cli/workspace)

(defun jobj (&rest kv)
  (let ((h (make-hash-table :test 'equal)))
    (loop for (k v) on kv by #'cddr do (setf (gethash k h) v))
    h))

(defun cell (index kind &key (body "") saved (unlocked t) (passed nil) (description "")
                         (tests #()))
  (jobj "index" index "cell_id" (format nil "c~D" index) "kind" kind
        "body" body "saved_code" (or saved 'null) "unlocked" unlocked
        "passed" passed "description" description "test_cases" tests "gated" nil))

(defun notebook (&rest cells)
  (jobj "handle" "alice" "slug" "nb" "title" "Title" "summary" "Sum"
        "cells" (coerce cells 'vector)))

(defparameter *nb*
  (notebook (cell 0 "prose" :body "Intro text")
            (cell 1 "code-eval" :body "(+ 1 2)")
            (cell 2 "code-exercise" :body "; fill" :saved "(saved)"
                  :description "Write it"
                  :tests (vector (jobj "input" "(f 1)" "expected" "2" "description" "")))
            (cell 3 "code-solution" :body 'null :unlocked nil)
            (cell 4 "scene" :body "(scene)")))

(deftest widths-and-file-names
  (ok (= 2 (index-width 5)))
  (ok (= 2 (index-width 100)))
  (ok (= 3 (index-width 101)))
  (ok (string= "03-exercise.wl" (cell-file-name 3 "code-exercise" 2)))
  (ok (string= "001-eval.wl" (cell-file-name 1 "code-eval" 3)))
  (ok (string= "04-solution.wl" (cell-file-name 4 "code-solution" 2)))
  (ng (cell-file-name 0 "prose" 2))
  (ng (cell-file-name 4 "scene" 2)))

(deftest initial-code-prefers-saved
  (ok (string= "(saved)" (initial-code (cell 2 "code-exercise" :body "; fill" :saved "(saved)"))))
  (ok (string= "; fill" (initial-code (cell 2 "code-exercise" :body "; fill"))))
  (ok (string= "" (initial-code (cell 3 "code-solution" :body 'null)))))

(deftest readme-mentions-every-cell
  (let ((md (render-readme *nb* 2)))
    (ok (search "# Title" md))
    (ok (search "Intro text" md))
    (ok (search "01-eval.wl" md))
    (ok (search "Write it" md))
    (ok (search "(f 1)" md))
    (ok (search "02-exercise.wl" md))
    (ok (search "locked" md) "locked solution is marked")
    (ok (search "not supported" md) "scene cell is marked")))

(deftest fresh-pull-writes-code-cells-only
  (multiple-value-bind (actions manifest) (plan-pull *nb* 2 nil '() nil)
    (ok (equal '((:write "01-eval.wl" "(+ 1 2)") (:write "02-exercise.wl" "(saved)"))
               actions))
    (ok (string= (content-hash "(saved)")
                 (gethash "hash" (manifest-cell manifest 2))))
    (ok (eq 'null (gethash "file" (manifest-cell manifest 3))) "locked solution has no file")))

(deftest repull-keeps-edited-files-unless-forced
  (let ((old (nth-value 1 (plan-pull *nb* 2 nil '() nil))))
    (let ((existing '(("01-eval.wl" . "(+ 1 2)") ("02-exercise.wl" . "(my edit)"))))
      (ok (equal '((:write "01-eval.wl" "(+ 1 2)") (:keep "02-exercise.wl"))
                 (plan-pull *nb* 2 old existing nil)))
      (ok (equal '((:write "01-eval.wl" "(+ 1 2)") (:write "02-exercise.wl" "(saved)"))
                 (plan-pull *nb* 2 old existing t))))
    (ok (equal '((:keep "01-eval.wl") (:keep "02-exercise.wl"))
               (plan-pull *nb* 2 nil '(("01-eval.wl" . "x") ("02-exercise.wl" . "y")) nil))
        "without a manifest, existing files are never overwritten")))

(deftest unlocked-solution-gets-a-file
  (let ((nb (notebook (cell 0 "code-exercise" :body "x")
                      (cell 1 "code-solution" :body "(answer)" :unlocked t))))
    (ok (equal '((:write "00-exercise.wl" "x") (:write "01-solution.wl" "(answer)"))
               (plan-pull nb 2 nil '() nil)))))

(deftest collect-codes-sends-files-for-code-cells
  (let ((manifest (nth-value 1 (plan-pull *nb* 2 nil '() nil))))
    (ok (equal '("" "(+ 1 2)" "(mine)")
               (collect-codes manifest 2
                              (lambda (f) (cdr (assoc f '(("01-eval.wl" . "(+ 1 2)")
                                                          ("02-exercise.wl" . "(mine)"))
                                                      :test #'string=))))))
    (ok (equal '("" "" "") (collect-codes manifest 2 (constantly nil)))
        "missing files are sent as empty code")))

(deftest resolve-cell-arg-forms
  (let ((manifest (nth-value 1 (plan-pull *nb* 2 nil '() nil))))
    (ok (= 2 (resolve-cell-arg "02" manifest)))
    (ok (= 2 (resolve-cell-arg "2" manifest)))
    (ok (= 2 (resolve-cell-arg "02-exercise.wl" manifest)))
    (ok (signals (resolve-cell-arg "0" manifest) 'workspace-error) "prose cannot run")
    (ok (signals (resolve-cell-arg "3" manifest) 'workspace-error) "solution cannot run")
    (ok (signals (resolve-cell-arg "99" manifest) 'workspace-error))
    (ok (signals (resolve-cell-arg "abc" manifest) 'workspace-error))))

(deftest manifest-json-roundtrip
  (let ((manifest (nth-value 1 (plan-pull *nb* 2 nil '() nil))))
    (let ((back (json->manifest (manifest->json manifest))))
      (ok (string= "alice" (gethash "handle" back)))
      (ok (string= "02-exercise.wl" (gethash "file" (manifest-cell back 2)))))))
