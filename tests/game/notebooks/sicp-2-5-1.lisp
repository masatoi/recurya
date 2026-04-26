;;;; tests/game/notebooks/sicp-2-5-1.lisp --- Smoke test for SICP 2.5.1.

(defpackage #:recurya/tests/game/notebooks/sicp-2-5-1
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-2-5-1
                #:make-sicp-2-5-1-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-2-5-1)

(deftest sicp-2-5-1-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-2-5-1-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(defparameter *generic-prelude*
  "(define (pair? x) (and (not (null? x)) (not (atom? x))))
(define (attach-tag tag x) (cons tag x))
(define (type-tag x) (car x))
(define (contents x) (cdr x))
(define (make-int n) (attach-tag 'int n))
(define (add-int a b) (make-int (+ a b)))
(define (mul-int a b) (make-int (* a b)))
(define (gcd a b) (if (= b 0) a (gcd b (mod a b))))
(define (make-rat n d) (let ((g (gcd n d))) (attach-tag 'rational (cons (quotient n g) (quotient d g)))))
(define (numer r) (car r))
(define (denom r) (cdr r))
(define (add-rat a b) (make-rat (+ (* (numer a) (denom b)) (* (numer b) (denom a))) (* (denom a) (denom b))))
(define (mul-rat a b) (make-rat (* (numer a) (numer b)) (* (denom a) (denom b))))
(define op-table
  (list
    (list (list 'add 'int 'int) (lambda (a b) (add-int a b)))
    (list (list 'mul 'int 'int) (lambda (a b) (mul-int a b)))
    (list (list 'add 'rational 'rational) (lambda (a b) (add-rat a b)))
    (list (list 'mul 'rational 'rational) (lambda (a b) (mul-rat a b)))))
(define (assoc-pair key alist)
  (cond ((null? alist) nil)
        ((equal? key (car (car alist))) (car alist))
        (t (assoc-pair key (cdr alist)))))
(define (get op types)
  (let ((entry (assoc-pair (cons op types) op-table)))
    (if entry (car (cdr entry)) nil)))
(define (apply-generic op a b)
  (let ((proc (get op (list (type-tag a) (type-tag b)))))
    (if proc (proc (contents a) (contents b)) 'no-method)))
(define (add x y) (apply-generic 'add x y))
(define (mul x y) (apply-generic 'mul x y))")

(deftest sicp-2-5-1-ex-int-add-passes
  (testing "the ex-int-add exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-2-5-1-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-int-add cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       (format nil "~A~%(add (make-int 5) (make-int 7))" *generic-prelude*))
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-2-5-1-ex-rat-mul-passes
  (testing "the ex-rat-mul exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-2-5-1-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-rat-mul cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       (format nil "~A~%(mul (make-rat 2 3) (make-rat 3 4))" *generic-prelude*))
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
