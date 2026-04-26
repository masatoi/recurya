;;;; tests/game/notebooks/sicp-3-3-4.lisp --- Smoke and grading tests for SICP 3.3.4.

(defpackage #:recurya/tests/game/notebooks/sicp-3-3-4
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-3-3-4
                #:make-sicp-3-3-4-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-3-3-4)

(deftest sicp-3-3-4-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-3-3-4-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 5))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(defparameter *and-gate-solution*
  "(define (lookup key alist)
  (cond ((null? alist) nil)
        ((eq? key (car (car alist))) (cdr (car alist)))
        (t (lookup key (cdr alist)))))
(define (insert key value alist)
  (cond ((null? alist) (list (cons key value)))
        ((eq? key (car (car alist))) (cons (cons key value) (cdr alist)))
        (t (cons (car alist) (insert key value (cdr alist))))))
(define (logical-and x y) (if (and (= x 1) (= y 1)) 1 0))
(define (and-gate a b out)
  (lambda (s) (insert out (logical-and (lookup a s) (lookup b s)) s)))
(define (apply-gates gates state)
  (if (null? gates) state (apply-gates (cdr gates) ((car gates) state))))
(lookup 'out (apply-gates (list (and-gate 'a 'b 'out))
                          (list (cons 'a 1) (cons 'b 0) (cons 'out 0))))")

(deftest sicp-3-3-4-ex-and-gate-passes
  (testing "the ex-and-gate exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-3-3-4-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-and-gate cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx) *and-gate-solution*)
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(defparameter *nand-solution*
  "(define (lookup key alist)
  (cond ((null? alist) nil)
        ((eq? key (car (car alist))) (cdr (car alist)))
        (t (lookup key (cdr alist)))))
(define (insert key value alist)
  (cond ((null? alist) (list (cons key value)))
        ((eq? key (car (car alist))) (cons (cons key value) (cdr alist)))
        (t (cons (car alist) (insert key value (cdr alist))))))
(define (logical-not x) (if (= x 0) 1 0))
(define (logical-and x y) (if (and (= x 1) (= y 1)) 1 0))
(define (inverter in out)
  (lambda (state) (insert out (logical-not (lookup in state)) state)))
(define (and-gate a b out)
  (lambda (state) (insert out (logical-and (lookup a state) (lookup b state)) state)))
(define (apply-gates gates state)
  (if (null? gates) state (apply-gates (cdr gates) ((car gates) state))))
(lookup 'out (apply-gates (list (and-gate 'a 'b 'temp) (inverter 'temp 'out))
                          (list (cons 'a 1) (cons 'b 1) (cons 'temp 0) (cons 'out 0))))")

(deftest sicp-3-3-4-ex-nand-passes
  (testing "the ex-nand exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-3-3-4-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-nand cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx) *nand-solution*)
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
