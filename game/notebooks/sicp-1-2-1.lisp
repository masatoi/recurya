;;;; game/notebooks/sicp-1-2-1.lisp --- SICP 1.2.1 Linear Recursion and Iteration.

(defpackage #:recurya/game/notebooks/sicp-1-2-1
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-1-2-1-notebook))

(in-package #:recurya/game/notebooks/sicp-1-2-1)

(defun make-sicp-1-2-1-notebook ()
  "SICP 1.2.1 - Linear Recursion and Iteration."
  (make-notebook
   :id :sicp-1-2-1
   :chapter "1.2.1"
   :title "線形再帰と反復"
   :summary "同じ階乗を再帰プロセスと反復プロセスの 2 通りで書き分け、手続きの形と計算の形が別物であることを学ぶ"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p (:code "(factorial n)") " は "
                           (:code "n × (n-1) × … × 1")
                           " です。再帰的に書くと:")
                       (:ul
                        (:li (:code "(factorial n) = n × (factorial (- n 1))"))
                        (:li (:code "(factorial 1) = 1")))))
    (make-cell :id :recursive-fact :kind :code-eval
               :body "(define (factorial n)
  (if (= n 1)
      1
      (* n (factorial (- n 1)))))
(factorial 6)")
    (make-cell :id :recursive-prose :kind :prose
               :body '(:div
                       (:p "これは " (:strong "線形再帰プロセス") " です。"
                           (:code "(factorial 6)")
                           " を計算するには "
                           (:code "(* 6 (factorial 5))")
                           " の結果を待つ必要があり、未完了の積の連鎖が"
                           "スタックに残り続けます。")
                       (:p "計算過程はこうなります:")
                       (:pre
                        "(factorial 6)
(* 6 (factorial 5))
(* 6 (* 5 (factorial 4)))
(* 6 (* 5 (* 4 (factorial 3))))
...
(* 6 (* 5 (* 4 (* 3 (* 2 1)))))
720")
                       (:p "プロセスの形状は線形 — 必要な記憶量も計算ステップ数も "
                           (:code "n") " に比例します。")))
    (make-cell :id :iterative-prose :kind :prose
               :body '(:div
                       (:p "同じ階乗を " (:strong "反復プロセス") " で書くこともできます。"
                           "アキュムレータ " (:code "product")
                           " と現在の数 " (:code "counter")
                           " を引数として持ち回し、"
                           (:code "counter") " が " (:code "max")
                           " を超えたら結果を返します。")))
    (make-cell :id :iterative-fact :kind :code-eval
               :body "(define (fact-iter product counter max)
  (if (> counter max)
      product
      (fact-iter (* counter product) (+ counter 1) max)))
(define (factorial-it n) (fact-iter 1 1 n))
(factorial-it 6)")
    (make-cell :id :tail-call-prose :kind :prose
               :body '(:div
                       (:p "両者とも " (:code "define") " の形は再帰呼び出しですが、"
                           "反復版は " (:strong "末尾呼び出し") " になっており "
                           "スタックに未完了の式を残しません。"
                           "WardLisp は末尾呼び出しを最適化するので、"
                           "大きな " (:code "n") " でもスタックを消費しません。")
                       (:p "重要なのは: "
                           (:strong "「手続きが再帰的」と「プロセスが再帰的」は別の話")
                           " ということです。"
                           (:code "fact-iter") " は手続き定義としては再帰ですが、"
                           "走らせると反復プロセスになります。")))
    (make-cell :id :ex-sum :kind :code-exercise
               :description
               "1 から n までの和 (sum-up-to n) を反復プロセスで書いてください。
アキュムレータと現在値を持ち回す形にし、(sum-up-to 10) を最終式に
残してください。"
               :body "; (define (sum-iter total cur max) ...)
; (define (sum-up-to n) (sum-iter 0 1 n))
; 最後に (sum-up-to 10)
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "55"
                                     :description "1+2+...+10 = 55")))
    (make-cell :id :ex-pow :kind :code-exercise
               :description
               "(power b n) = b^n を線形再帰プロセスで書いてください。
n が 0 のとき 1 を返し、そうでなければ b と (power b (- n 1)) の積を返します。
(power 2 10) を最終式に残してください。"
               :body "; (define (power b n) ...)
; 最後に (power 2 10)
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "1024"
                                     :description "2^10 = 1024"))))))
