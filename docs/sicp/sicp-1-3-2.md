===prose===
`define` で手続きに名前を付ける必要がない場面では、**lambda 式** で名前を付けずに手続きそのものを作って渡せます。

`(lambda (引数...) 本体...)` は「引数を受け取って本体を計算する手続き」を返します。そのまま関数位置に置けば呼び出せます。

===eval===
((lambda (x) (* x x x)) 4)

===prose===
前節 1.3.1 の汎用 `sum` に渡す項手続きや次手続きも、`define` で先に名前を付ける必要はなく、`lambda` で直接書けます。

「平方を 1 から 5 まで足す」だけのために `square` と `inc` を最上位で定義する必要は必ずしもありません。

===eval===
(define (sum f a next b)
  (if (> a b) 0 (+ (f a) (sum f (next a) next b))))
(sum (lambda (x) (* x x)) 1 (lambda (x) (+ x 1)) 5)

===prose===
**let** は局所変数を束縛するための式です。ですが、これは新しい仕組みではなく、実は `lambda` の **糖衣構文 (syntactic sugar)** です。

`(let ((x 5) (y 7)) (* x y))` は内部的には

```
((lambda (x y) (* x y)) 5 7)
```

と等価です。「先に値を名前に束縛してから本体を評価する」気持ちを、より読みやすい構文で書ける、という位置付けです。

===eval===
(let ((x 5) (y 7)) (* x y))

===prose===
通常の `let` では各束縛は **並列** に評価され、後の束縛が前の束縛を参照することはできません。

それに対し `let*` は **順次束縛** で、前で導入した名前を後の束縛の右辺で使えます。中間結果を一段ずつ名前付けしながら計算したい時に便利です。

===eval===
(let* ((x 5) (y (* x 2)) (z (+ x y))) z)

===exercise: lambda 式を直接呼び出す形で、a^2 + b^2 + c^2 を計算してください。 具体的には ((lambda (a b c) ...) 1 2 3) を最終式として残し、答えが 1*1 + 2*2 + 3*3 = 14 となるようにします。define は使わなくて構いません。===
; ((lambda (a b c) ...) 1 2 3)

===expect: 1+4+9 = 14===
14

===solution: lambda 式を直接呼び出す形で、a^2 + b^2 + c^2 を計算してください。 具体的には ((lambda (a b c) ...) 1 2 3) を最終式として残し、答えが 1*1 + 2*2 + 3*3 = 14 となるようにします。define は使わなくて構いません。===
((lambda (a b c) (+ (* a a) (* b b) (* c c))) 1 2 3)

===exercise: f(x, y) = x^2 + 2*x*y + y^2 + x + y を let* を使って計算する手続き (quadratic x y) を書いてください。中間結果 (x の二乗、y の二乗、2xy、x+y) を let* で順番に名前付けしながら最終値を返す形にします。 最終式として (quadratic 3 4) を残してください。 答え: 9 + 24 + 16 + 3 + 4 = 56===
; (define (quadratic x y)
;   (let* ((sq-x ...)
;          (sq-y ...)
;          (cross ...)
;          (sum-xy ...))
;     (+ sq-x cross sq-y sum-xy)))
; 最後に (quadratic 3 4)

===expect: (quadratic 3 4) = 56===
56

===solution: f(x, y) = x^2 + 2*x*y + y^2 + x + y を let* を使って計算する手続き (quadratic x y) を書いてください。中間結果 (x の二乗、y の二乗、2xy、x+y) を let* で順番に名前付けしながら最終値を返す形にします。 最終式として (quadratic 3 4) を残してください。 答え: 9 + 24 + 16 + 3 + 4 = 56===
(define (quadratic x y)
  (let* ((sq-x (* x x))
         (sq-y (* y y))
         (cross (* 2 x y))
         (sum-xy (+ x y)))
    (+ sq-x cross sq-y sum-xy)))
(quadratic 3 4)
