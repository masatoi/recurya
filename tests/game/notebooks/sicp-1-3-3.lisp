;;;; tests/game/notebooks/sicp-1-3-3.lisp --- Smoke test for SICP 1.3.3.

(defpackage #:recurya/tests/game/notebooks/sicp-1-3-3
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-1-3-3
                #:make-sicp-1-3-3-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-1-3-3)

(deftest sicp-1-3-3-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-1-3-3-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(deftest sicp-1-3-3-ex-fp-sqrt-passes
  (testing "the ex-fp-sqrt exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-1-3-3-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-fp-sqrt cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (abs-val x) (if (< x 0) (- 0 x) x))
(define (close-enough? a b) (< (abs-val (- a b)) 0.0001))
(define (fixed-point f start)
  (define (try g) (let ((next (f g))) (if (close-enough? g next) next (try next))))
  (try start))
(define (my-sqrt-2)
  (fixed-point (lambda (x) (/ (+ x (/ 2 x)) 2)) 1.0))
(my-sqrt-2)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-1-3-3-ex-golden-ratio-passes
  (testing "the ex-golden-ratio exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-1-3-3-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-golden-ratio cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (abs-val x) (if (< x 0) (- 0 x) x))
(define (close-enough? a b) (< (abs-val (- a b)) 0.0001))
(define (fixed-point f start)
  (define (try g) (let ((next (f g))) (if (close-enough? g next) next (try next))))
  (try start))
(fixed-point (lambda (x) (+ 1 (/ 1 x))) 1.0)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
