;;;; tests/game/notebooks/sicp-3-2-2.lisp --- Smoke and grading tests for SICP 3.2.2.

(defpackage #:recurya/tests/game/notebooks/sicp-3-2-2
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-3-2-2
                #:make-sicp-3-2-2-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-3-2-2)

(deftest sicp-3-2-2-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-3-2-2-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(defparameter *shadow-solution*
  "(define x 100)
(define (f y) (+ x y))
(define x 1)
(f 5)")

(deftest sicp-3-2-2-ex-shadow-passes
  (testing "the ex-shadow exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-3-2-2-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-shadow cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx) *shadow-solution*)
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
