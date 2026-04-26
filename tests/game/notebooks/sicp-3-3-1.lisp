;;;; tests/game/notebooks/sicp-3-3-1.lisp --- Smoke and grading tests for SICP 3.3.1.

(defpackage #:recurya/tests/game/notebooks/sicp-3-3-1
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-3-3-1
                #:make-sicp-3-3-1-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-3-3-1)

(deftest sicp-3-3-1-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-3-3-1-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(defparameter *shared-detect-solution*
  "(define (cdr-eq? a b) (eq? (cdr a) (cdr b)))
(let* ((c (list 1 2 3)) (a (cons 'x c)) (b (cons 'y c))) (cdr-eq? a b))")

(deftest sicp-3-3-1-ex-shared-detect-passes
  (testing "the ex-shared-detect exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-3-3-1-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-shared-detect cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx) *shared-detect-solution*)
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(defparameter *cons-twice-solution*
  "(let* ((x (list 1 2)) (z (cons x x))) (eq? (car z) (cdr z)))")

(deftest sicp-3-3-1-ex-cons-twice-passes
  (testing "the ex-cons-twice exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-3-3-1-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-cons-twice cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx) *cons-twice-solution*)
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
