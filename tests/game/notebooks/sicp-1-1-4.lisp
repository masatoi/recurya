;;;; tests/game/notebooks/sicp-1-1-4.lisp --- Smoke test for SICP 1.1.4.

(defpackage #:recurya/tests/game/notebooks/sicp-1-1-4
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-1-1-4
                #:make-sicp-1-1-4-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-1-1-4)

(deftest sicp-1-1-4-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-1-1-4-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(deftest sicp-1-1-4-ex-f-passes
  (testing "the ex-f exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-1-1-4-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-f cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (f a) (+ (* a (+ 1 a)) (- 1 a)))
(f 3)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-1-1-4-ex-power-passes
  (testing "the ex-power exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-1-1-4-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-power cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (square x) (* x x))
(define (power-fourth x) (square (square x)))
(power-fourth 3)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
