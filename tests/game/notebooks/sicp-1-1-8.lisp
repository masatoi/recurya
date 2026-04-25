;;;; tests/game/notebooks/sicp-1-1-8.lisp --- Smoke test for SICP 1.1.8.

(defpackage #:recurya/tests/game/notebooks/sicp-1-1-8
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-1-1-8
                #:make-sicp-1-1-8-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-1-1-8)

(deftest sicp-1-1-8-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-1-1-8-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(deftest sicp-1-1-8-ex-internal-passes
  (testing "the ex-internal exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-1-1-8-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-internal cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (cube-root x)
  (define (square g) (* g g))
  (define (abs-val a) (if (< a 0) (- 0 a) a))
  (define (good-enough? guess)
    (< (abs-val (- (* guess (square guess)) x)) 0.001))
  (define (improve guess)
    (/ (+ (/ x (square guess)) (* 2 guess)) 3))
  (define (iter guess)
    (if (good-enough? guess) guess (iter (improve guess))))
  (iter 1.0))
(cube-root 8)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-1-1-8-ex-mystery-passes
  (testing "the ex-mystery exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-1-1-8-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-mystery cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (factorial n)
  (define (iter i acc)
    (if (> i n) acc (iter (+ i 1) (* acc i))))
  (iter 1 1))
(factorial 5)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
