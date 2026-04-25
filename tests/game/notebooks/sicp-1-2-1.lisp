;;;; tests/game/notebooks/sicp-1-2-1.lisp --- Smoke test for SICP 1.2.1.

(defpackage #:recurya/tests/game/notebooks/sicp-1-2-1
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-1-2-1
                #:make-sicp-1-2-1-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-1-2-1)

(deftest sicp-1-2-1-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-1-2-1-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(deftest sicp-1-2-1-ex-sum-passes
  (testing "the ex-sum exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-1-2-1-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-sum cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (sum-iter total cur max)
  (if (> cur max)
      total
      (sum-iter (+ total cur) (+ cur 1) max)))
(define (sum-up-to n) (sum-iter 0 1 n))
(sum-up-to 10)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-1-2-1-ex-pow-passes
  (testing "the ex-pow exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-1-2-1-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-pow cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (power b n)
  (if (= n 0)
      1
      (* b (power b (- n 1)))))
(power 2 10)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
