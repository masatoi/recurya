===prose===
**SICP 3.5.1** はストリーム(遅延リスト)を導入します。原典では `(cons-stream a b)` という特殊形式が言語に組み込まれており、 `b` の評価を遅延します。

```
`;; SICP 原典 (WardLisp では動かない)
(define s (cons-stream 1 (cons-stream 2 (cons-stream 3 the-empty-stream))))`
```

WardLisp には `cons-stream` も `delay` もないので、 **明示的に lambda thunk** を書きます:

```
`(define s (cons 1 (lambda () (cons 2 (lambda () (cons 3 (lambda () nil)))))))`
```

`cdr` が thunk になっており、`((cdr s))` で初めて次の要素が計算される。これが**遅延評価**の核心です。

===eval===
(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-null? s) (null? s))
(define the-empty-stream nil)
(define s (stream-cons 1 (lambda () (stream-cons 2 (lambda () (stream-cons 3 (lambda () the-empty-stream)))))))
(list (stream-car s) (stream-car (stream-cdr s)) (stream-car (stream-cdr (stream-cdr s))))
;; → (1 2 3)

===prose===
**重要な点**:

- `s` を作る時点では `2` も `3` も **まだ評価されていない**(thunk の中)
- `stream-cdr s` を呼んで初めて thunk が実行され、次の要素が計算される
- これが**遅延評価**(lazy evaluation)の本質

===prose===
**有限ストリームを構築するヘルパ**:

```
`;; リストからストリームを作る
(define (list->stream xs)
  (if (null? xs)
      the-empty-stream
      (stream-cons (car xs) (lambda () (list->stream (cdr xs))))))`
```

`stream-take`(先頭 n 要素のリスト)と `stream-ref`(n 番目の要素)もよく使います。

===eval===
(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-null? s) (null? s))
(define the-empty-stream nil)
(define (list->stream xs)
  (if (null? xs)
      the-empty-stream
      (stream-cons (car xs) (lambda () (list->stream (cdr xs))))))
(define (stream-take s n)
  (if (or (= n 0) (stream-null? s))
      nil
      (cons (stream-car s) (stream-take (stream-cdr s) (- n 1)))))
(define (stream-ref s n)
  (if (= n 0) (stream-car s) (stream-ref (stream-cdr s) (- n 1))))
(define s (list->stream (list 10 20 30 40 50)))
(list (stream-take s 3) (stream-ref s 2))
;; → ((10 20 30) 30)

===prose===
**遅延評価のメリット**: 必要な部分だけ計算するので、**無限ストリーム**も扱えます(次節 3.5.2)。リストでは末尾まで全要素を保持しないと作れませんが、ストリームなら `stream-take 5` などで先頭だけ取り出すことができます。

===exercise: ストリームの先頭 n 個の合計を返す手続き (stream-sum-take s n) を書いてください。 stream-cons / stream-car / stream-cdr / stream-null? / the-empty-stream / list->stream を上で定義しておきます。 最終式: (stream-sum-take (list->stream (list 1 2 3 4 5)) 4) 1+2+3+4 = 10 を期待します。===
(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-null? s) (null? s))
(define the-empty-stream nil)
(define (list->stream xs)
  (if (null? xs)
      the-empty-stream
      (stream-cons (car xs) (lambda () (list->stream (cdr xs))))))
;; ここに (stream-sum-take s n) を書いてください
(stream-sum-take (list->stream (list 1 2 3 4 5)) 4)

===expect: 1+2+3+4 = 10===
10

===solution: ストリームの先頭 n 個の合計を返す手続き (stream-sum-take s n) を書いてください。 stream-cons / stream-car / stream-cdr / stream-null? / the-empty-stream / list->stream を上で定義しておきます。 最終式: (stream-sum-take (list->stream (list 1 2 3 4 5)) 4) 1+2+3+4 = 10 を期待します。===
(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-null? s) (null? s))
(define the-empty-stream nil)
(define (list->stream xs)
  (if (null? xs)
      the-empty-stream
      (stream-cons (car xs) (lambda () (list->stream (cdr xs))))))
(define (stream-sum-take s n)
  (if (or (= n 0) (stream-null? s))
      0
      (+ (stream-car s) (stream-sum-take (stream-cdr s) (- n 1)))))
(stream-sum-take (list->stream (list 1 2 3 4 5)) 4)

===exercise: ストリーム (a b c d e) の 3 番目の要素 (0-origin で index=2) を取得してください。 stream-ref を使えば 1 行で書けます。最終式: (stream-ref (list->stream (list 'a 'b 'c 'd 'e)) 2)===
(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-null? s) (null? s))
(define the-empty-stream nil)
(define (list->stream xs)
  (if (null? xs)
      the-empty-stream
      (stream-cons (car xs) (lambda () (list->stream (cdr xs))))))
(define (stream-ref s n)
  (if (= n 0) (stream-car s) (stream-ref (stream-cdr s) (- n 1))))
;; 最終式を書いてください
(stream-ref (list->stream (list 'a 'b 'c 'd 'e)) 2)

===expect: 3 番目の要素は c===
c

===solution: ストリーム (a b c d e) の 3 番目の要素 (0-origin で index=2) を取得してください。 stream-ref を使えば 1 行で書けます。最終式: (stream-ref (list->stream (list 'a 'b 'c 'd 'e)) 2)===
(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-null? s) (null? s))
(define the-empty-stream nil)
(define (list->stream xs)
  (if (null? xs)
      the-empty-stream
      (stream-cons (car xs) (lambda () (list->stream (cdr xs))))))
(define (stream-ref s n)
  (if (= n 0) (stream-car s) (stream-ref (stream-cdr s) (- n 1))))
(stream-ref (list->stream (list 'a 'b 'c 'd 'e)) 2)
