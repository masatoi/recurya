;;;; game/notebooks/sicp-2-1-3.lisp --- SICP 2.1.3 What Is Meant by Data?

(defpackage #:recurya/game/notebooks/sicp-2-1-3
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-2-1-3-notebook))

(in-package #:recurya/game/notebooks/sicp-2-1-3)

(defun make-sicp-2-1-3-notebook ()
  "SICP 2.1.3 - What Is Meant by Data?"
  (make-notebook
   :id :sicp-2-1-3
   :chapter "2.1.3"
   :title "データとは何か"
   :summary "cons / car / cdr すら手続きだけで実装できることを示し、データと手続きの境界が曖昧であることを体験する"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p "ここまで " (:code "cons") " / "
                           (:code "car") " / " (:code "cdr")
                           " は処理系が用意してくれる "
                           (:strong "プリミティブ")
                           " として使ってきました。"
                           "ですが SICP 2.1.3 の中心的なメッセージは、")
                       (:blockquote
                        (:strong "「ペア」というデータ構造は、実は手続きだけで完全に実装できる")
                        " ということです。")
                       (:p "つまり、ペアの満たすべき "
                           (:strong "契約 (contract)") " は")
                       (:ul
                        (:li (:code "(car (cons a b))") " は "
                             (:code "a") " を返す")
                        (:li (:code "(cdr (cons a b))") " は "
                             (:code "b") " を返す"))
                       (:p "の 2 つだけで、これを満たす実装ならば "
                           "ペアとして使えます。"
                           "下のセルでは、" (:code "lambda")
                           " だけでこれを実現してみます。")))
    (make-cell :id :proc-pair-prose :kind :prose
               :body '(:div
                       (:p (:strong "アイデア")
                           ": " (:code "(my-cons a b)")
                           " は " (:code "a") " と " (:code "b")
                           " を「閉じ込めた」 lambda を返す。"
                           "外から「セレクタ (どちらを選ぶか)」を渡されたら、"
                           "そのセレクタに " (:code "a") " と "
                           (:code "b") " を引数として渡して呼ぶだけ。")
                       (:p (:code "my-car") " は「最初の引数を返すセレクタ」を、"
                           (:code "my-cdr") " は「二番目の引数を返すセレクタ」を"
                           "渡してペアを呼ぶ、という設計です。")))
    (make-cell :id :proc-pair-code :kind :code-eval
               :body "(define (my-cons a b) (lambda (selector) (selector a b)))
(define (my-car p) (p (lambda (a b) a)))
(define (my-cdr p) (p (lambda (a b) b)))
(define p (my-cons 7 13))
(list (my-car p) (my-cdr p))")
    (make-cell :id :discussion :kind :prose
               :body '(:div
                       (:p (:strong "重要な観察")
                           ": " (:code "my-cons")
                           " が返す値は「データ」のように見えても、"
                           "中身はただの " (:code "lambda")
                           " (= 手続き) です。"
                           (:code "my-car") " が結果を取り出せるのは、"
                           "ペアの中に保存されているのではなく、"
                           "ペア (=lambda) を呼び出して "
                           (:strong "計算してもらっている")
                           " からです。")
                       (:p "つまり、")
                       (:ul
                        (:li "「データ」と「手続き」の境界は実は曖昧で、")
                        (:li "ある操作的契約を満たしていれば「データ」として扱える、")
                        (:li "という相対的な定義しかできません。"))
                       (:p "本節 (SICP 2.1.3) では「Church 数」と呼ばれる、"
                           "自然数までも手続きだけで表現する話も出てきますが、"
                           "ここではペアの実装で本質を捉えるところまでにします。")))
    (make-cell :id :ex-my-list :kind :code-exercise
               :description
               "上で定義した my-cons / my-car / my-cdr を使って、
3 要素「リスト」 (my-cons 1 (my-cons 2 (my-cons 3 nil))) を作り、
2 番目の要素を取り出してください。

具体的には:
  (my-car (my-cdr (my-cons 1 (my-cons 2 (my-cons 3 nil)))))

最終式の値は 2 になります。
my-cons / my-car / my-cdr の定義は自分でセル内に書くこと
(上のセル本文をそのままコピーして OK)。"
               :body "; (define (my-cons a b) ...)
; (define (my-car p) ...)
; (define (my-cdr p) ...)
; 最後に
; (my-car (my-cdr (my-cons 1 (my-cons 2 (my-cons 3 nil)))))
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "2"
                                     :description "手続きペアで作ったリストの 2 番目"))))))
