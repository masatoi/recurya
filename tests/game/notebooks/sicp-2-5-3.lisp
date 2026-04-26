;;;; tests/game/notebooks/sicp-2-5-3.lisp --- Smoke test for SICP 2.5.3.

(defpackage #:recurya/tests/game/notebooks/sicp-2-5-3
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-2-5-3
                #:make-sicp-2-5-3-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-2-5-3)

(deftest sicp-2-5-3-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-2-5-3-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(defparameter *poly-prelude*
  "(define (pair? x) (and (not (null? x)) (not (atom? x))))
(define (attach-tag tag x) (cons tag x))
(define (type-tag x) (car x))
(define (contents x) (cdr x))
(define (make-poly variable term-list) (attach-tag 'poly (cons variable term-list)))
(define (variable p) (car p))
(define (term-list p) (cdr p))
(define (make-term order coef) (list order coef))
(define (order term) (car term))
(define (coef term) (car (cdr term)))
(define (the-empty-term-list) nil)
(define (empty-term-list? l) (null? l))
(define (first-term l) (car l))
(define (rest-terms l) (cdr l))
(define (adjoin-term term term-list)
  (if (= 0 (coef term)) term-list (cons term term-list)))
(define (add-terms l1 l2)
  (cond ((empty-term-list? l1) l2)
        ((empty-term-list? l2) l1)
        (t
         (let ((t1 (first-term l1)) (t2 (first-term l2)))
           (cond ((> (order t1) (order t2))
                  (adjoin-term t1 (add-terms (rest-terms l1) l2)))
                 ((< (order t1) (order t2))
                  (adjoin-term t2 (add-terms l1 (rest-terms l2))))
                 (t (adjoin-term (make-term (order t1) (+ (coef t1) (coef t2)))
                                 (add-terms (rest-terms l1) (rest-terms l2)))))))))
(define (add-poly p1 p2)
  (if (eq? (variable p1) (variable p2))
      (make-poly (variable p1) (add-terms (term-list p1) (term-list p2)))
      'different-variables))
(define op-table
  (list
    (list (list 'add 'poly 'poly) (lambda (p1 p2) (add-poly p1 p2)))))
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
(define (add x y) (apply-generic 'add x y))")

(deftest sicp-2-5-3-ex-poly-add-passes
  (testing "the ex-poly-add exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-2-5-3-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-poly-add cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       (format nil "~A~%(add (make-poly 'x (list (make-term 1 2) (make-term 0 3))) (make-poly 'x (list (make-term 1 4) (make-term 0 5))))" *poly-prelude*))
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-2-5-3-ex-poly-zero-passes
  (testing "the ex-poly-zero exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-2-5-3-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-poly-zero cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       (format nil "~A~%(add (make-poly 'x (list (make-term 2 3) (make-term 0 5))) (make-poly 'x (list (make-term 2 -3) (make-term 0 1))))" *poly-prelude*))
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
