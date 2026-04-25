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
   :summary "試し割り法で素数を判定し、Fermat テストを WardLisp の random で実装する"
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
                       (:p (:strong "Fermat テスト") ": "
                           "フェルマーの小定理は "
                           (:code "n が素数なら、任意の a (1 ≤ a < n) について a^n ≡ a (mod n)")
                           " と主張します。")
                       (:p "この性質を使い、ランダムに " (:code "a")
                           " を選んで合同式を検査することで、"
                           (:strong "確率的に") " 素数判定する手法が "
                           "Fermat テストです。1 回の試行は "
                           (:code "Θ(log n)") " で動きます。")
                       (:p (:strong "WardLisp 注記") ": "
                           "Fermat テストには乱数が必要ですが、"
                           "WardLisp v0.2.0 から " (:code "(random n)")
                           " が使えるようになりました。"
                           (:code "0") " 以上 " (:code "n")
                           " 未満の整数を返します。")))
    (make-cell :id :fermat-impl :kind :code-eval
               :body "(define (square x) (* x x))
(define (even? n) (= (mod n 2) 0))
(define (expmod base exp m)
  (cond ((= exp 0) 1)
        ((even? exp) (mod (square (expmod base (/ exp 2) m)) m))
        (t (mod (* base (expmod base (- exp 1) m)) m))))
(define (fermat-test n)
  (define a (+ 1 (random (- n 1))))
  (= (expmod a n n) a))
(define (fast-prime? n times)
  (cond ((= times 0) t)
        ((fermat-test n) (fast-prime? n (- times 1)))
        (t nil)))
;; 1009 は素数。5 回試行すれば事実上常に t になる
(list (fast-prime? 1009 5) (fast-prime? 100 5))")
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
                                     :description "100 以上の最小の素数は 101")))
    (make-cell :id :ex-fermat :kind :code-exercise
               :description
               "Fermat テストで素数判定する (fast-prime? n times) を書いてください。
square / even? / expmod / fermat-test / fast-prime? を上記 fermat-impl と同じに定義し、
最終式として (fast-prime? 1009 5) を残します。
答え: t (1009 は素数なので Fermat テストは決定的に t を返す)"
               :body "; (define (square x) ...)
; (define (even? n) ...)
; (define (expmod base exp m) ...)
; (define (fermat-test n) ...)
; (define (fast-prime? n times) ...)
; 最後に (fast-prime? 1009 5)
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "t"
                                     :description "1009 を Fermat テストで判定"))))))
