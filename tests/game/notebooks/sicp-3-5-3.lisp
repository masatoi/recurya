;;;; tests/game/notebooks/sicp-3-5-3.lisp --- Smoke tests for SICP 3.5.3.

(defpackage #:recurya/tests/game/notebooks/sicp-3-5-3
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-3-5-3
                #:make-sicp-3-5-3-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-3-5-3)

(deftest sicp-3-5-3-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-3-5-3-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 5))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(deftest sicp-3-5-3-cubes-take-passes
  (testing "the ex-cubes-take exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-3-5-3-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-cubes-take cells :key #'cell-id))
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
(define cube-stream (stream-map (lambda (x) (* x x x)) (integers-from 1)))
(stream-take cube-stream 4)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-3-5-3-odd-squares-take-passes
  (testing "the ex-odd-squares-take exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-3-5-3-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-odd-squares-take cells :key #'cell-id))
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
(define (stream-filter p s)
  (cond ((null? s) nil)
        ((p (stream-car s)) (stream-cons (stream-car s) (lambda () (stream-filter p (stream-cdr s)))))
        (t (stream-filter p (stream-cdr s)))))
(stream-take (stream-map (lambda (x) (* x x)) (stream-filter (lambda (x) (= 1 (mod x 2))) (integers-from 1))) 5)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
