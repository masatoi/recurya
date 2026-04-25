;;;; tests/game/notebooks/sicp-1-2-6.lisp --- Smoke test for SICP 1.2.6.

(defpackage #:recurya/tests/game/notebooks/sicp-1-2-6
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-1-2-6
                #:make-sicp-1-2-6-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-1-2-6)

(deftest sicp-1-2-6-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-1-2-6-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(deftest sicp-1-2-6-ex-prime-1009-passes
  (testing "the ex-prime-1009 exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-1-2-6-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-prime-1009 cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (square x) (* x x))
(define (divides? a b) (= (mod b a) 0))
(define (find-divisor n test)
  (cond ((> (square test) n) n)
        ((divides? test n) test)
        (t (find-divisor n (+ test 1)))))
(define (smallest-divisor n) (find-divisor n 2))
(define (prime? n) (= (smallest-divisor n) n))
(prime? 1009)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-1-2-6-ex-next-prime-passes
  (testing "the ex-next-prime exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-1-2-6-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-next-prime cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (square x) (* x x))
(define (divides? a b) (= (mod b a) 0))
(define (find-divisor n test)
  (cond ((> (square test) n) n)
        ((divides? test n) test)
        (t (find-divisor n (+ test 1)))))
(define (smallest-divisor n) (find-divisor n 2))
(define (prime? n) (= (smallest-divisor n) n))
(define (next-prime n)
  (if (prime? n) n (next-prime (+ n 1))))
(next-prime 100)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
