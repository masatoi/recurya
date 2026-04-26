;;;; game/notebooks/sicp-3-1-2.lisp --- SICP 3.1.2 Benefits of assignment (functional alternatives).

(defpackage #:recurya/game/notebooks/sicp-3-1-2
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-3-1-2-notebook))

(in-package #:recurya/game/notebooks/sicp-3-1-2)

(defun make-sicp-3-1-2-notebook ()
  "SICP 3.1.2 - Benefits of assignment, with functional alternatives in WardLisp."
  (make-notebook
   :id :sicp-3-1-2
   :chapter "3.1.2"
   :title "代入導入のメリット (関数型での再構成)"
   :summary "SICP の Monte Carlo 法は set! で乱数生成器の状態を隠蔽する。WardLisp の組み込み (random) を使う方法と、seed を明示的に持ち回る LCG 方式の 2 通りで再構成する"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p (:strong "SICP 3.1.2")
                           " は "
                           (:code "set!")
                           " で乱数生成器の状態を隠蔽する例で、Monte Carlo 法による π の推定を扱います。原典は次のように書かれます:")
                       (:pre "(define rand
  (let ((x random-init))
    (lambda ()
      (set! x (rand-update x))   ;; ← 状態の更新
      x)))")
                       (:p (:code "(rand)")
                           " を呼ぶたびに内部の "
                           (:code "x")
                           " が "
                           (:code "set!")
                           " で進められ、新しい値が返ります。これにより呼び出し側は "
                           (:strong "状態を意識せず")
                           " 「次の乱数」を取れる、という設計が SICP 3.1.2 のポイントです。")
                       (:p "WardLisp v0.2.0 から "
                           (:code "(random n)")
                           " が組み込みで使えます。SBCL のグローバル PRNG 状態を共有して進めるため、外見上は SICP の "
                           (:code "(rand)")
                           " と同じく「呼ぶたびに新しい値が返る」形です。")))
    (make-cell :id :random-builtin :kind :code-eval
               :body "(list (random 100) (random 100) (random 100) (random 100))")
    (make-cell :id :monte-carlo-prose :kind :prose
               :body '(:div
                       (:p (:strong "Monte Carlo 法による π の推定")
                           ": "
                           "[0, n) 区間の整数 (x, y) を 2 つ取り、原点からの距離が n 未満なら円内とカウント。"
                           (:code "(円内 / 全試行) × 4 ≒ π")
                           "。"
                           "n を大きくとるほど整数演算でも精度が上がります。")))
    (make-cell :id :monte-carlo-code :kind :code-eval
               :body "(define (square x) (* x x))
(define (in-circle?-int n)
  ;; (random n) を 2 回取り x^2 + y^2 < n^2 で円内判定
  (let ((x (random n)) (y (random n)))
    (< (+ (square x) (square y)) (square n))))
(define (estimate-pi trials n)
  (define (iter k count)
    (cond ((= k 0) (/ (* 4 count) trials))
          ((in-circle?-int n) (iter (- k 1) (+ count 1)))
          (t (iter (- k 1) count))))
  (iter trials 0))
;; 100 試行 / n=1000 で粗い近似 (実行ごとに値は変動)
(estimate-pi 100 1000)")
    (make-cell :id :state-hiding :kind :prose
               :body '(:div
                       (:p (:strong "WardLisp 注記")
                           ": SICP 原典は "
                           (:code "set!")
                           " で乱数の状態を隠蔽し "
                           (:code "(rand)")
                           " を呼ぶたびに新しい値が出る形にします。WardLisp の "
                           (:code "(random n)")
                           " は内部で SBCL のグローバル PRNG を進めるので、外見上は同じ振る舞いです。"
                           "違いは「状態を隠蔽する仕組み」が言語の組み込みかユーザコードかです。")
                       (:p "完全に純関数で書きたい場合は seed を明示的に持ち回せます。"
                           "下のセルでは "
                           (:strong "線形合同法 (LCG)")
                           " を自作して、seed を引数として明示的にスレッドする例を示します。")))
    (make-cell :id :lcg-code :kind :code-eval
               :body "(define (lcg seed) (mod (+ (* 1103515245 seed) 12345) 2147483648))
(define (random-1 n seed) (mod seed n))
(define s0 42)
(define s1 (lcg s0))
(define s2 (lcg s1))
(define s3 (lcg s2))
(list (random-1 100 s1) (random-1 100 s2) (random-1 100 s3))")
    (make-cell :id :compare-approaches :kind :prose
               :body '(:div
                       (:p (:strong "アプローチの比較")
                           ":")
                       (:ul
                        (:li (:strong "SICP 原典 (set! + 内部状態)")
                             ": 呼び出し側は seed を意識しない。状態は隠蔽される。同じ式 "
                             (:code "(rand)")
                             " が呼ぶたびに違う値を返す ─ "
                             (:strong "参照透過性は失われる")
                             "。")
                        (:li (:strong "WardLisp 組み込み (random n)")
                             ": 同じく状態は隠蔽される (SBCL の PRNG が裏にいる)。表面の API は SICP 原典に近い。")
                        (:li (:strong "LCG + 明示的 seed-passing")
                             ": seed を引数として明示的に渡す。同じ seed なら "
                             (:strong "決定的に同じ結果")
                             " になる ─ 参照透過性が保たれる。テストの再現性、並列実行の安全性、デバッグの容易さが得られる。"))))
    (make-cell :id :ex-lcg-third :kind :code-exercise
               :description
               "線形合同法 (LCG) で seed を 3 回進めた値を返します。
  (define (lcg seed) (mod (+ (* 1103515245 seed) 12345) 2147483648))
を定義し、最終式として
  (lcg (lcg (lcg 42)))
を残してください。決定的なので何度実行しても同じ値になります。
答え: 1000676753 (SBCL での具体値; 任意の言語で同じ式を評価すれば同値)。"
               :body "; (define (lcg seed) (mod (+ (* 1103515245 seed) 12345) 2147483648))
; 最後に (lcg (lcg (lcg 42)))
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "1000676753"
                                     :description "LCG(42) を 3 回適用した決定的な値"))))))
