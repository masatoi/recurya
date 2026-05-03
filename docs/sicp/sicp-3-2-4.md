===prose===
関数の中で `define` を使うと、**その関数呼び出しのフレーム** に新しい束縛が追加されます。

つまり内部定義された関数は、**外側の関数の引数や局所変数を見られる** (= 同じフレーム列にいるので親をたどればよい)。そして外部からは **見えない** (= global からは到達できない)。

===eval===
(define (sqrt-y x)
  (define (square g) (* g g))
  (define (good? g) (< (let ((d (- (square g) x))) (if (< d 0) (- 0 d) d)) 0.001))
  (define (improve g) (/ (+ g (/ x g)) 2))
  (define (iter g) (if (good? g) g (iter (improve g))))
  (iter 1.0))
(sqrt-y 9)

===prose===
**ブラックボックス抽象**: `square` / `good?` / `improve` / `iter` は `sqrt-y` の内部にしか見えません。外部から `(square 5)` を呼ぼうとしても見つかりません (global にはない)。これは **レキシカルスコープによる情報隠蔽** の例です。

また、`good?` や `improve` の内部から `x` (sqrt-y の引数) を直接参照できる点も重要です。x は内部関数の *引数として渡されない* のに、**親フレームから自動的に見える** ─ これがクロージャの本質です。

===prose===
**ASCII 図 (sqrt-y 9 の途中)**:

```
  [global]
  └── sqrt-y: ...

  E1 [parent: global]    ← (sqrt-y 9) で作られたフレーム
  ├── x: 9
  ├── square: ...        ← 内部 define で追加
  ├── good?: ...
  ├── improve: ...
  └── iter: ...

  E2 [parent: E1]        ← (good? 1.0) で作られたフレーム
  └── g: 1.0
      body 内で (square g) → square は E1 で見つかる
            (- (square g) x) → x も E1 で見つかる
```

===prose===
**SICP 流の letrec* 解釈**: 内部 `define` は連続した `let*` のように扱われ、各 `define` は前の `define` の名前を見ることができます (WardLisp も同じ振る舞い)。

つまり後で定義された関数同士は互いを参照できる ─ `iter` の中から `improve` と `good?` を呼び出せるのはこのため。

===eval===
(define (compute x)
  (define a (+ x 1))
  (define b (* a 2))
  (define c (- b 3))
  c)
(compute 5)

===prose===
上のセルでは:

- `a` = (+ 5 1) = 6
- `b` = (* a 2) = 12 ─ b の定義時に a が見える
- `c` = (- b 3) = 9 ─ c の定義時に b が見える

順番に評価されて、各 `define` は前のものを参照できる。もし「先に c の定義が来る」ように書き換えたら、b がまだ未束縛なのでエラーになります。

===exercise: factorial-y を内部定義のみで階乗を計算するように書いてください。 iter などの内部関数は factorial-y の中にだけ見える形で。 最終式として (factorial-y 6) を残してください。期待値は 720 です。 スケルトン: (define (factorial-y n) (define (iter k acc) (if (> k n) acc (iter (+ k 1) (* acc k)))) (iter 1 1)) (factorial-y 6)===
; (define (factorial-y n)
;   (define (iter k acc) ...)
;   (iter 1 1))
; 最後に (factorial-y 6)

===expect: factorial-y で 6! = 720===
720

===solution: factorial-y を内部定義のみで階乗を計算するように書いてください。 iter などの内部関数は factorial-y の中にだけ見える形で。 最終式として (factorial-y 6) を残してください。期待値は 720 です。 スケルトン: (define (factorial-y n) (define (iter k acc) (if (> k n) acc (iter (+ k 1) (* acc k)))) (iter 1 1)) (factorial-y 6)===
(define (factorial-y n)
  (define (iter k acc)
    (if (> k n) acc (iter (+ k 1) (* acc k))))
  (iter 1 1))
(factorial-y 6)
