;;;; game/notebooks/sicp-1-2-6.lisp --- SICP 1.2.6 Testing for Primality.

(defpackage #:recurya/game/notebooks/sicp-1-2-6
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-1-2-6-notebook))

(in-package #:recurya/game/notebooks/sicp-1-2-6)

(defun make-sicp-1-2-6-notebook ()
  "SICP 1.2.6 - Testing for Primality."
  (make-notebook
   :id :sicp-1-2-6
   :chapter "1.2.6"
   :title "素数判定"
   :summary "試し割り法で素数を判定し、Fermat テストの考え方も紹介する"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p "整数 " (:code "n")
                           " が素数かどうかを判定するもっとも素朴な方法は、"
                           (:strong "試し割り法") " です。"
                           (:code "2") " から順に "
                           (:code "√n") " 以下の整数で割り、"
                           "割り切れる数が見つかれば合成数、"
                           "見つからなければ素数だと結論します。")
                       (:p (:code "√n") " まで調べれば十分なのは、"
                           "もし " (:code "n = a * b") " で "
                           (:code "a ≤ b") " なら必ず " (:code "a ≤ √n")
                           " が成り立つからです。")))
    (make-cell :id :prime-def :kind :code-eval
               :body "(define (square x) (* x x))
(define (divides? a b) (= (mod b a) 0))
(define (find-divisor n test)
  (cond ((> (square test) n) n)
        ((divides? test n) test)
        (t (find-divisor n (+ test 1)))))
(define (smallest-divisor n) (find-divisor n 2))
(define (prime? n) (= (smallest-divisor n) n))
(list (prime? 7) (prime? 12) (smallest-divisor 199))")
    (make-cell :id :complexity :kind :prose
               :body '(:div
                       (:p (:code "smallest-divisor") " は最悪でも "
                           (:code "√n") " 回ループするので、"
                           "ステップ数は " (:strong "Θ(√n)") " です。")
                       (:p "実用速度の目安:")
                       (:ul
                        (:li (:code "(prime? 1009)") " — ほぼ瞬時")
                        (:li (:code "(prime? 1000003)") " — 実用範囲で動作")
                        (:li (:code "(prime? 10000000019)") " — 大きな素数になると重くなる"))))
    (make-cell :id :ward-note :kind :prose
               :body '(:div
                       (:p (:strong "WardLisp 注記") ": "
                           "SICP 原典の "
                           (:code "(remainder b a)") " は WardLisp では "
                           (:code "(mod b a)") " と書きます。"
                           "また " (:code "cond") " の "
                           (:code "else") " 節は WardLisp では "
                           (:code "(t ...)") " と書きます。")))
    (make-cell :id :fermat-prose :kind :prose
               :body '(:div
                       (:p (:strong "Fermat テスト (概念紹介)") ": "
                           "フェルマーの小定理は "
                           (:code "n が素数なら、任意の a (1 ≤ a < n) について a^n ≡ a (mod n)")
                           " と主張します。")
                       (:p "この性質を使い、ランダムに " (:code "a")
                           " を選んで合同式を検査することで、"
                           (:strong "確率的に") " 素数判定する手法が "
                           "Fermat テストです。Θ(log n) で動きます。")
                       (:p (:strong "WardLisp 注記") ": "
                           "実装には乱数生成 (" (:code "random") ") が必要ですが、"
                           "WardLisp には " (:code "random") " 関数が"
                           (:strong "存在しない") " ため、"
                           "本ノートでは概念紹介に留め、"
                           (:strong "決定的な試し割り法のみ")
                           " を実装します。")))
    (make-cell :id :ex-prime-1009 :kind :code-exercise
               :description
               "試し割り法で (prime? 1009) の値を求めてください。
square / divides? / find-divisor / smallest-divisor / prime? を順に定義し、
最終式として (prime? 1009) を残します。
答え: t (1009 は素数)"
               :body "; (define (square x) ...)
; (define (divides? a b) ...)
; (define (find-divisor n test) ...)
; (define (smallest-divisor n) ...)
; (define (prime? n) ...)
; 最後に (prime? 1009)
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "t"
                                     :description "1009 は素数")))
    (make-cell :id :ex-next-prime :kind :code-exercise
               :description
               "n 以上の最小の素数を返す (next-prime n) を書いてください。
prime? を再利用し、n が素数ならそのまま、そうでなければ (next-prime (+ n 1)) を呼びます。
最終式として (next-prime 100) を残します。
答え: 101"
               :body "; (define (square x) ...)
; (define (divides? a b) ...)
; (define (find-divisor n test) ...)
; (define (smallest-divisor n) ...)
; (define (prime? n) ...)
; (define (next-prime n) ...)
; 最後に (next-prime 100)
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "101"
                                     :description "100 以上の最小の素数は 101"))))))
