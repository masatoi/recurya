;;;; tests/game/notebooks/sicp-1-1-2.lisp --- Smoke test for SICP 1.1.2.

(defpackage #:recurya/tests/game/notebooks/sicp-1-1-2
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-1-1-2
                #:make-sicp-1-1-2-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-1-1-2)

(deftest sicp-1-1-2-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-1-1-2-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(deftest sicp-1-1-2-circle-area-passes
  (testing "the ex-circle-area exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-1-1-2-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-circle-area cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define pi 3.14)
(define (circle-area r) (* pi r r))
(circle-area 10)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-1-1-2-sphere-volume-passes
  (testing "the ex-sphere-volume exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-1-1-2-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-sphere-volume cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define pi 3.14)
(define (cube x) (* x x x))
(* 4 (/ pi 3) (cube 2))")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
