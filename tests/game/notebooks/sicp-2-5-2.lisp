;;;; tests/game/notebooks/sicp-2-5-2.lisp --- Smoke test for SICP 2.5.2.

(defpackage #:recurya/tests/game/notebooks/sicp-2-5-2
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-2-5-2
                #:make-sicp-2-5-2-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-2-5-2)

(deftest sicp-2-5-2-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-2-5-2-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(defparameter *coerce-prelude*
  "(define (pair? x) (and (not (null? x)) (not (atom? x))))
(define (attach-tag tag x) (cons tag x))
(define (type-tag x) (car x))
(define (contents x) (cdr x))
(define (make-int n) (attach-tag 'int n))
(define (gcd a b) (if (= b 0) a (gcd b (mod a b))))
(define (make-rat n d) (let ((g (gcd n d))) (attach-tag 'rational (cons (quotient n g) (quotient d g)))))
(define (numer r) (car r))
(define (denom r) (cdr r))
(define (add-int a b) (make-int (+ a b)))
(define (add-rat a b) (make-rat (+ (* (numer a) (denom b)) (* (numer b) (denom a))) (* (denom a) (denom b))))
(define (int->rational n) (make-rat n 1))
(define coercion-table
  (list
    (list (list 'int 'rational) int->rational)))
(define (assoc-pair key alist)
  (cond ((null? alist) nil)
        ((equal? key (car (car alist))) (car alist))
        (t (assoc-pair key (cdr alist)))))
(define (get-coercion from to)
  (let ((entry (assoc-pair (list from to) coercion-table)))
    (if entry (car (cdr entry)) nil)))
(define op-table
  (list
    (list (list 'add 'int 'int) (lambda (a b) (add-int a b)))
    (list (list 'add 'rational 'rational) (lambda (a b) (add-rat a b)))))
(define (get op types)
  (let ((entry (assoc-pair (cons op types) op-table)))
    (if entry (car (cdr entry)) nil)))
(define (apply-generic op a b)
  (let ((ta (type-tag a)) (tb (type-tag b)))
    (let ((proc (get op (list ta tb))))
      (if proc
          (proc (contents a) (contents b))
          (let ((a->b (get-coercion ta tb)))
            (if a->b
                (apply-generic op (a->b (contents a)) b)
                (let ((b->a (get-coercion tb ta)))
                  (if b->a (apply-generic op a (b->a (contents b))) 'no-method))))))))
(define (add x y) (apply-generic 'add x y))")

(defparameter *coerce-only-prelude*
  "(define (pair? x) (and (not (null? x)) (not (atom? x))))
(define (attach-tag tag x) (cons tag x))
(define (gcd a b) (if (= b 0) a (gcd b (mod a b))))
(define (make-rat n d) (let ((g (gcd n d))) (attach-tag 'rational (cons (quotient n g) (quotient d g)))))
(define (int->rational n) (make-rat n 1))")

(deftest sicp-2-5-2-ex-mixed-add-passes
  (testing "the ex-mixed-add exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-2-5-2-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-mixed-add cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       (format nil "~A~%(add (make-int 5) (make-rat 1 3))" *coerce-prelude*))
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-2-5-2-ex-coerce-passes
  (testing "the ex-coerce exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-2-5-2-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-coerce cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       (format nil "~A~%(int->rational 7)" *coerce-only-prelude*))
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
