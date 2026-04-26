;;;; tests/game/notebooks/sicp-2-4-2.lisp --- Smoke test for SICP 2.4.2.

(defpackage #:recurya/tests/game/notebooks/sicp-2-4-2
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-2-4-2
                #:make-sicp-2-4-2-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-2-4-2)

(deftest sicp-2-4-2-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-2-4-2-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(defparameter *tagged-prelude*
  "(define (square x) (* x x))
(define (sqrt-newton x)
  (define (good? g) (< (let ((d (- (square g) x))) (if (< d 0) (- 0 d) d)) 0.001))
  (define (improve g) (/ (+ g (/ x g)) 2))
  (define (iter g) (if (good? g) g (iter (improve g))))
  (iter 1.0))
(define (attach-tag tag x) (cons tag x))
(define (type-tag x) (car x))
(define (contents x) (cdr x))
(define (rectangular? z) (eq? (type-tag z) 'rectangular))
(define (polar? z) (eq? (type-tag z) 'polar))
(define (real-part-rect z) (car (contents z)))
(define (imag-part-rect z) (cdr (contents z)))
(define (magnitude-rect z) (sqrt-newton (+ (square (real-part-rect z)) (square (imag-part-rect z)))))
(define (real-part z) (cond ((rectangular? z) (real-part-rect z)) (t 'unknown)))
(define (imag-part z) (cond ((rectangular? z) (imag-part-rect z)) (t 'unknown)))
(define (magnitude z) (cond ((rectangular? z) (magnitude-rect z)) (t 'unknown)))
(define (make-from-real-imag-tagged x y) (attach-tag 'rectangular (cons x y)))")

(deftest sicp-2-4-2-ex-dispatch-passes
  (testing "the ex-dispatch exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-2-4-2-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-dispatch cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       (format nil "~A~%(magnitude (make-from-real-imag-tagged 6 8))" *tagged-prelude*))
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-2-4-2-ex-tag-only-passes
  (testing "the ex-tag-only exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-2-4-2-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-tag-only cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (attach-tag tag x) (cons tag x))
(define (type-tag x) (car x))
(type-tag (attach-tag 'polar (cons 5 0.5)))")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
