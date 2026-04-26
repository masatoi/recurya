;;;; tests/game/notebooks/sicp-3-2-3.lisp --- Smoke and grading tests for SICP 3.2.3.

(defpackage #:recurya/tests/game/notebooks/sicp-3-2-3
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-3-2-3
                #:make-sicp-3-2-3-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-3-2-3)

(deftest sicp-3-2-3-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-3-2-3-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(defparameter *fresh-counter-solution*
  "(let* ((c1 (count-up 10))
       (c2 ((car (cdr c1))))
       (c3 ((car (cdr c2)))))
  (car c3))")

(deftest sicp-3-2-3-ex-fresh-counter-passes
  (testing "the ex-fresh-counter exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-3-2-3-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-fresh-counter cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx) *fresh-counter-solution*)
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
