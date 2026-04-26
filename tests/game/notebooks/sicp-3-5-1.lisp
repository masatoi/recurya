;;;; tests/game/notebooks/sicp-3-5-1.lisp --- Smoke tests for SICP 3.5.1.

(defpackage #:recurya/tests/game/notebooks/sicp-3-5-1
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-3-5-1
                #:make-sicp-3-5-1-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-3-5-1)

(deftest sicp-3-5-1-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-3-5-1-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 5))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(deftest sicp-3-5-1-stream-sum-passes
  (testing "the ex-stream-sum exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-3-5-1-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-stream-sum cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-null? s) (null? s))
(define the-empty-stream nil)
(define (list->stream xs)
  (if (null? xs)
      the-empty-stream
      (stream-cons (car xs) (lambda () (list->stream (cdr xs))))))
(define (stream-sum-take s n)
  (if (or (= n 0) (stream-null? s))
      0
      (+ (stream-car s) (stream-sum-take (stream-cdr s) (- n 1)))))
(stream-sum-take (list->stream (list 1 2 3 4 5)) 4)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-3-5-1-stream-third-passes
  (testing "the ex-stream-third exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-3-5-1-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-stream-third cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-null? s) (null? s))
(define the-empty-stream nil)
(define (list->stream xs)
  (if (null? xs)
      the-empty-stream
      (stream-cons (car xs) (lambda () (list->stream (cdr xs))))))
(define (stream-ref s n)
  (if (= n 0) (stream-car s) (stream-ref (stream-cdr s) (- n 1))))
(stream-ref (list->stream (list 'a 'b 'c 'd 'e)) 2)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
