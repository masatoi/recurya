;;;; game/notebooks/sicp-2-3-4.lisp --- SICP 2.3.4 Huffman Encoding Trees.

(defpackage #:recurya/game/notebooks/sicp-2-3-4
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-2-3-4-notebook))

(in-package #:recurya/game/notebooks/sicp-2-3-4)

(defun make-sicp-2-3-4-notebook ()
  "SICP 2.3.4 - Huffman Encoding Trees."
  (make-notebook
   :id :sicp-2-3-4
   :chapter "2.3.4"
   :title "Huffman 符号木"
   :summary "出現頻度に応じた可変長符号 (Huffman 符号) を木構造で表現し、葉と内部ノードの抽象化、ビット列の復号 decode を実装する"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p (:strong "Huffman 符号")
                           ": 出現頻度の高いシンボルに短い符号を割り当てる "
                           (:strong "可変長符号")
                           "。木構造で表現し、葉に到達するまで枝を辿ることでデコードします。")))
    (make-cell :id :leaves-prose :kind :prose
               :body '(:div
                       (:p "葉 (leaf) は "
                           (:code "(list 'leaf symbol weight)")
                           "。内部ノードは "
                           (:code "(list left right symbols weight)")
                           "。葉と内部ノードを統一的に扱える "
                           (:code "symbols")
                           " / "
                           (:code "weight")
                           " 抽象を作ります。")))
    (make-cell :id :leaves-code :kind :code-eval
               :body "(define (make-leaf sym weight) (list 'leaf sym weight))
(define (leaf? node) (eq? (car node) 'leaf))
(define (symbol-leaf x) (car (cdr x)))
(define (weight-leaf x) (car (cdr (cdr x))))
(define la (make-leaf 'A 4))
(list (leaf? la) (symbol-leaf la) (weight-leaf la))")
    (make-cell :id :tree-build-prose :kind :prose
               :body '(:div
                       (:p "内部ノードの "
                           (:code "make-code-tree")
                           " は左右の部分木のシンボル集合を連結し、重みの合計を保持します。"
                           (:code "symbols")
                           " と "
                           (:code "weight")
                           " はノード種別で分岐します。")))
    (make-cell :id :tree-build-code :kind :code-eval
               :body "(define (make-leaf sym weight) (list 'leaf sym weight))
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
(define sample-tree
  (make-code-tree (make-leaf 'A 4)
                  (make-code-tree (make-leaf 'B 2)
                                  (make-code-tree (make-leaf 'D 1) (make-leaf 'C 1)))))
(list (symbols sample-tree) (weight sample-tree))")
    (make-cell :id :decode-prose :kind :prose
               :body '(:div
                       (:p (:strong "復号 (decode)")
                           ": ビット列を木の根から辿り、葉に到達したらそのシンボルを出力。"
                           (:code "0")
                           " で左、"
                           (:code "1")
                           " で右に進み、葉に着いたら根に戻ります。")))
    (make-cell :id :decode-code :kind :code-eval
               :body "(define (make-leaf sym weight) (list 'leaf sym weight))
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
                                  (make-code-tree (make-leaf 'D 1) (make-leaf 'C 1)))))
(decode (list 0 1 1 0 0 1 0 1 0 1 1 1 0) sample-tree)")
    (make-cell :id :ex-decode :kind :code-exercise
               :description
               "上のセルと同じ抽象 (make-leaf, leaf?, left-branch, right-branch, symbols, weight,
make-code-tree, choose-branch, decode) を組み立て、
標準サンプル木
  sample-tree =
    (make-code-tree (make-leaf 'A 4)
                    (make-code-tree (make-leaf 'B 2)
                                    (make-code-tree (make-leaf 'D 1) (make-leaf 'C 1))))
を作ったうえで、最終式として
  (decode (list 0 1 1 0) sample-tree)
を残してください。結果は (a d) になります。"
               :body "; (define (make-leaf ...) ...)
; (define (leaf? ...) ...)
; (define sample-tree ...)
; (define (decode bits tree) ...)
; 最後に (decode (list 0 1 1 0) sample-tree)
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "(a d)"
                                     :description "0 1 1 0 は A の後 D")))
    (make-cell :id :ex-symbols-weight :kind :code-exercise
               :description
               "同じ sample-tree について
  (list (symbols sample-tree) (weight sample-tree))
を最終式に。シンボル集合と重みの合計が ((a b d c) 8) になります。"
               :body "; (define (make-leaf ...) ...)
; (define (symbols tree) ...)
; (define (weight tree) ...)
; (define sample-tree ...)
; 最後に (list (symbols sample-tree) (weight sample-tree))
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "((a b d c) 8)"
                                     :description "葉のシンボル列と重みの合計"))))))
