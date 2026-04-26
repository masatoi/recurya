;;;; tests/game/notebooks/sicp-2-2-3.lisp --- Smoke test for SICP 2.2.3.

(defpackage #:recurya/tests/game/notebooks/sicp-2-2-3
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-2-2-3
                #:make-sicp-2-2-3-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-2-2-3)

(deftest sicp-2-2-3-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-2-2-3-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(deftest sicp-2-2-3-ex-product-list-passes
  (testing "the ex-product-list exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-2-2-3-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-product-list cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (accumulate op init xs)
  (if (null? xs) init (op (car xs) (accumulate op init (cdr xs)))))
(define (product-list xs) (accumulate * 1 xs))
(product-list (list 1 2 3 4 5))")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-2-2-3-ex-flatmap-passes
  (testing "the ex-flatmap exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-2-2-3-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-flatmap cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (my-map f xs)
  (if (null? xs) nil (cons (f (car xs)) (my-map f (cdr xs)))))
(define (accumulate op init xs)
  (if (null? xs) init (op (car xs) (accumulate op init (cdr xs)))))
(define (flatmap f xs) (accumulate append nil (my-map f xs)))
(flatmap (lambda (x) (list x (* x x))) (list 1 2 3))")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-2-2-3-ex-list-length-passes
  (testing "the ex-list-length exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-2-2-3-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-list-length cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (accumulate op init xs)
  (if (null? xs) init (op (car xs) (accumulate op init (cdr xs)))))
(define (my-length xs) (accumulate (lambda (_ count) (+ count 1)) 0 xs))
(my-length (list 'a 'b 'c 'd 'e))")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
