;;;; tests/game/notebooks/sicp-1-1-6.lisp --- Smoke test for SICP 1.1.6.

(defpackage #:recurya/tests/game/notebooks/sicp-1-1-6
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-1-1-6
                #:make-sicp-1-1-6-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-1-1-6)

(deftest sicp-1-1-6-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-1-1-6-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(deftest sicp-1-1-6-ex-abs-passes
  (testing "the ex-abs exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-1-1-6-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-abs cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (abs-val x) (if (< x 0) (- 0 x) x))
(abs-val -7)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-1-1-6-ex-ge-passes
  (testing "the ex-ge exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-1-1-6-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-ge cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (my-ge? x y) (not (< x y)))
(my-ge? 5 5)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-1-1-6-ex-largest-two-passes
  (testing "the ex-largest-two exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-1-1-6-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-largest-two cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (sum-of-two-largest a b c)
  (cond ((and (<= a b) (<= a c)) (+ b c))
        ((and (<= b a) (<= b c)) (+ a c))
        (t                       (+ a b))))
(sum-of-two-largest 3 7 4)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
