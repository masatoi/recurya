===prose===
**環境モデル (environment model)** は手続き呼び出しを正確に説明する仕組みです。

「環境」とは **フレーム (frame) の列** のことで、各フレームは **名前から値への束縛 (binding)** を持ちます。フレームは外側のフレーム (親) を指す矢印を持っていて、名前を解決するときは内側のフレームから外側へ順に探します。

===prose===
`(define x 5)` は **現在のフレーム** に束縛 `x → 5` を追加します。`x` を参照すると、**現在のフレームから外側に向かって最初に見つかった束縛** が返ります。これが **レキシカルスコープ (lexical scope)** です。

「現在のフレーム」は手続き呼び出しのたびに作られる新しいフレームで、その親は手続きが *作られた* ときの環境 (定義環境) です。

===eval===
(define (make-adder n) (lambda (x) (+ x n)))
(define add3 (make-adder 3))
(define add10 (make-adder 10))
(list (add3 5) (add10 5))

===prose===
**重要**: `add3` と `add10` はそれぞれ自分が作られた時のフレーム (`n=3` または `n=10`) を **捕捉** しています。これが **クロージャ (closure)** です。`(add3 5)` を呼ぶと `n=3` のフレームを親とする新しいフレームが作られ、その中で `x=5` が束縛されて `(+ x n)` が評価されます。

===prose===
**ASCII で環境を絵にする例**:

```
  [global frame]
  ├── make-adder: (lambda (n) (lambda (x) (+ x n)))
  ├── add3: ─→ E1
  └── add10: ─→ E2

  E1 [parent: global]      E2 [parent: global]
  └── n: 3                 └── n: 10
```

`add3` を呼ぶと新フレーム `E3 [parent: E1]` が作られ、その中に `x: 5` が入ります。`(+ x n)` は `E3 → E1 → global` の順に lookup されます ─ `x` は E3 で見つかり、`n` は E1 で見つかり、`+` は global で見つかります。

===exercise: クロージャが環境を捕捉することを観察する課題です。 WardLisp には set! がないので、let で束縛した値を後から書き換えることはできません。 したがって以下のような関数を考えると ─ (define (make-counter) (lambda () 0)) make-counter を呼ぶたびに新しい lambda が作られますが、それを何度呼んでも常に同じ値 0 を返します。 最終式として (let ((cc (make-counter))) (list (cc) (cc) (cc))) を残してください。 期待値は (0 0 0) です。===
; (define (make-counter) (lambda () 0))
; 最後に (let ((cc (make-counter))) (list (cc) (cc) (cc)))

===expect: make-counter を 3 回呼んで全て 0===
(0 0 0)

===solution: クロージャが環境を捕捉することを観察する課題です。 WardLisp には set! がないので、let で束縛した値を後から書き換えることはできません。 したがって以下のような関数を考えると ─ (define (make-counter) (lambda () 0)) make-counter を呼ぶたびに新しい lambda が作られますが、それを何度呼んでも常に同じ値 0 を返します。 最終式として (let ((cc (make-counter))) (list (cc) (cc) (cc))) を残してください。 期待値は (0 0 0) です。===
(define (make-counter) (lambda () 0))
(let ((cc (make-counter))) (list (cc) (cc) (cc)))
