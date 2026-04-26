;;;; tests/game/notebooks/sicp-3-2-4.lisp --- Smoke and grading tests for SICP 3.2.4.

(defpackage #:recurya/tests/game/notebooks/sicp-3-2-4
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-3-2-4
                #:make-sicp-3-2-4-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-3-2-4)

(deftest sicp-3-2-4-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-3-2-4-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(defparameter *internal-fact-solution*
  "(define (factorial-y n)
  (define (iter k acc)
    (if (> k n) acc (iter (+ k 1) (* acc k))))
  (iter 1 1))
(factorial-y 6)")

(deftest sicp-3-2-4-ex-internal-fact-passes
  (testing "the ex-internal-fact exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-3-2-4-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-internal-fact cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx) *internal-fact-solution*)
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
