;;;; tests/game/notebooks/sicp-1-2-3.lisp --- Smoke test for SICP 1.2.3.

(defpackage #:recurya/tests/game/notebooks/sicp-1-2-3
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-1-2-3
                #:make-sicp-1-2-3-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-1-2-3)

(deftest sicp-1-2-3-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-1-2-3-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(deftest sicp-1-2-3-ex-classify-passes
  (testing "the ex-classify exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-1-2-3-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-classify cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (count-down n)
  (if (= n 0)
      0
      (count-down (- n 1))))
(count-down 100)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-1-2-3-ex-double-passes
  (testing "the ex-double exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-1-2-3-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-double cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (power b e)
  (if (= e 0) 1 (* b (power b (- e 1)))))
(define (power-of-2-sum n)
  (define (iter k total)
    (if (> k n) total (iter (+ k 1) (+ total (power 2 k)))))
  (iter 0 0))
(power-of-2-sum 5)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
