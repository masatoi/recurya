;;;; tests/game/notebooks/sicp-2-1-4.lisp --- Smoke test for SICP 2.1.4.

(defpackage #:recurya/tests/game/notebooks/sicp-2-1-4
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-2-1-4
                #:make-sicp-2-1-4-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-2-1-4)

(deftest sicp-2-1-4-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-2-1-4-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(deftest sicp-2-1-4-ex-width-passes
  (testing "the ex-width exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-2-1-4-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-width cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (make-interval lo hi) (cons lo hi))
(define (lower-bound i) (car i))
(define (upper-bound i) (cdr i))
(define (width i) (/ (- (upper-bound i) (lower-bound i)) 2))
(width (make-interval 4 10))")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-2-1-4-ex-sub-interval-passes
  (testing "the ex-sub-interval exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-2-1-4-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-sub-interval cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (make-interval lo hi) (cons lo hi))
(define (lower-bound i) (car i))
(define (upper-bound i) (cdr i))
(define (sub-interval x y)
  (make-interval (- (lower-bound x) (upper-bound y))
                 (- (upper-bound x) (lower-bound y))))
(sub-interval (make-interval 5 10) (make-interval 1 3))")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
