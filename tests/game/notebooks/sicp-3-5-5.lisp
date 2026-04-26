;;;; tests/game/notebooks/sicp-3-5-5.lisp --- Smoke tests for SICP 3.5.5.

(defpackage #:recurya/tests/game/notebooks/sicp-3-5-5
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-3-5-5
                #:make-sicp-3-5-5-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-3-5-5)

(deftest sicp-3-5-5-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-3-5-5-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 5))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(deftest sicp-3-5-5-account-history-passes
  (testing "the ex-account-history exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-3-5-5-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-account-history cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       "(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-take s n)
  (if (= n 0) nil (cons (stream-car s) (stream-take (stream-cdr s) (- n 1)))))
(define (apply-tx bal tx)
  (let ((kind (car tx)) (amt (cdr tx)))
    (cond ((eq? kind 'deposit) (+ bal amt))
          ((eq? kind 'withdraw) (- bal amt))
          (t bal))))
(define (account-stream bal txs)
  (stream-cons bal
    (lambda ()
      (if (null? txs) nil (account-stream (apply-tx bal (car txs)) (cdr txs))))))
(stream-take (account-stream 50 (list (cons 'deposit 20) (cons 'withdraw 10) (cons 'deposit 5))) 4)")
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
