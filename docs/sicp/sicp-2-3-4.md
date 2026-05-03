===prose===
**Huffman 符号**: 出現頻度の高いシンボルに短い符号を割り当てる **可変長符号**。木構造で表現し、葉に到達するまで枝を辿ることでデコードします。

===prose===
葉 (leaf) は `(list 'leaf symbol weight)`。内部ノードは `(list left right symbols weight)`。葉と内部ノードを統一的に扱える `symbols` / `weight` 抽象を作ります。

===eval===
(define (make-leaf sym weight) (list 'leaf sym weight))
(define (leaf? node) (eq? (car node) 'leaf))
(define (symbol-leaf x) (car (cdr x)))
(define (weight-leaf x) (car (cdr (cdr x))))
(define la (make-leaf 'A 4))
(list (leaf? la) (symbol-leaf la) (weight-leaf la))

===prose===
内部ノードの `make-code-tree` は左右の部分木のシンボル集合を連結し、重みの合計を保持します。`symbols` と `weight` はノード種別で分岐します。

===eval===
(define (make-leaf sym weight) (list 'leaf sym weight))
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
(list (symbols sample-tree) (weight sample-tree))

===prose===
**復号 (decode)**: ビット列を木の根から辿り、葉に到達したらそのシンボルを出力。`0` で左、`1` で右に進み、葉に着いたら根に戻ります。

===eval===
(define (make-leaf sym weight) (list 'leaf sym weight))
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
(decode (list 0 1 1 0 0 1 0 1 0 1 1 1 0) sample-tree)

===exercise: 上のセルと同じ抽象 (make-leaf, leaf?, left-branch, right-branch, symbols, weight, make-code-tree, choose-branch, decode) を組み立て、 標準サンプル木 sample-tree = (make-code-tree (make-leaf 'A 4) (make-code-tree (make-leaf 'B 2) (make-code-tree (make-leaf 'D 1) (make-leaf 'C 1)))) を作ったうえで、最終式として (decode (list 0 1 1 0) sample-tree) を残してください。結果は (a d) になります。===
; (define (make-leaf ...) ...)
; (define (leaf? ...) ...)
; (define sample-tree ...)
; (define (decode bits tree) ...)
; 最後に (decode (list 0 1 1 0) sample-tree)

===expect: 0 1 1 0 は A の後 D===
(a d)

===solution: 上のセルと同じ抽象 (make-leaf, leaf?, left-branch, right-branch, symbols, weight, make-code-tree, choose-branch, decode) を組み立て、 標準サンプル木 sample-tree = (make-code-tree (make-leaf 'A 4) (make-code-tree (make-leaf 'B 2) (make-code-tree (make-leaf 'D 1) (make-leaf 'C 1)))) を作ったうえで、最終式として (decode (list 0 1 1 0) sample-tree) を残してください。結果は (a d) になります。===
(define (make-leaf sym weight) (list 'leaf sym weight))
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
(decode (list 0 1 1 0) sample-tree)

===exercise: 同じ sample-tree について (list (symbols sample-tree) (weight sample-tree)) を最終式に。シンボル集合と重みの合計が ((a b d c) 8) になります。===
; (define (make-leaf ...) ...)
; (define (symbols tree) ...)
; (define (weight tree) ...)
; (define sample-tree ...)
; 最後に (list (symbols sample-tree) (weight sample-tree))

===expect: 葉のシンボル列と重みの合計===
((a b d c) 8)

===solution: 同じ sample-tree について (list (symbols sample-tree) (weight sample-tree)) を最終式に。シンボル集合と重みの合計が ((a b d c) 8) になります。===
(define (make-leaf sym weight) (list 'leaf sym weight))
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
(list (symbols sample-tree) (weight sample-tree))
