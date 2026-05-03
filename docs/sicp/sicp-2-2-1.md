===prose===
系列 (sequence) を `cons` で並べると `(cons 1 (cons 2 (cons 3 nil)))` のような入れ子構造になります。これがいわゆる **リスト** です。`(list 1 2 3)` はこの cons の入れ子と同じ意味の構文糖です。

リストの末尾は `nil` (空リスト) で表し、「これ以上要素がない」ことを示します。

===eval===
(define xs (list 1 2 3 4 5))
xs

===prose===
`car` は先頭要素、`cdr` は残りのリストを返します。リストを舐める処理は、`(null? items)` で空リストか判定し、そうでなければ `(car items)` と `(cdr items)` で再帰する、というパターンになります。

===eval===
(define (list-ref items n)
  (if (= n 0)
      (car items)
      (list-ref (cdr items) (- n 1))))
(define (my-length items)
  (if (null? items)
      0
      (+ 1 (my-length (cdr items)))))
(list (list-ref (list 'a 'b 'c 'd) 2)
      (my-length (list 1 2 3 4 5)))

===prose===
再帰呼び出しが「結果に対して何もしない」末尾位置にあれば、**反復的プロセス** になり、空間 Θ(1) で動きます。`length` を反復版で書き直してみましょう。

===eval===
(define (length-iter items count)
  (if (null? items)
      count
      (length-iter (cdr items) (+ count 1))))
(define (my-length items) (length-iter items 0))
(my-length (list 1 2 3 4 5 6 7))

===prose===
`append` は最初のリストの末尾に 2 番目のリストを連結します。再帰でリストを舐めながら、空になったらもう一方をそのまま返します。

`reverse` は先頭から要素を取り出し、後ろから前にむかって新しい先頭に積んでいくことで実現できます。

===eval===
(define (my-append xs ys)
  (if (null? xs)
      ys
      (cons (car xs) (my-append (cdr xs) ys))))
(define (my-reverse xs)
  (if (null? xs)
      nil
      (my-append (my-reverse (cdr xs)) (list (car xs)))))
(list (my-append (list 1 2) (list 3 4))
      (my-reverse (list 1 2 3 4)))

===exercise: リストの末尾のペア (要素 1 個だけのリスト) を返す手続き (last-pair items) を書いてください。 たとえば (last-pair (list 1 2 3)) は (3) (= 3 だけからなるリスト) を返します。 最終式として (last-pair (list 1 2 3)) を残してください。===
; (define (last-pair items) ...)
; 最後に (last-pair (list 1 2 3))

===expect: (last-pair (list 1 2 3)) は要素 1 個のリスト (3)===
(3)

===solution: リストの末尾のペア (要素 1 個だけのリスト) を返す手続き (last-pair items) を書いてください。 たとえば (last-pair (list 1 2 3)) は (3) (= 3 だけからなるリスト) を返します。 最終式として (last-pair (list 1 2 3)) を残してください。===
(define (last-pair items)
  (if (null? (cdr items)) items (last-pair (cdr items))))
(last-pair (list 1 2 3))

===exercise: フラットなリストを反復版で反転する手続き (reverse-iter items) を書いてください。 内部に補助手続き (iter xs acc) を定義し、acc にこれまで取り出した要素を cons で積んでいくと、自然な反復プロセスになります。 最終式として (reverse-iter (list 1 2 3 4 5)) を残してください。 結果は (5 4 3 2 1) になります。===
; (define (reverse-iter items)
;   (define (iter xs acc) ...)
;   (iter items nil))
; 最後に (reverse-iter (list 1 2 3 4 5))

===expect: (reverse-iter (list 1 2 3 4 5)) は (5 4 3 2 1)===
(5 4 3 2 1)

===solution: フラットなリストを反復版で反転する手続き (reverse-iter items) を書いてください。 内部に補助手続き (iter xs acc) を定義し、acc にこれまで取り出した要素を cons で積んでいくと、自然な反復プロセスになります。 最終式として (reverse-iter (list 1 2 3 4 5)) を残してください。 結果は (5 4 3 2 1) になります。===
(define (reverse-iter items)
  (define (iter xs acc)
    (if (null? xs) acc (iter (cdr xs) (cons (car xs) acc))))
  (iter items nil))
(reverse-iter (list 1 2 3 4 5))
