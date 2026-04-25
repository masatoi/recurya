;;;; tests/game/notebooks/sicp-1-3-2.lisp --- Smoke test for SICP 1.3.2.

(defpackage #:recurya/tests/game/notebooks/sicp-1-3-2
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-1-3-2
                #:make-sicp-1-3-2-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-1-3-2)

(deftest sicp-1-3-2-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-1-3-2-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(deftest sicp-1-3-2-ex-lambda-call-passes
  (testing "the ex-lambda-call exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-1-3-2-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-lambda-call cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "((lambda (a b c) (+ (* a a) (* b b) (* c c))) 1 2 3)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-1-3-2-ex-let-quad-passes
  (testing "the ex-let-quad exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-1-3-2-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-let-quad cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (quadratic x y)
  (let* ((sq-x (* x x))
         (sq-y (* y y))
         (cross (* 2 x y))
         (sum-xy (+ x y)))
    (+ sq-x cross sq-y sum-xy)))
(quadratic 3 4)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
