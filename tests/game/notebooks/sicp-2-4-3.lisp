;;;; tests/game/notebooks/sicp-2-4-3.lisp --- Smoke test for SICP 2.4.3.

(defpackage #:recurya/tests/game/notebooks/sicp-2-4-3
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-2-4-3
                #:make-sicp-2-4-3-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-2-4-3)

(deftest sicp-2-4-3-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-2-4-3-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(defparameter *dispatch-prelude*
  "(define (pair? x) (and (not (null? x)) (not (atom? x))))
(define (attach-tag tag x) (cons tag x))
(define (type-tag x) (car x))
(define (contents x) (cdr x))
(define (real-part-rect z) (car z))
(define (imag-part-rect z) (cdr z))
(define (magnitude-polar z) (car z))
(define (angle-polar z) (cdr z))
(define op-table
  (list
    (list (list 'real-part 'rectangular) real-part-rect)
    (list (list 'imag-part 'rectangular) imag-part-rect)
    (list (list 'magnitude 'polar) magnitude-polar)
    (list (list 'angle 'polar) angle-polar)))
(define (assoc-pair key alist)
  (cond ((null? alist) nil)
        ((equal? key (car (car alist))) (car alist))
        (t (assoc-pair key (cdr alist)))))
(define (get op type)
  (let ((entry (assoc-pair (list op type) op-table)))
    (if entry (car (cdr entry)) nil)))
(define (apply-generic op arg)
  (let ((proc (get op (type-tag arg))))
    (if proc (proc (contents arg)) 'no-method)))
(define (real-part z) (apply-generic 'real-part z))
(define (magnitude z) (apply-generic 'magnitude z))")

(deftest sicp-2-4-3-ex-data-directed-passes
  (testing "the ex-data-directed exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-2-4-3-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-data-directed cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       (format nil "~A~%(magnitude (attach-tag 'polar (cons 5 0.927)))" *dispatch-prelude*))
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-2-4-3-ex-dispatch-real-passes
  (testing "the ex-dispatch-real exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-2-4-3-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-dispatch-real cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       (format nil "~A~%(real-part (attach-tag 'rectangular (cons 7 24)))" *dispatch-prelude*))
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
