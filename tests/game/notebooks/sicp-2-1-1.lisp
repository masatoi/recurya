;;;; tests/game/notebooks/sicp-2-1-1.lisp --- Smoke test for SICP 2.1.1.

(defpackage #:recurya/tests/game/notebooks/sicp-2-1-1
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-2-1-1
                #:make-sicp-2-1-1-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-2-1-1)

(deftest sicp-2-1-1-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-2-1-1-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(deftest sicp-2-1-1-ex-mul-rat-passes
  (testing "the ex-mul-rat exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-2-1-1-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-mul-rat cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (gcd a b) (if (= b 0) a (gcd b (mod a b))))
(define (make-rat n d) (let ((g (gcd n d))) (cons (quotient n g) (quotient d g))))
(define (numer x) (car x))
(define (denom x) (cdr x))
(define (mul-rat x y) (make-rat (* (numer x) (numer y)) (* (denom x) (denom y))))
(mul-rat (make-rat 2 3) (make-rat 3 4))")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-2-1-1-ex-equal-rat-passes
  (testing "the ex-equal-rat exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-2-1-1-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-equal-rat cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (gcd a b) (if (= b 0) a (gcd b (mod a b))))
(define (make-rat n d) (let ((g (gcd n d))) (cons (quotient n g) (quotient d g))))
(define (numer x) (car x))
(define (denom x) (cdr x))
(define (equal-rat? x y) (= (* (numer x) (denom y)) (* (numer y) (denom x))))
(equal-rat? (make-rat 2 4) (make-rat 1 2))")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
