;;;; tests/game/notebooks/sicp-3-5-4.lisp --- Smoke tests for SICP 3.5.4.

(defpackage #:recurya/tests/game/notebooks/sicp-3-5-4
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-3-5-4
                #:make-sicp-3-5-4-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-3-5-4)

(deftest sicp-3-5-4-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-3-5-4-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 5))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(deftest sicp-3-5-4-triangular-passes
  (testing "the ex-triangular exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-3-5-4-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-triangular cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-take s n)
  (if (= n 0) nil (cons (stream-car s) (stream-take (stream-cdr s) (- n 1)))))
(define (integers-from n) (stream-cons n (lambda () (integers-from (+ n 1)))))
(define (partial-sums-helper s acc)
  (let ((next-acc (+ acc (stream-car s))))
    (stream-cons next-acc (lambda () (partial-sums-helper (stream-cdr s) next-acc)))))
(define (partial-sums s) (partial-sums-helper s 0))
(stream-take (partial-sums (integers-from 1)) 6)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-3-5-4-square-sums-passes
  (testing "the ex-square-sums exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-3-5-4-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-square-sums cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-take s n)
  (if (= n 0) nil (cons (stream-car s) (stream-take (stream-cdr s) (- n 1)))))
(define (integers-from n) (stream-cons n (lambda () (integers-from (+ n 1)))))
(define (stream-map f s)
  (if (null? s) nil (stream-cons (f (stream-car s)) (lambda () (stream-map f (stream-cdr s))))))
(define (partial-sums-helper s acc)
  (let ((next-acc (+ acc (stream-car s))))
    (stream-cons next-acc (lambda () (partial-sums-helper (stream-cdr s) next-acc)))))
(define (partial-sums s) (partial-sums-helper s 0))
(stream-take (partial-sums (stream-map (lambda (x) (* x x)) (integers-from 1))) 5)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
