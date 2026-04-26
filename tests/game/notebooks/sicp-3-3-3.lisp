;;;; tests/game/notebooks/sicp-3-3-3.lisp --- Smoke and grading tests for SICP 3.3.3.

(defpackage #:recurya/tests/game/notebooks/sicp-3-3-3
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-3-3-3
                #:make-sicp-3-3-3-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-3-3-3)

(deftest sicp-3-3-3-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-3-3-3-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(defparameter *table-1d-solution*
  "(define (make-table) nil)
(define (lookup key table)
  (cond ((null? table) nil)
        ((equal? key (car (car table))) (cdr (car table)))
        (t (lookup key (cdr table)))))
(define (insert key value table)
  (cond ((null? table) (list (cons key value)))
        ((equal? key (car (car table)))
         (cons (cons key value) (cdr table)))
        (t (cons (car table) (insert key value (cdr table))))))
(lookup 'b (insert 'c 3 (insert 'b 2 (insert 'a 1 (make-table)))))")

(deftest sicp-3-3-3-ex-table-1d-passes
  (testing "the ex-table-1d exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-3-3-3-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-table-1d cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx) *table-1d-solution*)
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(defparameter *update-existing-solution*
  "(define (make-table) nil)
(define (lookup key table)
  (cond ((null? table) nil)
        ((equal? key (car (car table))) (cdr (car table)))
        (t (lookup key (cdr table)))))
(define (insert key value table)
  (cond ((null? table) (list (cons key value)))
        ((equal? key (car (car table)))
         (cons (cons key value) (cdr table)))
        (t (cons (car table) (insert key value (cdr table))))))
(lookup 'a (insert 'a 99 (insert 'a 1 (make-table))))")

(deftest sicp-3-3-3-ex-update-existing-passes
  (testing "the ex-update-existing exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-3-3-3-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-update-existing cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx) *update-existing-solution*)
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
