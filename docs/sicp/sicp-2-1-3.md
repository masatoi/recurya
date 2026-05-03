===prose===
ここまで `cons` / `car` / `cdr` は処理系が用意してくれる **プリミティブ** として使ってきました。ですが SICP 2.1.3 の中心的なメッセージは、

> **「ペア」というデータ構造は、実は手続きだけで完全に実装できる** ということです。

つまり、ペアの満たすべき **契約 (contract)** は

- `(car (cons a b))` は `a` を返す
- `(cdr (cons a b))` は `b` を返す

の 2 つだけで、これを満たす実装ならば ペアとして使えます。下のセルでは、`lambda` だけでこれを実現してみます。

===prose===
**アイデア**: `(my-cons a b)` は `a` と `b` を「閉じ込めた」 lambda を返す。外から「セレクタ (どちらを選ぶか)」を渡されたら、そのセレクタに `a` と `b` を引数として渡して呼ぶだけ。

`my-car` は「最初の引数を返すセレクタ」を、`my-cdr` は「二番目の引数を返すセレクタ」を渡してペアを呼ぶ、という設計です。

===eval===
(define (my-cons a b) (lambda (selector) (selector a b)))
(define (my-car p) (p (lambda (a b) a)))
(define (my-cdr p) (p (lambda (a b) b)))
(define p (my-cons 7 13))
(list (my-car p) (my-cdr p))

===prose===
**重要な観察**: `my-cons` が返す値は「データ」のように見えても、中身はただの `lambda` (= 手続き) です。`my-car` が結果を取り出せるのは、ペアの中に保存されているのではなく、ペア (=lambda) を呼び出して **計算してもらっている** からです。

つまり、

- 「データ」と「手続き」の境界は実は曖昧で、
- ある操作的契約を満たしていれば「データ」として扱える、
- という相対的な定義しかできません。

本節 (SICP 2.1.3) では「Church 数」と呼ばれる、自然数までも手続きだけで表現する話も出てきますが、ここではペアの実装で本質を捉えるところまでにします。

===exercise: 上で定義した my-cons / my-car / my-cdr を使って、 3 要素「リスト」 (my-cons 1 (my-cons 2 (my-cons 3 nil))) を作り、 2 番目の要素を取り出してください。 具体的には: (my-car (my-cdr (my-cons 1 (my-cons 2 (my-cons 3 nil))))) 最終式の値は 2 になります。 my-cons / my-car / my-cdr の定義は自分でセル内に書くこと (上のセル本文をそのままコピーして OK)。===
; (define (my-cons a b) ...)
; (define (my-car p) ...)
; (define (my-cdr p) ...)
; 最後に
; (my-car (my-cdr (my-cons 1 (my-cons 2 (my-cons 3 nil)))))

===expect: 手続きペアで作ったリストの 2 番目===
2

===solution: 上で定義した my-cons / my-car / my-cdr を使って、 3 要素「リスト」 (my-cons 1 (my-cons 2 (my-cons 3 nil))) を作り、 2 番目の要素を取り出してください。 具体的には: (my-car (my-cdr (my-cons 1 (my-cons 2 (my-cons 3 nil))))) 最終式の値は 2 になります。 my-cons / my-car / my-cdr の定義は自分でセル内に書くこと (上のセル本文をそのままコピーして OK)。===
(define (my-cons a b) (lambda (selector) (selector a b)))
(define (my-car p) (p (lambda (a b) a)))
(define (my-cdr p) (p (lambda (a b) b)))
(my-car (my-cdr (my-cons 1 (my-cons 2 (my-cons 3 nil)))))
