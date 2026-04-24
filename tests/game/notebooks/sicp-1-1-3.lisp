;;;; tests/game/notebooks/sicp-1-1-3.lisp --- Smoke test for SICP 1.1.3.

(defpackage #:recurya/tests/game/notebooks/sicp-1-1-3
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-1-1-3
                #:make-sicp-1-1-3-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-1-1-3)

(deftest sicp-1-1-3-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-1-1-3-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 3))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(deftest sicp-1-1-3-fraction-passes
  (testing "the ex-fraction exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-1-1-3-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-fraction cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (f a b c d e) (/ (+ a (* b c)) (- d e)))
(f 2 3 4 10 5)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
