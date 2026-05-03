===prose===
`(list 'a 'b)` のように `'` をつけると、その式は **評価されず** そのまま記号として扱われます。`'a` は **シンボル** `a` を表す。これを **引用 (quotation)** と呼びます。

===eval===
(list 'a 'b 'c)

===prose===
シンボルはそれ自身の名前を値とする atomic な値です。`eq?` でシンボル同士の **同一性** を判定できます。

===eval===
(list (eq? 'apple 'apple) (eq? 'apple 'orange))

===prose===
`'(a b c)` のように直接引用してリストを作ることもできます。これは `(list 'a 'b 'c)` と同じです。

===eval===
'(a b c)

===prose===
`memq` は、リスト中に等しい (`eq?`) 要素があれば **その要素以降の sublist** を返し、なければ `nil` を返します。

===eval===
(define (memq item xs)
  (cond ((null? xs) nil)
        ((eq? item (car xs)) xs)
        (t (memq item (cdr xs)))))
(list (memq 'apple '(pear banana apple grape)) (memq 'fig '(pear banana apple)))

===exercise: 自前の (my-equal? a b) を書いてください。 両方が atom なら eq? で比較、両方が pair なら car と cdr を再帰的に比較します。 どちらか一方だけが atom の場合は nil。 最終式として (my-equal? '(this is a list) '(this is a list)) を残してください。結果は t になります。===
; (define (my-equal? a b) ...)
; 最後に (my-equal? '(this is a list) '(this is a list))

===expect: 同じ構造のリストは等しい===
t

===solution: 自前の (my-equal? a b) を書いてください。 両方が atom なら eq? で比較、両方が pair なら car と cdr を再帰的に比較します。 どちらか一方だけが atom の場合は nil。 最終式として (my-equal? '(this is a list) '(this is a list)) を残してください。結果は t になります。===
(define (my-equal? a b)
  (cond ((and (atom? a) (atom? b)) (eq? a b))
        ((or (atom? a) (atom? b)) nil)
        (t (and (my-equal? (car a) (car b))
                (my-equal? (cdr a) (cdr b))))))
(my-equal? '(this is a list) '(this is a list))

===exercise: シンボルのフラットなリストの中に、特定のシンボルが何回現れるかを数える (count-occurrences sym xs) を書いてください。 xs は入れ子のないシンボル列です。eq? で要素を比較し、再帰的に走査します。 最終式として (count-occurrences 'a '(a b a c a d a)) を残してください。結果は 4 になります。===
; (define (count-occurrences sym xs) ...)
; 最後に (count-occurrences 'a '(a b a c a d a))

===expect: 'a が 4 回現れる===
4

===solution: シンボルのフラットなリストの中に、特定のシンボルが何回現れるかを数える (count-occurrences sym xs) を書いてください。 xs は入れ子のないシンボル列です。eq? で要素を比較し、再帰的に走査します。 最終式として (count-occurrences 'a '(a b a c a d a)) を残してください。結果は 4 になります。===
(define (count-occurrences sym xs)
  (cond ((null? xs) 0)
        ((eq? sym (car xs)) (+ 1 (count-occurrences sym (cdr xs))))
        (t (count-occurrences sym (cdr xs)))))
(count-occurrences 'a '(a b a c a d a))
