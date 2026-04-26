;;;; tests/game/notebooks/sicp-2-1-2.lisp --- Smoke test for SICP 2.1.2.

(defpackage #:recurya/tests/game/notebooks/sicp-2-1-2
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-2-1-2
                #:make-sicp-2-1-2-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-2-1-2)

(deftest sicp-2-1-2-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-2-1-2-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(deftest sicp-2-1-2-ex-line-passes
  (testing "the ex-line exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-2-1-2-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-line cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (make-point x y) (cons x y))
(define (x-point p) (car p))
(define (y-point p) (cdr p))
(define (make-segment p1 p2) (cons p1 p2))
(define (start-segment s) (car s))
(define (end-segment s) (cdr s))
(define (midpoint-segment s)
  (make-point (/ (+ (x-point (start-segment s)) (x-point (end-segment s))) 2)
              (/ (+ (y-point (start-segment s)) (y-point (end-segment s))) 2)))
(midpoint-segment (make-segment (make-point 0 0) (make-point 4 6)))")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
