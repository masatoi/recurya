;;;; game/notebooks/sicp-3-4-1.lisp --- SICP 3.4.1 The Nature of Time in Concurrent Systems.

(defpackage #:recurya/game/notebooks/sicp-3-4-1
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:export #:make-sicp-3-4-1-notebook))

(in-package #:recurya/game/notebooks/sicp-3-4-1)

(defun make-sicp-3-4-1-notebook ()
  "SICP 3.4.1 - The nature of time in concurrent systems, contrasted with functional/immutable approach."
  (make-notebook
   :id :sicp-3-4-1
   :chapter "3.4.1"
   :title "並行システムにおける時間の本質"
   :summary "SICP 3.4.1 は並行システムにおける時間と状態の問題を扱う。複数のプロセスが同じ可変状態を共有すると競合状態 (race condition) が起きる。WardLisp はシングルスレッドなので並行性そのものは実演できないが、関数型 (不変) アプローチではそもそも競合が問題にならないことを示す。"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p (:strong "SICP 3.4.1")
                           " は並行システムにおける"
                           (:strong "時間と状態")
                           "の問題を扱います。"
                           "複数のプロセスが同じ可変状態を共有すると、操作の"
                           (:strong "順序")
                           "(時間)に依存して結果が変わる "
                           (:strong "競合状態 (race condition)")
                           " が起きます。")))
    (make-cell :id :race-example :kind :prose
               :body '(:div
                       (:p (:strong "典型例")
                           ": 銀行口座の同時引き落とし")
                       (:pre
                        (:code
                         ";; SICP 原典(set! ベース、並行性あり想定)
(define peter-acc (make-account 100))
;; プロセス A:                      プロセス B:
;; (set! balance (- balance 10))    (set! balance (- balance 25))"))
                       (:p "両プロセスが同時に "
                           (:code "balance")
                           " を読み、それぞれ計算してから "
                           (:code "set!")
                           " で書き戻すと、"
                           (:strong "最後の write が勝ち")
                           "、片方の引き落としが消えます (lost update)。")))
    (make-cell :id :serialization :kind :prose
               :body '(:div
                       (:p (:strong "直列化 (serialization)")
                           ": SICP 原典は "
                           (:code "make-serializer")
                           " を使って『同時にこれを実行しないでね』というガードを設定します。"
                           "これは典型的な mutex / lock の実装。"
                           "並行性のためのプリミティブが言語(または OS)に必要になります。")))
    (make-cell :id :functional-alt :kind :prose
               :body '(:div
                       (:p (:strong "WardLisp/関数型のアプローチ")
                           ": 状態を"
                           (:strong "不変 (immutable)")
                           "にすれば、共有自体が問題になりません。"
                           "複数のプロセスが同じデータを"
                           (:strong "読む")
                           "だけなら競合は起きない。"
                           "書き換えは新しい値を返すので、各プロセスがそれぞれ自分の文脈で新しい値を持ちます。")))
    (make-cell :id :functional-eval :kind :code-eval
               :body "(define (make-account balance) (cons 'account balance))
(define (account-balance acc) (cdr acc))
(define (withdraw acc amt)
  (if (>= (account-balance acc) amt)
      (make-account (- (account-balance acc) amt))
      acc))
;; 「並行に」withdraw を呼んでも、それぞれが新しい account を返す
(define peter-acc (make-account 100))
(define peter-after-A (withdraw peter-acc 10))   ;; プロセス A の見る世界
(define peter-after-B (withdraw peter-acc 25))   ;; プロセス B の見る世界
(list (account-balance peter-after-A) (account-balance peter-after-B))
;; → (90 75)")
    (make-cell :id :two-worlds :kind :prose
               :body '(:div
                       (:p (:strong "重要な観察")
                           ": 関数型版では「peter-acc が 90 になる世界」と「peter-acc が 75 になる世界」が"
                           (:strong "両方とも生成")
                           "されます。"
                           "この 2 つの世界をどう統合するかは、"
                           (:strong "プログラム上の問題")
                           "(STM, CRDT, 関数型データベース)であって、"
                           (:strong "言語実装の問題ではない")
                           "。")
                       (:p "これが Clojure / Haskell / Erlang などの "
                           (:strong "関数型並行プログラミング")
                           " が依拠する原理。"
                           "状態を不変にすれば、ロックは最終結合だけに必要になります。")))
    (make-cell :id :takeaway :kind :prose
               :body '(:div
                       (:p (:strong "SICP 原典のメッセージ")
                           ": 並行性のせいで「時間」というモデル化が必要になる。")
                       (:p (:strong "WardLisp/関数型")
                           ": 不変性によって時間を抽象化する別の方法もある — 各 transaction が世界の新しい"
                           (:em "バージョン")
                           "を作り、参照は明示的に進める。"))))))
