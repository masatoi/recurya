;;;; tests/game/notebooks/sicp-2-3-3.lisp --- Smoke test for SICP 2.3.3.

(defpackage #:recurya/tests/game/notebooks/sicp-2-3-3
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-2-3-3
                #:make-sicp-2-3-3-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-2-3-3)

(deftest sicp-2-3-3-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-2-3-3-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(deftest sicp-2-3-3-ex-intersection-passes
  (testing "the ex-intersection exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-2-3-3-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-intersection cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (element-of-set? x s)
  (cond ((null? s) nil)
        ((equal? x (car s)) t)
        (t (element-of-set? x (cdr s)))))
(define (intersection-set s1 s2)
  (cond ((null? s1) nil)
        ((element-of-set? (car s1) s2)
         (cons (car s1) (intersection-set (cdr s1) s2)))
        (t (intersection-set (cdr s1) s2))))
(intersection-set '(a b c d) '(b d e f))")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-2-3-3-ex-union-ordered-passes
  (testing "the ex-union-ordered exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-2-3-3-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-union-ordered cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (union-set-ordered s1 s2)
  (cond ((null? s1) s2)
        ((null? s2) s1)
        ((= (car s1) (car s2))
         (cons (car s1) (union-set-ordered (cdr s1) (cdr s2))))
        ((< (car s1) (car s2))
         (cons (car s1) (union-set-ordered (cdr s1) s2)))
        (t (cons (car s2) (union-set-ordered s1 (cdr s2))))))
(union-set-ordered (list 1 3 5) (list 2 3 4 6))")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
