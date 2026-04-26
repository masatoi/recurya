;;;; tests/game/notebooks/sicp-2-3-2.lisp --- Smoke test for SICP 2.3.2.

(defpackage #:recurya/tests/game/notebooks/sicp-2-3-2
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-2-3-2
                #:make-sicp-2-3-2-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-2-3-2)

(deftest sicp-2-3-2-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-2-3-2-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(defparameter *deriv-prelude*
  "(define (pair? x) (and (not (null? x)) (not (atom? x))))
(define (variable? x) (atom? x))
(define (same-variable? v1 v2) (and (variable? v1) (variable? v2) (eq? v1 v2)))
(define (sum? e) (and (pair? e) (eq? (car e) '+)))
(define (addend e) (car (cdr e)))
(define (augend e) (car (cdr (cdr e))))
(define (product? e) (and (pair? e) (eq? (car e) '*)))
(define (multiplier e) (car (cdr e)))
(define (multiplicand e) (car (cdr (cdr e))))
(define (number-equal? n v) (and (number? n) (= n v)))
(define (make-sum a b)
  (cond ((number-equal? a 0) b)
        ((number-equal? b 0) a)
        ((and (number? a) (number? b)) (+ a b))
        (t (list '+ a b))))
(define (make-product a b)
  (cond ((or (number-equal? a 0) (number-equal? b 0)) 0)
        ((number-equal? a 1) b)
        ((number-equal? b 1) a)
        ((and (number? a) (number? b)) (* a b))
        (t (list '* a b))))
(define (deriv expr var)
  (cond ((variable? expr) (if (same-variable? expr var) 1 0))
        ((sum? expr) (make-sum (deriv (addend expr) var) (deriv (augend expr) var)))
        ((product? expr) (make-sum (make-product (multiplier expr) (deriv (multiplicand expr) var))
                                    (make-product (deriv (multiplier expr) var) (multiplicand expr))))
        (t 0)))")

(deftest sicp-2-3-2-ex-deriv-x-passes
  (testing "the ex-deriv-x exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-2-3-2-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-deriv-x cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       (format nil "~A~%(deriv '(* x x) 'x)" *deriv-prelude*))
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-2-3-2-ex-deriv-poly-passes
  (testing "the ex-deriv-poly exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-2-3-2-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-deriv-poly cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       (format nil "~A~%(deriv '(+ (* 3 (* x x)) (* 2 x)) 'x)" *deriv-prelude*))
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
