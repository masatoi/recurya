===prose===
前節の `sqrt-y` は `square`・`good-enough?`・`improve`・`sqrt-iter` という 4 つの補助手続きを大域に晒していました。

しかし、これらは `sqrt-y` の **実装詳細** であって、外から見えなくても何も困りません。**内部定義 (internal define)** で、これらを関数の中に閉じ込めましょう。

===eval===
(define (sqrt-y x)
  (define (square g) (* g g))
  (define (abs-val a) (if (< a 0) (- 0 a) a))
  (define (good-enough? guess)
    (< (abs-val (- (square guess) x)) 0.001))
  (define (improve guess) (/ (+ guess (/ x guess)) 2))
  (define (iter guess)
    (if (good-enough? guess) guess (iter (improve guess))))
  (iter 1.0))
(sqrt-y 9)

===prose===
**注目してください。** 内側の `good-enough?` と `improve` は、引数として `x` を受け取っていません。

それでも本体の中で `x` を使えるのは、これらが外側の `sqrt-y` の引数 `x` を直接参照しているからです。これを **レキシカルスコープ** と呼びます。

===prose===
内部定義のおかげで、外部に見える名前は `sqrt-y` ただ一つだけになりました。`good-enough?` や `iter` は他の関数と名前がぶつかる心配がありません。

利用者から見ると `sqrt-y` は「数を入れたら平方根が出てくる箱」でしかなく、中の仕組みを意識する必要はありません。これが **ブラックボックス抽象** の核心です。

===exercise: 立方根 cube-root を、内部定義のみ で書いてください。 square・abs-val・good-enough?・improve・iter をすべて cube-root の内側に置き、外部 API は cube-root 一つだけ。 最終式として (cube-root 8) を残してください。===
; (define (cube-root x)
;   (define (square g) ...)
;   (define (abs-val a) ...)
;   (define (good-enough? guess) ...)   ; (* guess (square guess)) と x を比べる
;   (define (improve guess) ...)        ; (/ (+ (/ x (square guess)) (* 2 guess)) 3)
;   (define (iter guess) ...)
;   (iter 1.0))
; 最後に (cube-root 8)

===expect: 8 の立方根を Newton 法で===
2.000004911675504

===solution: 立方根 cube-root を、内部定義のみ で書いてください。 square・abs-val・good-enough?・improve・iter をすべて cube-root の内側に置き、外部 API は cube-root 一つだけ。 最終式として (cube-root 8) を残してください。===
(define (cube-root x)
  (define (square g) (* g g))
  (define (abs-val a) (if (< a 0) (- 0 a) a))
  (define (good-enough? guess)
    (< (abs-val (- (* guess (square guess)) x)) 0.001))
  (define (improve guess)
    (/ (+ (/ x (square guess)) (* 2 guess)) 3))
  (define (iter guess)
    (if (good-enough? guess) guess (iter (improve guess))))
  (iter 1.0))
(cube-root 8)

===exercise: 次の階乗手続きを、内部定義のみを使って factorial に書き換えてください。 反復用の補助手続き iter を factorial の内側に置き、外部 API は factorial 一つだけ。最終式として (factorial 5) を残してください。===
; (define (factorial n)
;   (define (iter i acc) ...)            ; i が n を超えたら acc を返す
;   (iter 1 1))
; 最後に (factorial 5)

===expect: 5! = 120===
120

===solution: 次の階乗手続きを、内部定義のみを使って factorial に書き換えてください。 反復用の補助手続き iter を factorial の内側に置き、外部 API は factorial 一つだけ。最終式として (factorial 5) を残してください。===
(define (factorial n)
  (define (iter i acc)
    (if (> i n) acc (iter (+ i 1) (* acc i))))
  (iter 1 1))
(factorial 5)
