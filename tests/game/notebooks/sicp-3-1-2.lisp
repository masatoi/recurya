;;;; tests/game/notebooks/sicp-3-1-2.lisp --- Smoke and grading tests for SICP 3.1.2.

(defpackage #:recurya/tests/game/notebooks/sicp-3-1-2
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-3-1-2
                #:make-sicp-3-1-2-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-3-1-2)

(deftest sicp-3-1-2-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-3-1-2-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(defparameter *lcg-prelude*
  "(define (lcg seed) (mod (+ (* 1103515245 seed) 12345) 2147483648))")

(deftest sicp-3-1-2-ex-lcg-third-passes
  (testing "the ex-lcg-third exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-3-1-2-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-lcg-third cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       (format nil "~A~%(lcg (lcg (lcg 42)))"
                                               *lcg-prelude*))
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
