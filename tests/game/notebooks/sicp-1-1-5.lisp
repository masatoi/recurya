;;;; tests/game/notebooks/sicp-1-1-5.lisp --- Smoke test for SICP 1.1.5.

(defpackage #:recurya/tests/game/notebooks/sicp-1-1-5
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-1-1-5
                #:make-sicp-1-1-5-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-1-1-5)

(deftest sicp-1-1-5-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-1-1-5-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(deftest sicp-1-1-5-ex-trace-passes
  (testing "the ex-trace exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-1-1-5-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-trace cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (a-plus-abs-b a b) ((if (> b 0) + -) a b))
(a-plus-abs-b 3 -5)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
