===prose===
リストに対する操作には共通のパターンがあります: 各要素に関数を適用する `map` 、条件を満たす要素だけ残す `filter` 、畳み込みで一つの値にまとめる `accumulate` (= reduce) です。

これらを高階手続きとして用意しておくと、多くのリスト処理は「どう書くか」よりも **データの流れ** として簡潔に表現できるようになります。

===eval===
(define (my-map f xs)
  (if (null? xs)
      nil
      (cons (f (car xs)) (my-map f (cdr xs)))))
(define (my-filter p xs)
  (cond ((null? xs) nil)
        ((p (car xs)) (cons (car xs) (my-filter p (cdr xs))))
        (t (my-filter p (cdr xs)))))
(define (accumulate op init xs)
  (if (null? xs)
      init
      (op (car xs) (accumulate op init (cdr xs)))))
(list (my-map (lambda (x) (* x x)) (list 1 2 3 4))
      (my-filter (lambda (x) (> x 2)) (list 1 2 3 4 5))
      (accumulate + 0 (list 1 2 3 4 5)))

===prose===
これら 3 つを組み合わせると、「奇数だけを取り出し、それぞれを 2 乗して、和を取る」というような問題が **1 行のパイプライン** で書けます。

問題が `filter` -> `map` -> `accumulate` のデータの流れに分解できる、というのが SICP 2.2.3 のキーアイデアです。

===eval===
(define (my-map f xs)
  (if (null? xs)
      nil
      (cons (f (car xs)) (my-map f (cdr xs)))))
(define (my-filter p xs)
  (cond ((null? xs) nil)
        ((p (car xs)) (cons (car xs) (my-filter p (cdr xs))))
        (t (my-filter p (cdr xs)))))
(define (accumulate op init xs)
  (if (null? xs)
      init
      (op (car xs) (accumulate op init (cdr xs)))))
(define (sum-odd-squares xs)
  (accumulate + 0
    (my-map (lambda (x) (* x x))
      (my-filter (lambda (x) (= (mod x 2) 1)) xs))))
(sum-odd-squares (list 1 2 3 4 5 6 7))

===prose===
木の上でも同じ系列インタフェースを使うには、まず木を「葉のリスト」に平らに並べる `enumerate-tree` を用意します。こうすれば木の問題も `filter / map / accumulate` のパイプラインに乗ります。

===eval===
(define (pair? x) (and (not (null? x)) (not (atom? x))))
(define (enumerate-tree tr)
  (cond ((null? tr) nil)
        ((not (pair? tr)) (list tr))
        (t (append (enumerate-tree (car tr))
                   (enumerate-tree (cdr tr))))))
(enumerate-tree (list 1 (list 2 (list 3 4)) 5))

===exercise: (product-list xs) を accumulate を使って書いてください。 リストの全要素の積を返します。 accumulate は事前にセル内で再定義しておく必要があります (引数の順は (op init xs))。 最終式として (product-list (list 1 2 3 4 5)) を残してください。 結果は 120 です。===
; (define (accumulate op init xs) ...)
; (define (product-list xs) (accumulate ...))
; 最後に (product-list (list 1 2 3 4 5))

===expect: 1*2*3*4*5 = 120===
120

===solution: (product-list xs) を accumulate を使って書いてください。 リストの全要素の積を返します。 accumulate は事前にセル内で再定義しておく必要があります (引数の順は (op init xs))。 最終式として (product-list (list 1 2 3 4 5)) を残してください。 結果は 120 です。===
(define (accumulate op init xs)
  (if (null? xs) init (op (car xs) (accumulate op init (cdr xs)))))
(define (product-list xs) (accumulate * 1 xs))
(product-list (list 1 2 3 4 5))

===exercise: (flatmap f xs) を実装してください。 定義は次のとおりです: (flatmap f xs) = (accumulate append nil (map f xs)) つまり f を各要素に適用した結果のリスト達を、append で 1 本につなぎます。 my-map と accumulate も同じセル内に再定義してください。 最終式として (flatmap (lambda (x) (list x (* x x))) (list 1 2 3)) を残してください。結果は (1 1 2 4 3 9) になります。===
; (define (my-map f xs) ...)
; (define (accumulate op init xs) ...)
; (define (flatmap f xs) (accumulate append nil (my-map f xs)))
; 最後に (flatmap (lambda (x) (list x (* x x))) (list 1 2 3))

===expect: 各 x について (x (* x x)) を作り全部つなぐ===
(1 1 2 4 3 9)

===solution: (flatmap f xs) を実装してください。 定義は次のとおりです: (flatmap f xs) = (accumulate append nil (map f xs)) つまり f を各要素に適用した結果のリスト達を、append で 1 本につなぎます。 my-map と accumulate も同じセル内に再定義してください。 最終式として (flatmap (lambda (x) (list x (* x x))) (list 1 2 3)) を残してください。結果は (1 1 2 4 3 9) になります。===
(define (my-map f xs)
  (if (null? xs) nil (cons (f (car xs)) (my-map f (cdr xs)))))
(define (accumulate op init xs)
  (if (null? xs) init (op (car xs) (accumulate op init (cdr xs)))))
(define (flatmap f xs) (accumulate append nil (my-map f xs)))
(flatmap (lambda (x) (list x (* x x))) (list 1 2 3))

===exercise: リストの長さを accumulate だけで実装してください。 ヒント: (my-length xs) = (accumulate (lambda (_ count) (+ count 1)) 0 xs) 要素そのものは使わず、走査するたびに count を 1 増やします。 accumulate は同じセル内に再定義してください。 最終式として (my-length (list 'a 'b 'c 'd 'e)) を残してください。 結果は 5 です。===
; (define (accumulate op init xs) ...)
; (define (my-length xs) (accumulate (lambda (_ count) (+ count 1)) 0 xs))
; 最後に (my-length (list 'a 'b 'c 'd 'e))

===expect: 要素数 5===
5

===solution: リストの長さを accumulate だけで実装してください。 ヒント: (my-length xs) = (accumulate (lambda (_ count) (+ count 1)) 0 xs) 要素そのものは使わず、走査するたびに count を 1 増やします。 accumulate は同じセル内に再定義してください。 最終式として (my-length (list 'a 'b 'c 'd 'e)) を残してください。 結果は 5 です。===
(define (accumulate op init xs)
  (if (null? xs) init (op (car xs) (accumulate op init (cdr xs)))))
(define (my-length xs) (accumulate (lambda (_ count) (+ count 1)) 0 xs))
(my-length (list 'a 'b 'c 'd 'e))
