===prose===
**SICP 3.5.5** は本章のまとめです。状態を扱う 2 つのパラダイムを比較します:

- **オブジェクトベース** (3.1〜3.4): 状態を持つオブジェクトが互いにメッセージを交換。**時間とアイデンティティ**が中心。
- **ストリームベース** (3.5): 状態の**履歴を不変な値の列**として表現。**時間は明示的なインデックス**になる。

両者は**双対 (dual)**の関係にあると SICP は論じます。

===prose===
**モンテカルロ π 推定の対比** (SICP 原典の例):

```
;; オブジェクトベース(set! を使う)
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
                   random-numbers))
```

ストリーム版では `random-numbers` は一度作られたら**変わらない**。`cesaro-stream` も同様。状態の変化は**ストリームの先頭がどこにあるか**(インデックス)で表現される。

===prose===
**WardLisp ミニデモ**: 銀行口座の取引履歴をストリームで表現。`account-stream` の各位置 i は、i 個の取引が起きた後の残高を表す。

取引は `(deposit . amt)` または `(withdraw . amt)` のペア。`apply-tx` で残高を更新し、`account-stream` で履歴ストリームを生成します。

===eval===
(define (stream-cons a thunk) (cons a thunk))
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
;; → (100 150 120 220 200): 初期 100、+50→150、-30→120、+100→220、-20→200

===prose===
**観察**

- 過去のすべての残高が**保持される** ― タイムトラベル(過去状態への参照)が自由。
- 取引の順序が**ストリームの順序**として明示的に表現される。
- 「現在の残高」は「ストリームの最新位置」を持つことに相当。

**比較**: SICP 原典の `set!` 版では、過去の残高は**消える**。状態を 1 つのオブジェクトに集約する代わりに、過去への参照を失います。

===prose===
**SICP の結論**: どちらのパラダイムも有用で、それぞれ得意な領域がある。

- **オブジェクトベース** ― GUI / シミュレーション / 実世界モデル化に自然。
- **ストリームベース** ― 信号処理 / バッチ計算 / イベントソーシングに自然。

**現代的な視点**: Clojure / Haskell / Erlang のような関数型言語は、ストリーム/不変性を中心に置きつつ、必要な箇所で **STM** や **actor** を組み合わせて状態を扱います。SICP の対比は今も有効です。第3章はここで終わり、第4章では言語そのものを評価器として実装する旅が始まります。

===exercise: 上記 apply-tx / account-stream を使い、初期残高 50、取引 ((deposit . 20) (withdraw . 10) (deposit . 5)) のときの残高ストリームの先頭 4 項を返してください。 50 → +20 で 70 → -10 で 60 → +5 で 65。 最終式: (stream-take (account-stream 50 (list (cons 'deposit 20) (cons 'withdraw 10) (cons 'deposit 5))) 4)===
(define (stream-cons a thunk) (cons a thunk))
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
(stream-take (account-stream 50 (list (cons 'deposit 20) (cons 'withdraw 10) (cons 'deposit 5))) 4)

===expect: 残高履歴 先頭 4 項===
(50 70 60 65)

===solution: 上記 apply-tx / account-stream を使い、初期残高 50、取引 ((deposit . 20) (withdraw . 10) (deposit . 5)) のときの残高ストリームの先頭 4 項を返してください。 50 → +20 で 70 → -10 で 60 → +5 で 65。 最終式: (stream-take (account-stream 50 (list (cons 'deposit 20) (cons 'withdraw 10) (cons 'deposit 5))) 4)===
(define (stream-cons a thunk) (cons a thunk))
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
(stream-take (account-stream 50 (list (cons 'deposit 20) (cons 'withdraw 10) (cons 'deposit 5))) 4)
