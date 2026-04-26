;;;; tests/game/notebooks/sicp-3-3-5.lisp --- Smoke and grading tests for SICP 3.3.5.

(defpackage #:recurya/tests/game/notebooks/sicp-3-3-5
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-3-3-5
                #:make-sicp-3-3-5-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-3-3-5)

(deftest sicp-3-3-5-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-3-3-5-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 5))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(defparameter *cf-fwd-solution*
  "(define (lookup key alist)
  (cond ((null? alist) nil)
        ((eq? key (car (car alist))) (cdr (car alist)))
        (t (lookup key (cdr alist)))))
(define (insert key value alist)
  (cond ((null? alist) (list (cons key value)))
        ((eq? key (car (car alist))) (cons (cons key value) (cdr alist)))
        (t (cons (car alist) (insert key value (cdr alist))))))
(define (cf-constraint c f)
  (lambda (state)
    (let ((cv (lookup c state)) (fv (lookup f state)))
      (cond ((and cv (not fv)) (insert f (+ (/ (* 9 cv) 5) 32) state))
            ((and fv (not cv)) (insert c (/ (* 5 (- fv 32)) 9) state))
            (t state)))))
(define (apply-constraints constraints state)
  (if (null? constraints) state
      (apply-constraints (cdr constraints) ((car constraints) state))))
(define (iterate-until-stable f state limit)
  (if (= limit 0) state
      (let ((next (f state)))
        (if (equal? next state) state (iterate-until-stable f next (- limit 1))))))
(lookup 'F (iterate-until-stable
             (lambda (st) (apply-constraints (list (cf-constraint 'C 'F)) st))
             (list (cons 'C 100) (cons 'F nil))
             10))")

(deftest sicp-3-3-5-ex-cf-fwd-passes
  (testing "the ex-cf-fwd exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-3-3-5-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-cf-fwd cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx) *cf-fwd-solution*)
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(defparameter *cf-rev-solution*
  "(define (lookup key alist)
  (cond ((null? alist) nil)
        ((eq? key (car (car alist))) (cdr (car alist)))
        (t (lookup key (cdr alist)))))
(define (insert key value alist)
  (cond ((null? alist) (list (cons key value)))
        ((eq? key (car (car alist))) (cons (cons key value) (cdr alist)))
        (t (cons (car alist) (insert key value (cdr alist))))))
(define (cf-constraint c f)
  (lambda (state)
    (let ((cv (lookup c state)) (fv (lookup f state)))
      (cond ((and cv (not fv)) (insert f (+ (/ (* 9 cv) 5) 32) state))
            ((and fv (not cv)) (insert c (/ (* 5 (- fv 32)) 9) state))
            (t state)))))
(define (apply-constraints constraints state)
  (if (null? constraints) state
      (apply-constraints (cdr constraints) ((car constraints) state))))
(define (iterate-until-stable f state limit)
  (if (= limit 0) state
      (let ((next (f state)))
        (if (equal? next state) state (iterate-until-stable f next (- limit 1))))))
(lookup 'C (iterate-until-stable
             (lambda (st) (apply-constraints (list (cf-constraint 'C 'F)) st))
             (list (cons 'C nil) (cons 'F 32))
             10))")

(deftest sicp-3-3-5-ex-cf-rev-passes
  (testing "the ex-cf-rev exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-3-3-5-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-cf-rev cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx) *cf-rev-solution*)
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
