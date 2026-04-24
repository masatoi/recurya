;;;; tests/game/notebooks/sicp-1-1-1.lisp --- Smoke test for SICP 1.1.1.

(defpackage #:recurya/tests/game/notebooks/sicp-1-1-1
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-1-1-1
                #:make-sicp-1-1-1-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-1-1-1)

(deftest sicp-1-1-1-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-1-1-1-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(deftest sicp-1-1-1-exercise-passes
  (testing "the ex-sum3 exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-1-1-1-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-sum3 cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx) "(+ 137 349 22)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
