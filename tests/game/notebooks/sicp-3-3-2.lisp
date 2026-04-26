;;;; tests/game/notebooks/sicp-3-3-2.lisp --- Smoke and grading tests for SICP 3.3.2.

(defpackage #:recurya/tests/game/notebooks/sicp-3-3-2
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-3-3-2
                #:make-sicp-3-3-2-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-3-3-2)

(deftest sicp-3-3-2-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-3-3-2-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(defparameter *fifo-solution*
  "(define (make-queue) (cons nil nil))
(define (front q) (car q))
(define (back q) (cdr q))
(define (queue-empty? q) (and (null? (front q)) (null? (back q))))
(define (enqueue q x) (cons (front q) (cons x (back q))))
(define (rev-iter xs acc) (if (null? xs) acc (rev-iter (cdr xs) (cons (car xs) acc))))
(define (rev xs) (rev-iter xs nil))
(define (dequeue q)
  (cond ((queue-empty? q) 'empty)
        ((null? (front q))
         (let ((flipped (rev (back q))))
           (cons (car flipped) (cons (cdr flipped) nil))))
        (t (cons (car (front q)) (cons (cdr (front q)) (back q))))))
(let* ((q (enqueue (enqueue (enqueue (make-queue) 'a) 'b) 'c))
       (r (dequeue q)))
  (car r))")

(deftest sicp-3-3-2-ex-fifo-passes
  (testing "the ex-fifo exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-3-3-2-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-fifo cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx) *fifo-solution*)
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(defparameter *three-deqs-solution*
  "(define (make-queue) (cons nil nil))
(define (front q) (car q))
(define (back q) (cdr q))
(define (queue-empty? q) (and (null? (front q)) (null? (back q))))
(define (enqueue q x) (cons (front q) (cons x (back q))))
(define (rev-iter xs acc) (if (null? xs) acc (rev-iter (cdr xs) (cons (car xs) acc))))
(define (rev xs) (rev-iter xs nil))
(define (dequeue q)
  (cond ((queue-empty? q) 'empty)
        ((null? (front q))
         (let ((flipped (rev (back q))))
           (cons (car flipped) (cons (cdr flipped) nil))))
        (t (cons (car (front q)) (cons (cdr (front q)) (back q))))))
(define (three-deqs)
  (let* ((q1 (enqueue (enqueue (enqueue (make-queue) 'a) 'b) 'c))
         (r1 (dequeue q1))
         (v1 (car r1))
         (q2 (cdr r1))
         (r2 (dequeue q2))
         (v2 (car r2))
         (q3 (cdr r2))
         (r3 (dequeue q3))
         (v3 (car r3)))
    (list v1 v2 v3)))
(three-deqs)")

(deftest sicp-3-3-2-ex-three-deqs-passes
  (testing "the ex-three-deqs exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-3-3-2-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-three-deqs cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx) *three-deqs-solution*)
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
