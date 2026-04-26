;;;; tests/game/notebooks/sicp-2-2-1.lisp --- Smoke test for SICP 2.2.1.

(defpackage #:recurya/tests/game/notebooks/sicp-2-2-1
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-2-2-1
                #:make-sicp-2-2-1-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-2-2-1)

(deftest sicp-2-2-1-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-2-2-1-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(deftest sicp-2-2-1-ex-last-pair-passes
  (testing "the ex-last-pair exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-2-2-1-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-last-pair cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (last-pair items)
  (if (null? (cdr items)) items (last-pair (cdr items))))
(last-pair (list 1 2 3))")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-2-2-1-ex-deep-reverse-flat-passes
  (testing "the ex-deep-reverse-flat exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-2-2-1-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-deep-reverse-flat cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (reverse-iter items)
  (define (iter xs acc)
    (if (null? xs) acc (iter (cdr xs) (cons (car xs) acc))))
  (iter items nil))
(reverse-iter (list 1 2 3 4 5))")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
