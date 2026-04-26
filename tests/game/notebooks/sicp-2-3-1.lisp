;;;; tests/game/notebooks/sicp-2-3-1.lisp --- Smoke test for SICP 2.3.1.

(defpackage #:recurya/tests/game/notebooks/sicp-2-3-1
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-2-3-1
                #:make-sicp-2-3-1-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-2-3-1)

(deftest sicp-2-3-1-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-2-3-1-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(deftest sicp-2-3-1-ex-equal-passes
  (testing "the ex-equal exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-2-3-1-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-equal cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (my-equal? a b)
  (cond ((and (atom? a) (atom? b)) (eq? a b))
        ((or (atom? a) (atom? b)) nil)
        (t (and (my-equal? (car a) (car b))
                (my-equal? (cdr a) (cdr b))))))
(my-equal? '(this is a list) '(this is a list))")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-2-3-1-ex-count-syms-passes
  (testing "the ex-count-syms exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-2-3-1-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-count-syms cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (count-occurrences sym xs)
  (cond ((null? xs) 0)
        ((eq? sym (car xs)) (+ 1 (count-occurrences sym (cdr xs))))
        (t (count-occurrences sym (cdr xs)))))
(count-occurrences 'a '(a b a c a d a))")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
