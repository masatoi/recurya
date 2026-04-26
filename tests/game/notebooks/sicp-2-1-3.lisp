;;;; tests/game/notebooks/sicp-2-1-3.lisp --- Smoke test for SICP 2.1.3.

(defpackage #:recurya/tests/game/notebooks/sicp-2-1-3
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-2-1-3
                #:make-sicp-2-1-3-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-2-1-3)

(deftest sicp-2-1-3-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-2-1-3-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(deftest sicp-2-1-3-ex-my-list-passes
  (testing "the ex-my-list exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-2-1-3-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-my-list cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (my-cons a b) (lambda (selector) (selector a b)))
(define (my-car p) (p (lambda (a b) a)))
(define (my-cdr p) (p (lambda (a b) b)))
(my-car (my-cdr (my-cons 1 (my-cons 2 (my-cons 3 nil)))))")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
