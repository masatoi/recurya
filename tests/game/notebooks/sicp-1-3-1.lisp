;;;; tests/game/notebooks/sicp-1-3-1.lisp --- Smoke test for SICP 1.3.1.

(defpackage #:recurya/tests/game/notebooks/sicp-1-3-1
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-1-3-1
                #:make-sicp-1-3-1-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-1-3-1)

(deftest sicp-1-3-1-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-1-3-1-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(deftest sicp-1-3-1-ex-product-passes
  (testing "the ex-product exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-1-3-1-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-product cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (inc x) (+ x 1))
(define (product f a next b)
  (if (> a b) 1 (* (f a) (product f (next a) next b))))
(product (lambda (i) i) 1 inc 5)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-1-3-1-ex-sum-cubes-passes
  (testing "the ex-sum-cubes exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-1-3-1-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-sum-cubes cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (sum f a next b)
  (if (> a b) 0 (+ (f a) (sum f (next a) next b))))
(define (cube x) (* x x x))
(define (inc x) (+ x 1))
(sum cube 1 inc 4)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-1-3-1-ex-pi-eighth-passes
  (testing "the ex-pi-eighth exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-1-3-1-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-pi-eighth cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (sum f a next b)
  (if (> a b) 0 (+ (f a) (sum f (next a) next b))))
(define (inc x) (+ x 1))
(define (pi-term i) (/ 1 (* (- (* 4 i) 3) (- (* 4 i) 1))))
(define (pi-eighth-approx n) (sum pi-term 1 inc n))
(pi-eighth-approx 100)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
