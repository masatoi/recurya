;;;; tests/game/notebooks/sicp-1-2-5.lisp --- Smoke test for SICP 1.2.5.

(defpackage #:recurya/tests/game/notebooks/sicp-1-2-5
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-1-2-5
                #:make-sicp-1-2-5-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-1-2-5)

(deftest sicp-1-2-5-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-1-2-5-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(deftest sicp-1-2-5-ex-gcd-large-passes
  (testing "the ex-gcd-large exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-1-2-5-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-gcd-large cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (gcd a b)
  (if (= b 0) a (gcd b (mod a b))))
(gcd 1071 462)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-1-2-5-ex-lcm-passes
  (testing "the ex-lcm exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-1-2-5-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-lcm cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (gcd a b)
  (if (= b 0) a (gcd b (mod a b))))
(define (lcm a b) (/ (* a b) (gcd a b)))
(lcm 12 18)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
