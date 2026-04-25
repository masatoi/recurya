;;;; game/notebooks/sicp-1-2-3.lisp --- SICP 1.2.3 Orders of Growth.

(defpackage #:recurya/game/notebooks/sicp-1-2-3
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-1-2-3-notebook))

(in-package #:recurya/game/notebooks/sicp-1-2-3)

(defun make-sicp-1-2-3-notebook ()
  "SICP 1.2.3 - Orders of Growth."
  (make-notebook
   :id :sicp-1-2-3
   :chapter "1.2.3"
   :title "増加オーダ"
   :summary "Θ 記法でアルゴリズムの計算量を直観的に分類し、これまでの例を整理する"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p "アルゴリズムの " (:strong "増加オーダ")
                           " とは、入力サイズ " (:code "n")
                           " が大きくなったときに必要な"
                           " 計算リソース (時間や空間) がどう増えるかを表したものです。")
                       (:p "記号 " (:code "Θ(f(n))") " は "
                           "「リソース消費がだいたい " (:code "f(n)")
                           " に比例する」ことを意味します。"
                           "細かな定数倍は無視し、"
                           "「" (:code "n") " が 2 倍になったら時間も 2 倍になるか?"
                           "それとも 4 倍? 全然増えない?」 という"
                           "オーダだけを問題にします。")))
    (make-cell :id :common-orders :kind :prose
               :body '(:div
                       (:p "代表的なオーダを大きさの順に並べると:")
                       (:ul
                        (:li (:code "Θ(1)") " — 入力に依らない (定数時間)")
                        (:li (:code "Θ(log n)") " — 入力が倍になっても 1 ステップ増えるだけ")
                        (:li (:code "Θ(n)") " — 入力に比例")
                        (:li (:code "Θ(n²)") " — 入力が倍になると 4 倍に")
                        (:li (:code "Θ(2^n)") " — 入力が 1 増えるだけで倍に膨らむ"))
                       (:p "右に行くほど急速に大きくなります。"
                           (:code "Θ(2^n)") " は実用的には "
                           (:strong "ほとんど計算不能") " とみなせます。")))
    (make-cell :id :classify :kind :prose
               :body '(:div
                       (:p "これまでに登場した手続きを分類してみましょう:")
                       (:ul
                        (:li (:strong "1.2.1 線形再帰の factorial") ": "
                             "時間 " (:code "Θ(n)") "、空間 " (:code "Θ(n)")
                             " (積の連鎖がスタックに積まれるので)")
                        (:li (:strong "1.2.1 反復の factorial-it") ": "
                             "時間 " (:code "Θ(n)") "、空間 " (:code "Θ(1)")
                             " (アキュムレータだけ持っていればよい)")
                        (:li (:strong "1.2.2 木再帰の fib") ": "
                             "時間 " (:code "Θ(2^n)") "、空間 " (:code "Θ(n)")
                             " (深さは線形だが計算量は指数)")
                        (:li (:strong "1.2.2 反復の fib-fast") ": "
                             "時間 " (:code "Θ(n)") "、空間 " (:code "Θ(1)")))
                       (:p "同じ問題でも、実装次第で時間オーダが "
                           (:code "Θ(n)") " と " (:code "Θ(2^n)")
                           " ほどの差が出ることに注意してください。")))
    (make-cell :id :log-prose :kind :prose
               :body '(:div
                       (:p "次節で見る " (:code "fast-expt") " (高速累乗) は "
                           (:strong "時間 Θ(log n)") " になります。"
                           "これは入力 " (:code "n") " が倍に増えても "
                           "計算ステップが 1 つしか増えない、という非常に良いオーダです。")
                       (:p "「ステップ数を半減できる」操作 (典型的にはバイナリ分割) "
                           "が見つかると " (:code "Θ(log n)") " に到達できます。")))
    (make-cell :id :linear-iter-demo :kind :code-eval
               :body "(define (fact-iter product counter max)
  (if (> counter max)
      product
      (fact-iter (* counter product) (+ counter 1) max)))
(define (factorial-it n) (fact-iter 1 1 n))
(factorial-it 20)")
    (make-cell :id :doubling-prose :kind :prose
               :body '(:div
                       (:p "オーダを実感する古典的な方法は、"
                           (:strong "入力サイズを 2 倍にして") " 必要時間が"
                           " 2 倍 (線形) なのか、4 倍 (二次) なのか、"
                           " 倍々に膨れる (指数) のかを観察することです。")
                       (:p "次の演習では、線形再帰でも反復でも書ける手続きを書いて、"
                           "末尾呼び出しの動きを確認しましょう。")))
    (make-cell :id :ex-classify :kind :code-exercise
               :description
               "末尾再帰で書かれた count-down を完成させてください。
n が 0 になるまで自分自身を呼び続け、最終的に 0 を返します。
これは時間 Θ(n)、空間 Θ(1) の典型例です。
最終式として (count-down 100) を残してください。"
               :body "; (define (count-down n)
;   (if (= n 0) 0 (count-down (- n 1))))
; 最後に (count-down 100)
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "0"
                                     :description "末尾再帰で 100 から 0 まで")))
    (make-cell :id :ex-double :kind :code-exercise
               :description
               "1 + 2 + 4 + ... + 2^n を求める (power-of-2-sum n) を書いてください。
2 の累乗を計算する補助手続きと、和を貯めるアキュムレータを使います。
最終式として (power-of-2-sum 5) を残してください。
答え: 1 + 2 + 4 + 8 + 16 + 32 = 63"
               :body "; (define (power b e) ...)
; (define (power-of-2-sum n) ...)
; 最後に (power-of-2-sum 5)
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "63"
                                     :description "1+2+4+8+16+32 = 63"))))))
