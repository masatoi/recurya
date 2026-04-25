;;;; tests/game/notebooks/sicp-1-2-2.lisp --- Smoke test for SICP 1.2.2.

(defpackage #:recurya/tests/game/notebooks/sicp-1-2-2
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-1-2-2
                #:make-sicp-1-2-2-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-1-2-2)

(deftest sicp-1-2-2-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-1-2-2-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(deftest sicp-1-2-2-ex-fib-iter-passes
  (testing "the ex-fib-iter exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-1-2-2-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-fib-iter cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (fib-iter a b cnt)
  (if (= cnt 0)
      b
      (fib-iter (+ a b) a (- cnt 1))))
(define (fib-iter-call n) (fib-iter 1 0 n))
(fib-iter-call 15)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-1-2-2-ex-cc-2-passes
  (testing "the ex-cc-2 exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-1-2-2-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-cc-2 cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (cc-12 amount kinds)
  (cond ((= amount 0) 1)
        ((< amount 0) 0)
        ((= kinds 0) 0)
        (t (+ (cc-12 amount (- kinds 1))
              (cc-12 (- amount (if (= kinds 1) 1 5)) kinds)))))
(define (cc-12-amt n) (cc-12 n 2))
(cc-12-amt 7)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
