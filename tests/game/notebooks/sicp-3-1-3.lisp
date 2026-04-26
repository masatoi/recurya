;;;; tests/game/notebooks/sicp-3-1-3.lisp --- Smoke and grading tests for SICP 3.1.3.

(defpackage #:recurya/tests/game/notebooks/sicp-3-1-3
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-3-1-3
                #:make-sicp-3-1-3-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-3-1-3)

(deftest sicp-3-1-3-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-3-1-3-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(defparameter *pure-counter-prelude*
  "(define (make-counter) 0)
(define (tick c) (+ c 1))
(define (value c) c)")

(deftest sicp-3-1-3-ex-pure-counter-passes
  (testing "the ex-pure-counter exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-3-1-3-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-pure-counter cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       (format nil "~A~%(value (tick (tick (tick (make-counter)))))"
                                               *pure-counter-prelude*))
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
