;;;; game/notebooks/sicp-3-5-5.lisp --- SICP 3.5.5 Modularity of Functional Programs and Modularity of Objects.

(defpackage #:recurya/game/notebooks/sicp-3-5-5
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-3-5-5-notebook))

(in-package #:recurya/game/notebooks/sicp-3-5-5)

(defun make-sicp-3-5-5-notebook ()
  "SICP 3.5.5 - Modularity of Functional Programs and Modularity of Objects."
  (make-notebook
   :id :sicp-3-5-5
   :chapter "3.5.5"
   :title "関数型プログラムのモジュール性 vs オブジェクトのモジュール性"
   :summary "SICP 第3章の最終節。状態を扱う 2 つのパラダイム ― オブジェクトベース(set! と隠蔽状態)とストリームベース(履歴を不変な値の列で表す)― を対比する。取引履歴を残高ストリームとして表現し、過去状態への自由な参照を獲得できることを見る。"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p (:strong "SICP 3.5.5")
                           " は本章のまとめです。状態を扱う 2 つのパラダイムを比較します:")
                       (:ul
                        (:li (:strong "オブジェクトベース")
                             " (3.1〜3.4): 状態を持つオブジェクトが互いにメッセージを交換。"
                             (:strong "時間とアイデンティティ")
                             "が中心。")
                        (:li (:strong "ストリームベース")
                             " (3.5): 状態の"
                             (:strong "履歴を不変な値の列")
                             "として表現。"
                             (:strong "時間は明示的なインデックス")
                             "になる。"))
                       (:p "両者は"
                           (:strong "双対 (dual)")
                           "の関係にあると SICP は論じます。")))
    (make-cell :id :monte-carlo-prose :kind :prose
               :body '(:div
                       (:p (:strong "モンテカルロ π 推定の対比")
                           " (SICP 原典の例):")
                       (:pre
                        ";; オブジェクトベース(set! を使う)
(define rand
  (let ((x random-init))
    (lambda ()
      (set! x (rand-update x))
      x)))
(define (cesaro-test) (= 1 (gcd (rand) (rand))))

;; ストリームベース(状態は不変なストリーム)
(define random-numbers (stream-of (random 100000)))
(define cesaro-stream
  (map-pair-stream (lambda (a b) (= 1 (gcd a b)))
                   random-numbers))")
                       (:p "ストリーム版では "
                           (:code "random-numbers")
                           " は一度作られたら"
                           (:strong "変わらない")
                           "。"
                           (:code "cesaro-stream")
                           " も同様。"
                           "状態の変化は"
                           (:strong "ストリームの先頭がどこにあるか")
                           "(インデックス)で表現される。")))
    (make-cell :id :tx-prose :kind :prose
               :body '(:div
                       (:p (:strong "WardLisp ミニデモ")
                           ": 銀行口座の取引履歴をストリームで表現。"
                           (:code "account-stream")
                           " の各位置 i は、i 個の取引が起きた後の残高を表す。")
                       (:p "取引は "
                           (:code "(deposit . amt)")
                           " または "
                           (:code "(withdraw . amt)")
                           " のペア。"
                           (:code "apply-tx")
                           " で残高を更新し、"
                           (:code "account-stream")
                           " で履歴ストリームを生成します。")))
    (make-cell :id :tx-eval :kind :code-eval
               :body "(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-take s n)
  (if (= n 0) nil (cons (stream-car s) (stream-take (stream-cdr s) (- n 1)))))
;; 取引: (deposit . amt) または (withdraw . amt)
(define transactions
  (list (cons 'deposit 50)
        (cons 'withdraw 30)
        (cons 'deposit 100)
        (cons 'withdraw 20)))
;; account-stream: 取引のリストから残高ストリームを生成
(define (apply-tx bal tx)
  (let ((kind (car tx)) (amt (cdr tx)))
    (cond ((eq? kind 'deposit) (+ bal amt))
          ((eq? kind 'withdraw) (- bal amt))
          (t bal))))
(define (account-stream bal txs)
  (stream-cons bal
    (lambda ()
      (if (null? txs) nil (account-stream (apply-tx bal (car txs)) (cdr txs))))))
(stream-take (account-stream 100 transactions) 5)
;; → (100 150 120 220 200): 初期 100、+50→150、-30→120、+100→220、-20→200")
    (make-cell :id :observe :kind :prose
               :body '(:div
                       (:p (:strong "観察"))
                       (:ul
                        (:li "過去のすべての残高が"
                             (:strong "保持される")
                             " ― タイムトラベル(過去状態への参照)が自由。")
                        (:li "取引の順序が"
                             (:strong "ストリームの順序")
                             "として明示的に表現される。")
                        (:li "「現在の残高」は「ストリームの最新位置」を持つことに相当。"))
                       (:p (:strong "比較")
                           ": SICP 原典の "
                           (:code "set!")
                           " 版では、過去の残高は"
                           (:strong "消える")
                           "。状態を 1 つのオブジェクトに集約する代わりに、過去への参照を失います。")))
    (make-cell :id :conclusion :kind :prose
               :body '(:div
                       (:p (:strong "SICP の結論")
                           ": どちらのパラダイムも有用で、それぞれ得意な領域がある。")
                       (:ul
                        (:li (:strong "オブジェクトベース")
                             " ― GUI / シミュレーション / 実世界モデル化に自然。")
                        (:li (:strong "ストリームベース")
                             " ― 信号処理 / バッチ計算 / イベントソーシングに自然。"))
                       (:p (:strong "現代的な視点")
                           ": Clojure / Haskell / Erlang のような関数型言語は、"
                           "ストリーム/不変性を中心に置きつつ、必要な箇所で "
                           (:strong "STM")
                           " や "
                           (:strong "actor")
                           " を組み合わせて状態を扱います。"
                           "SICP の対比は今も有効です。第3章はここで終わり、第4章では言語そのものを評価器として実装する旅が始まります。")))
    (make-cell :id :ex-account-history :kind :code-exercise
               :description
               "上記 apply-tx / account-stream を使い、初期残高 50、取引 ((deposit . 20) (withdraw . 10) (deposit . 5)) のときの残高ストリームの先頭 4 項を返してください。
50 → +20 で 70 → -10 で 60 → +5 で 65。
最終式: (stream-take (account-stream 50 (list (cons 'deposit 20) (cons 'withdraw 10) (cons 'deposit 5))) 4)"
               :body "(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-take s n)
  (if (= n 0) nil (cons (stream-car s) (stream-take (stream-cdr s) (- n 1)))))
(define (apply-tx bal tx)
  (let ((kind (car tx)) (amt (cdr tx)))
    (cond ((eq? kind 'deposit) (+ bal amt))
          ((eq? kind 'withdraw) (- bal amt))
          (t bal))))
(define (account-stream bal txs)
  (stream-cons bal
    (lambda ()
      (if (null? txs) nil (account-stream (apply-tx bal (car txs)) (cdr txs))))))
;; 最終式を書いてください
(stream-take (account-stream 50 (list (cons 'deposit 20) (cons 'withdraw 10) (cons 'deposit 5))) 4)"
               :test-cases
               (list (make-test-case
                      :input ""
                      :expected "(50 70 60 65)"
                      :description "残高履歴 先頭 4 項"))))))
