===prose===
集合は `element-of-set?` / `adjoin-set` / `union-set` / `intersection-set` の 4 操作で表現の差を吸収できます。同じ操作集合を 3 通りに実装し、計算量を比較します。

===prose===
**順序なしリスト**: 重複なし、線形検索。`element-of-set?` は Θ(n)、`adjoin-set` も Θ(n)。

===eval===
(define (element-of-set? x s)
  (cond ((null? s) nil)
        ((equal? x (car s)) t)
        (t (element-of-set? x (cdr s)))))
(define (adjoin-set x s) (if (element-of-set? x s) s (cons x s)))
(list (element-of-set? 'a '(a b c)) (adjoin-set 'd '(a b c)))

===prose===
**順序付きリスト**: ソート済を保つ。`element-of-set?` は Θ(n) だが平均的には早く打ち切れる。`adjoin-set` はソートを壊さない位置に挿入。

===eval===
(define (element-of-set?-ordered x s)
  (cond ((null? s) nil)
        ((= x (car s)) t)
        ((< x (car s)) nil)
        (t (element-of-set?-ordered x (cdr s)))))
(list (element-of-set?-ordered 3 (list 1 3 5 7))
      (element-of-set?-ordered 4 (list 1 3 5 7)))

===prose===
**二分木**: 各ノード `(value left right)`。`element-of-set?` は Θ(log n) (バランスしていれば)。

===eval===
(define (entry tr) (car tr))
(define (left-branch tr) (car (cdr tr)))
(define (right-branch tr) (car (cdr (cdr tr))))
(define (make-tree entry left right) (list entry left right))
(define (element-of-set?-tree x s)
  (cond ((null? s) nil)
        ((= x (entry s)) t)
        ((< x (entry s)) (element-of-set?-tree x (left-branch s)))
        (t (element-of-set?-tree x (right-branch s)))))
(define sample (make-tree 5 (make-tree 3 nil nil) (make-tree 7 nil nil)))
(list (element-of-set?-tree 3 sample) (element-of-set?-tree 9 sample))

===exercise: 順序なしリスト版の (intersection-set s1 s2) を element-of-set? を使って書いてください。 s1 を走査し、s2 にも含まれる要素のみを集める素直な再帰で書けます。 最終式として (intersection-set '(a b c d) '(b d e f)) を残してください。s1 の出現順に拾うので結果は (b d) になります。===
; (define (element-of-set? x s) ...)
; (define (intersection-set s1 s2) ...)
; 最後に (intersection-set '(a b c d) '(b d e f))

===expect: 両方に共通する要素のみ===
(b d)

===solution: 順序なしリスト版の (intersection-set s1 s2) を element-of-set? を使って書いてください。 s1 を走査し、s2 にも含まれる要素のみを集める素直な再帰で書けます。 最終式として (intersection-set '(a b c d) '(b d e f)) を残してください。s1 の出現順に拾うので結果は (b d) になります。===
(define (element-of-set? x s)
  (cond ((null? s) nil)
        ((equal? x (car s)) t)
        (t (element-of-set? x (cdr s)))))
(define (intersection-set s1 s2)
  (cond ((null? s1) nil)
        ((element-of-set? (car s1) s2)
         (cons (car s1) (intersection-set (cdr s1) s2)))
        (t (intersection-set (cdr s1) s2))))
(intersection-set '(a b c d) '(b d e f))

===exercise: 順序付きリスト版の (union-set-ordered s1 s2) を merge sort 方式で書いてください。 両方とも昇順ソート済の数値リストとし、結果も昇順・重複なしになるようにします。 最終式として (union-set-ordered (list 1 3 5) (list 2 3 4 6)) を残してください。結果は (1 2 3 4 5 6) になります。===
; (define (union-set-ordered s1 s2) ...)
; 最後に (union-set-ordered (list 1 3 5) (list 2 3 4 6))

===expect: merge 方式で重複を除いて昇順合併===
(1 2 3 4 5 6)

===solution: 順序付きリスト版の (union-set-ordered s1 s2) を merge sort 方式で書いてください。 両方とも昇順ソート済の数値リストとし、結果も昇順・重複なしになるようにします。 最終式として (union-set-ordered (list 1 3 5) (list 2 3 4 6)) を残してください。結果は (1 2 3 4 5 6) になります。===
(define (union-set-ordered s1 s2)
  (cond ((null? s1) s2)
        ((null? s2) s1)
        ((= (car s1) (car s2))
         (cons (car s1) (union-set-ordered (cdr s1) (cdr s2))))
        ((< (car s1) (car s2))
         (cons (car s1) (union-set-ordered (cdr s1) s2)))
        (t (cons (car s2) (union-set-ordered s1 (cdr s2))))))
(union-set-ordered (list 1 3 5) (list 2 3 4 6))
