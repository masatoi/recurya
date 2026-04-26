;;;; game/notebooks/sicp-3-2-4.lisp --- SICP 3.2.4 Internal Definitions.

(defpackage #:recurya/game/notebooks/sicp-3-2-4
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-3-2-4-notebook))

(in-package #:recurya/game/notebooks/sicp-3-2-4)

(defun make-sicp-3-2-4-notebook ()
  "SICP 3.2.4 - Internal definitions: lexical scope and information hiding."
  (make-notebook
   :id :sicp-3-2-4
   :chapter "3.2.4"
   :title "内部定義"
   :summary "関数の中で define を使ったときの環境モデル上の意味。 内部定義は呼び出しのフレームに束縛され、レキシカルスコープによって外部から隠蔽される (ブラックボックス抽象)"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p "関数の中で "
                           (:code "define")
                           " を使うと、"
                           (:strong "その関数呼び出しのフレーム")
                           " に新しい束縛が追加されます。")
                       (:p "つまり内部定義された関数は、"
                           (:strong "外側の関数の引数や局所変数を見られる")
                           " (= 同じフレーム列にいるので親をたどればよい)。"
                           "そして外部からは "
                           (:strong "見えない")
                           " (= global からは到達できない)。")))
    (make-cell :id :sqrt-y-eval :kind :code-eval
               :body "(define (sqrt-y x)
  (define (square g) (* g g))
  (define (good? g) (< (let ((d (- (square g) x))) (if (< d 0) (- 0 d) d)) 0.001))
  (define (improve g) (/ (+ g (/ x g)) 2))
  (define (iter g) (if (good? g) g (iter (improve g))))
  (iter 1.0))
(sqrt-y 9)")
    (make-cell :id :black-box :kind :prose
               :body '(:div
                       (:p (:strong "ブラックボックス抽象")
                           ": "
                           (:code "square")
                           " / "
                           (:code "good?")
                           " / "
                           (:code "improve")
                           " / "
                           (:code "iter")
                           " は "
                           (:code "sqrt-y")
                           " の内部にしか見えません。"
                           "外部から "
                           (:code "(square 5)")
                           " を呼ぼうとしても見つかりません (global にはない)。"
                           "これは "
                           (:strong "レキシカルスコープによる情報隠蔽")
                           " の例です。")
                       (:p "また、"
                           (:code "good?")
                           " や "
                           (:code "improve")
                           " の内部から "
                           (:code "x")
                           " (sqrt-y の引数) を直接参照できる点も重要です。"
                           "x は内部関数の "
                           (:em "引数として渡されない")
                           " のに、"
                           (:strong "親フレームから自動的に見える")
                           " ─ これがクロージャの本質です。")))
    (make-cell :id :ascii-frames :kind :prose
               :body '(:div
                       (:p (:strong "ASCII 図 (sqrt-y 9 の途中)")
                           ":")
                       (:pre "  [global]
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
            (- (square g) x) → x も E1 で見つかる")))
    (make-cell :id :letrec-star :kind :prose
               :body '(:div
                       (:p (:strong "SICP 流の letrec* 解釈")
                           ": 内部 "
                           (:code "define")
                           " は連続した "
                           (:code "let*")
                           " のように扱われ、各 "
                           (:code "define")
                           " は前の "
                           (:code "define")
                           " の名前を見ることができます (WardLisp も同じ振る舞い)。")
                       (:p "つまり後で定義された関数同士は互いを参照できる ─ "
                           (:code "iter")
                           " の中から "
                           (:code "improve")
                           " と "
                           (:code "good?")
                           " を呼び出せるのはこのため。")))
    (make-cell :id :compute-eval :kind :code-eval
               :body "(define (compute x)
  (define a (+ x 1))
  (define b (* a 2))
  (define c (- b 3))
  c)
(compute 5)")
    (make-cell :id :compute-explanation :kind :prose
               :body '(:div
                       (:p "上のセルでは:")
                       (:ul
                        (:li (:code "a")
                             " = (+ 5 1) = 6")
                        (:li (:code "b")
                             " = (* a 2) = 12 ─ b の定義時に a が見える")
                        (:li (:code "c")
                             " = (- b 3) = 9 ─ c の定義時に b が見える"))
                       (:p "順番に評価されて、各 "
                           (:code "define")
                           " は前のものを参照できる。"
                           "もし「先に c の定義が来る」ように書き換えたら、"
                           "b がまだ未束縛なのでエラーになります。")))
    (make-cell :id :ex-internal-fact :kind :code-exercise
               :description
               "factorial-y を内部定義のみで階乗を計算するように書いてください。
 iter などの内部関数は factorial-y の中にだけ見える形で。
最終式として (factorial-y 6) を残してください。期待値は 720 です。
スケルトン:
  (define (factorial-y n)
    (define (iter k acc)
      (if (> k n) acc (iter (+ k 1) (* acc k))))
    (iter 1 1))
  (factorial-y 6)"
               :body "; (define (factorial-y n)
;   (define (iter k acc) ...)
;   (iter 1 1))
; 最後に (factorial-y 6)
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "720"
                                     :description "factorial-y で 6! = 720"))))))
