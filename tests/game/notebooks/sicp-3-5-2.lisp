;;;; tests/game/notebooks/sicp-3-5-2.lisp --- Smoke tests for SICP 3.5.2.

(defpackage #:recurya/tests/game/notebooks/sicp-3-5-2
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-3-5-2
                #:make-sicp-3-5-2-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-3-5-2)

(deftest sicp-3-5-2-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-3-5-2-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 5))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(deftest sicp-3-5-2-fibs-take-passes
  (testing "the ex-fibs-take exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-3-5-2-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-fibs-take cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-take s n)
  (if (= n 0) nil (cons (stream-car s) (stream-take (stream-cdr s) (- n 1)))))
(define (fibs-from a b)
  (stream-cons a (lambda () (fibs-from b (+ a b)))))
(stream-take (fibs-from 0 1) 7)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-3-5-2-primes-take-passes
  (testing "the ex-primes-take exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-3-5-2-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-primes-take cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-take s n)
  (if (= n 0) nil (cons (stream-car s) (stream-take (stream-cdr s) (- n 1)))))
(define (integers-from n) (stream-cons n (lambda () (integers-from (+ n 1)))))
(define (stream-filter p s)
  (cond ((null? s) nil)
        ((p (stream-car s)) (stream-cons (stream-car s) (lambda () (stream-filter p (stream-cdr s)))))
        (t (stream-filter p (stream-cdr s)))))
(define (sieve s)
  (stream-cons (stream-car s)
    (lambda ()
      (sieve (stream-filter
               (lambda (x) (not (= 0 (mod x (stream-car s)))))
               (stream-cdr s))))))
(stream-take (sieve (integers-from 2)) 5)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
