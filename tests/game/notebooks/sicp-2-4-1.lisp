;;;; tests/game/notebooks/sicp-2-4-1.lisp --- Smoke test for SICP 2.4.1.

(defpackage #:recurya/tests/game/notebooks/sicp-2-4-1
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-2-4-1
                #:make-sicp-2-4-1-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-2-4-1)

(deftest sicp-2-4-1-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-2-4-1-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(defparameter *complex-prelude*
  "(define (square x) (* x x))
(define (sqrt-newton x)
  (define (good? g) (< (let ((d (- (square g) x))) (if (< d 0) (- 0 d) d)) 0.001))
  (define (improve g) (/ (+ g (/ x g)) 2))
  (define (iter g) (if (good? g) g (iter (improve g))))
  (iter 1.0))
(define (make-from-real-imag x y) (cons x y))
(define (real-part z) (car z))
(define (imag-part z) (cdr z))
(define (magnitude z) (sqrt-newton (+ (square (real-part z)) (square (imag-part z)))))
(define (add-complex z1 z2)
  (make-from-real-imag (+ (real-part z1) (real-part z2))
                       (+ (imag-part z1) (imag-part z2))))")

(deftest sicp-2-4-1-ex-magnitude-passes
  (testing "the ex-magnitude exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-2-4-1-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-magnitude cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       (format nil "~A~%(magnitude (make-from-real-imag 6.0 8.0))" *complex-prelude*))
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-2-4-1-ex-add-complex-passes
  (testing "the ex-add-complex exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-2-4-1-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-add-complex cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       (format nil "~A~%(real-part (add-complex (make-from-real-imag 1 2) (make-from-real-imag 3 4)))" *complex-prelude*))
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
