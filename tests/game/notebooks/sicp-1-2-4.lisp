;;;; tests/game/notebooks/sicp-1-2-4.lisp --- Smoke test for SICP 1.2.4.

(defpackage #:recurya/tests/game/notebooks/sicp-1-2-4
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-1-2-4
                #:make-sicp-1-2-4-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-1-2-4)

(deftest sicp-1-2-4-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-1-2-4-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(deftest sicp-1-2-4-ex-fast-expt-passes
  (testing "the ex-fast-expt exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-1-2-4-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-fast-expt cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (even? n) (= (mod n 2) 0))
(define (square x) (* x x))
(define (fast-expt b n)
  (cond ((= n 0) 1)
        ((even? n) (square (fast-expt b (/ n 2))))
        (t (* b (fast-expt b (- n 1))))))
(fast-expt 3 12)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-1-2-4-ex-expt-mul-passes
  (testing "the ex-expt-mul exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-1-2-4-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-expt-mul cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (my-mul-iter a b acc)
  (if (= b 0) acc (my-mul-iter a (- b 1) (+ acc a))))
(define (my-mul a b) (my-mul-iter a b 0))
(my-mul 7 9)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
