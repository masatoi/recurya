;;;; tests/game/notebooks/sicp-3-2-1.lisp --- Smoke and grading tests for SICP 3.2.1.

(defpackage #:recurya/tests/game/notebooks/sicp-3-2-1
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-3-2-1
                #:make-sicp-3-2-1-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-3-2-1)

(deftest sicp-3-2-1-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-3-2-1-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(defparameter *make-counter-prelude*
  "(define (make-counter) (lambda () 0))")

(deftest sicp-3-2-1-ex-trace-passes
  (testing "the ex-trace exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-3-2-1-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-trace cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       (format nil "~A~%(let ((cc (make-counter))) (list (cc) (cc) (cc)))"
                                               *make-counter-prelude*))
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
