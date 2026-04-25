;;;; tests/game/notebooks/sicp-1-1-7.lisp --- Smoke test for SICP 1.1.7.

(defpackage #:recurya/tests/game/notebooks/sicp-1-1-7
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-1-1-7
                #:make-sicp-1-1-7-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-1-1-7)

(deftest sicp-1-1-7-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-1-1-7-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(deftest sicp-1-1-7-ex-sqrt2-passes
  (testing "the ex-sqrt2 exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-1-1-7-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-sqrt2 cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(sqrt-y 2)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-1-1-7-ex-cube-root-passes
  (testing "the ex-cube-root exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-1-1-7-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-cube-root cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (abs-val x) (if (< x 0) (- 0 x) x))
(define (square x) (* x x))
(define (cube x) (* x x x))
(define (good-enough? guess x)
  (< (abs-val (- (cube guess) x)) 0.001))
(define (improve guess x)
  (/ (+ (/ x (square guess)) (* 2 guess)) 3))
(define (cbrt-iter guess x)
  (if (good-enough? guess x)
      guess
      (cbrt-iter (improve guess x) x)))
(define (cbrt x) (cbrt-iter 1.0 x))
(cbrt 27)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
