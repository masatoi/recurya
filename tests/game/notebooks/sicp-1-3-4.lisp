;;;; tests/game/notebooks/sicp-1-3-4.lisp --- Smoke test for SICP 1.3.4.

(defpackage #:recurya/tests/game/notebooks/sicp-1-3-4
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-1-3-4
                #:make-sicp-1-3-4-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-1-3-4)

(deftest sicp-1-3-4-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-1-3-4-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(deftest sicp-1-3-4-ex-compose-passes
  (testing "the ex-compose exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-1-3-4-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-compose cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (compose f g) (lambda (x) (f (g x))))
((compose (lambda (x) (* x x)) (lambda (x) (+ x 1))) 4)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-1-3-4-ex-double-passes
  (testing "the ex-double exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-1-3-4-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-double cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (double f) (lambda (x) (f (f x))))
((double (lambda (x) (+ x 1))) 5)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
