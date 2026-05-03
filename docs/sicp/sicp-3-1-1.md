===prose===
**SICP 3.1.1** は `set!` を使ってオブジェクトの局所状態を保持する例を扱います。原典の `make-account` はクロージャ内部の `balance` を直接書き換える形で書かれます (WardLisp では動かないため、概念紹介のみ):

```
(define (make-account balance)
  (define (withdraw amt)
    (if (>= balance amt)
        (begin (set! balance (- balance amt)) balance)
        'insufficient))
  (define (deposit amt)
    (set! balance (+ balance amt))
    balance)
  ...)
```

WardLisp には `set!` がないため、別のアプローチが要ります。本ノートでは **持続的データ (persistent data)** で再構成します。各操作は新しい account レコードを返し、過去の状態は破壊されません。

===eval===
(define (make-account balance) (cons 'account balance))
(define (account-balance acc) (cdr acc))
(define (withdraw acc amt)
  (if (>= (account-balance acc) amt)
      (make-account (- (account-balance acc) amt))
      acc))  ;; 残高不足なら据え置き
(define (deposit acc amt)
  (make-account (+ (account-balance acc) amt)))
(define a0 (make-account 100))
(define a1 (deposit a0 50))
(define a2 (withdraw a1 30))
(list (account-balance a0) (account-balance a1) (account-balance a2))

===prose===
**重要な観察**:

- `a0`、`a1`、`a2` は **それぞれ別の値** として共存します。SICP 原典の `set!` 版では「同じ口座が時間とともに変化していく」が、関数型版では「過去の状態が値として残る」。
- 呼び出し側は新しい値を受け取って差し替える必要があります。WardLisp は `set!` がないので、関数の引数として渡し続けるか、`define` し直すことで「現在の口座」を表現します。

===prose===
**両アプローチの比較**:

- **SICP 原典 (set! 版)**: 「カウンター」「銀行口座」のような **状態を持つオブジェクト** を簡潔に表現できます。同一性 (identity) を持つ実体として扱える。
- **関数型版 (持続的データ)**: 時間軸での同一性は失われる代わりに、過去の値を保持でき、参照透過性を保てます。並列処理やバージョン管理 (undo/redo) と相性が良い。

===exercise: 持続的な銀行口座を実装します。 (define (make-account balance) ...) (define (account-balance acc) ...) (define (withdraw acc amt) ...) ; 残高不足なら同じ acc を返す (define (deposit acc amt) ...) を定義し、初期残高 100 から deposit 50、withdraw 30、withdraw 200 (残高不足) を順に適用した 最終的な残高を返してください。最終式: (account-balance ((lambda (a) (withdraw (withdraw (deposit a 50) 30) 200)) (make-account 100))) 答え: 100 + 50 - 30 = 120 (最後の 200 は残高不足で据え置き)。===
; (define (make-account balance) ...)
; (define (account-balance acc) ...)
; (define (withdraw acc amt) ...)
; (define (deposit acc amt) ...)
; 最後に
;   (account-balance ((lambda (a) (withdraw (withdraw (deposit a 50) 30) 200))
;                     (make-account 100)))

===expect: 100 + 50 - 30 = 120 (200 は残高不足で無視)===
120

===solution: 持続的な銀行口座を実装します。 (define (make-account balance) ...) (define (account-balance acc) ...) (define (withdraw acc amt) ...) ; 残高不足なら同じ acc を返す (define (deposit acc amt) ...) を定義し、初期残高 100 から deposit 50、withdraw 30、withdraw 200 (残高不足) を順に適用した 最終的な残高を返してください。最終式: (account-balance ((lambda (a) (withdraw (withdraw (deposit a 50) 30) 200)) (make-account 100))) 答え: 100 + 50 - 30 = 120 (最後の 200 は残高不足で据え置き)。===
(define (make-account balance) (cons 'account balance))
(define (account-balance acc) (cdr acc))
(define (withdraw acc amt)
  (if (>= (account-balance acc) amt)
      (make-account (- (account-balance acc) amt))
      acc))
(define (deposit acc amt)
  (make-account (+ (account-balance acc) amt)))
(account-balance ((lambda (a) (withdraw (withdraw (deposit a 50) 30) 200)) (make-account 100)))

===exercise: 純関数的なカウンターを実装します。 (define (make-counter) ...) ; 新しいカウンター (define (counter-increment c) ...) ; +1 された新しいカウンター (define (counter-value c) ...) ; 現在値 を定義し、3 回 increment して値を返してください。最終式: (counter-value (counter-increment (counter-increment (counter-increment (make-counter)))))===
; (define (make-counter) ...)
; (define (counter-increment c) ...)
; (define (counter-value c) ...)
; 最後に
;   (counter-value (counter-increment (counter-increment (counter-increment (make-counter)))))

===expect: 3 回 increment して 3===
3

===solution: 純関数的なカウンターを実装します。 (define (make-counter) ...) ; 新しいカウンター (define (counter-increment c) ...) ; +1 された新しいカウンター (define (counter-value c) ...) ; 現在値 を定義し、3 回 increment して値を返してください。最終式: (counter-value (counter-increment (counter-increment (counter-increment (make-counter)))))===
(define (make-counter) (cons 'counter 0))
(define (counter-value c) (cdr c))
(define (counter-increment c) (cons 'counter (+ 1 (cdr c))))
(counter-value (counter-increment (counter-increment (counter-increment (make-counter)))))
