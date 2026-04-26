;;;; tests/game/notebooks/sicp-3-1-1.lisp --- Smoke and grading tests for SICP 3.1.1.

(defpackage #:recurya/tests/game/notebooks/sicp-3-1-1
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-3-1-1
                #:make-sicp-3-1-1-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-3-1-1)

(deftest sicp-3-1-1-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-3-1-1-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(defparameter *account-prelude*
  "(define (make-account balance) (cons 'account balance))
(define (account-balance acc) (cdr acc))
(define (withdraw acc amt)
  (if (>= (account-balance acc) amt)
      (make-account (- (account-balance acc) amt))
      acc))
(define (deposit acc amt)
  (make-account (+ (account-balance acc) amt)))")

(deftest sicp-3-1-1-ex-account-ops-passes
  (testing "the ex-account-ops exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-3-1-1-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-account-ops cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       (format nil "~A~%(account-balance ((lambda (a) (withdraw (withdraw (deposit a 50) 30) 200)) (make-account 100)))"
                                               *account-prelude*))
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(defparameter *counter-prelude*
  "(define (make-counter) (cons 'counter 0))
(define (counter-value c) (cdr c))
(define (counter-increment c) (cons 'counter (+ 1 (cdr c))))")

(deftest sicp-3-1-1-ex-counter-passes
  (testing "the ex-counter exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-3-1-1-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-counter cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       (format nil "~A~%(counter-value (counter-increment (counter-increment (counter-increment (make-counter)))))"
                                               *counter-prelude*))
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
