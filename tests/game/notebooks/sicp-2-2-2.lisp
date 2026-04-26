;;;; tests/game/notebooks/sicp-2-2-2.lisp --- Smoke test for SICP 2.2.2.

(defpackage #:recurya/tests/game/notebooks/sicp-2-2-2
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-2-2-2
                #:make-sicp-2-2-2-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-2-2-2)

(deftest sicp-2-2-2-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-2-2-2-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(deftest sicp-2-2-2-ex-count-leaves-passes
  (testing "the ex-count-leaves exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-2-2-2-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-count-leaves cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (pair? x) (and (not (null? x)) (not (atom? x))))
(define (count-leaves tr)
  (cond ((null? tr) 0)
        ((not (pair? tr)) 1)
        (t (+ (count-leaves (car tr)) (count-leaves (cdr tr))))))
(count-leaves (list 1 (list 2 3) (list 4 (list 5 6))))")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-2-2-2-ex-tree-map-passes
  (testing "the ex-tree-map exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-2-2-2-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-tree-map cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (pair? x) (and (not (null? x)) (not (atom? x))))
(define (tree-map f tree)
  (cond ((null? tree) nil)
        ((not (pair? tree)) (f tree))
        (t (cons (tree-map f (car tree)) (tree-map f (cdr tree))))))
(tree-map (lambda (x) (* x x)) (list 1 (list 2 3) 4))")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
