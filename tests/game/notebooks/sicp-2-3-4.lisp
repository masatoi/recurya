;;;; tests/game/notebooks/sicp-2-3-4.lisp --- Smoke test for SICP 2.3.4.

(defpackage #:recurya/tests/game/notebooks/sicp-2-3-4
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-2-3-4
                #:make-sicp-2-3-4-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind #:cell-body
                #:run-cell #:notebook-cell-result-status))

(in-package #:recurya/tests/game/notebooks/sicp-2-3-4)

(deftest sicp-2-3-4-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-2-3-4-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))

(defparameter *huffman-prelude*
  "(define (make-leaf sym weight) (list 'leaf sym weight))
(define (leaf? node) (eq? (car node) 'leaf))
(define (symbol-leaf x) (car (cdr x)))
(define (weight-leaf x) (car (cdr (cdr x))))
(define (left-branch tree) (car tree))
(define (right-branch tree) (car (cdr tree)))
(define (symbols tree)
  (if (leaf? tree) (list (symbol-leaf tree)) (car (cdr (cdr tree)))))
(define (weight tree)
  (if (leaf? tree) (weight-leaf tree) (car (cdr (cdr (cdr tree))))))
(define (make-code-tree left right)
  (list left right
        (append (symbols left) (symbols right))
        (+ (weight left) (weight right))))
(define (choose-branch bit branch)
  (cond ((= bit 0) (left-branch branch))
        ((= bit 1) (right-branch branch))
        (t 'bad-bit)))
(define (decode bits tree)
  (define (decode-1 bits current)
    (if (null? bits)
        nil
        (let ((next (choose-branch (car bits) current)))
          (if (leaf? next)
              (cons (symbol-leaf next) (decode-1 (cdr bits) tree))
              (decode-1 (cdr bits) next)))))
  (decode-1 bits tree))
(define sample-tree
  (make-code-tree (make-leaf 'A 4)
                  (make-code-tree (make-leaf 'B 2)
                                  (make-code-tree (make-leaf 'D 1) (make-leaf 'C 1)))))")

(deftest sicp-2-3-4-ex-decode-passes
  (testing "the ex-decode exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-2-3-4-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-decode cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       (format nil "~A~%(decode (list 0 1 1 0) sample-tree)" *huffman-prelude*))
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))

(deftest sicp-2-3-4-ex-symbols-weight-passes
  (testing "the ex-symbols-weight exercise grades as :pass with canonical solution"
    (let* ((nb (make-sicp-2-3-4-notebook))
           (cells (notebook-cells nb))
           (ex-idx (position :ex-symbols-weight cells :key #'cell-id))
           (codes (loop for c in cells
                        for i from 0
                        collect (cond ((= i ex-idx)
                                       (format nil "~A~%(list (symbols sample-tree) (weight sample-tree))" *huffman-prelude*))
                                      ((eq (cell-kind c) :code-eval)
                                       (cell-body c))
                                      (t ""))))
           (result (run-cell nb ex-idx codes)))
      (ok (eq :pass (notebook-cell-result-status result))))))
