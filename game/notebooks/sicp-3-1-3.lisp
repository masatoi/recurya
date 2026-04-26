;;;; game/notebooks/sicp-3-1-3.lisp --- SICP 3.1.3 Costs of assignment.

(defpackage #:recurya/game/notebooks/sicp-3-1-3
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-3-1-3-notebook))

(in-package #:recurya/game/notebooks/sicp-3-1-3)

(defun make-sicp-3-1-3-notebook ()
  "SICP 3.1.3 - The cost of introducing assignment: loss of referential transparency."
  (make-notebook
   :id :sicp-3-1-3
   :chapter "3.1.3"
   :title "代入導入のコスト (参照透過性の喪失)"
   :summary "set! を導入することで何を失うか ─ 参照透過性 (referential transparency)。同じ式が同じ文脈で常に同じ値を返すという性質が壊れる。WardLisp の関数型版ではこの性質が保たれることを観察する"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p (:strong "SICP 3.1.3")
                           " は "
                           (:code "set!")
                           " を導入することで "
                           (:strong "失うもの")
                           " ─ "
                           (:strong "参照透過性 (referential transparency)")
                           " ─ を論じます。"
                           "参照透過性とは、同じ式が同じ文脈で常に同じ値を返すという性質です。"
                           "数学の関数 "
                           (:code "f(x) = x^2")
                           " は "
                           (:code "f(3)")
                           " がいつでも 9 を返すように。")))
    (make-cell :id :set-bang-issue :kind :prose
               :body '(:div
                       (:p "SICP 原典の "
                           (:code "set!")
                           " 版 make-account では、同じ式が呼ぶたびに違う値を返します:")
                       (:pre "(define a (make-account 100))
((a 'withdraw) 30)  ;; → 70
((a 'withdraw) 30)  ;; → 40   ← 同じ式なのに値が違う!
((a 'withdraw) 30)  ;; → 10")
                       (:p "これが "
                           (:strong "参照透過性の喪失")
                           " です。"
                           "コードを読むだけでは値が分からなくなり、推論・テスト・並列実行のどれもが難しくなります。")))
    (make-cell :id :functional-preserves :kind :code-eval
               :body "(define (make-account balance) (cons 'account balance))
(define (account-balance acc) (cdr acc))
(define (withdraw acc amt)
  (if (>= (account-balance acc) amt)
      (make-account (- (account-balance acc) amt))
      acc))
(define a (make-account 100))
;; 同じ式 (withdraw a 30) は何度書いても同じ値 70 を返す
(list (account-balance (withdraw a 30))
      (account-balance (withdraw a 30))
      (account-balance (withdraw a 30)))")
    (make-cell :id :transparency-discuss :kind :prose
               :body '(:div
                       (:p "上のセルでは "
                           (:code "(withdraw a 30)")
                           " を 3 回呼び出していますが、すべて同じ値 (残高 70) を返します。"
                           (:code "a")
                           " 自体は変化しないため、"
                           (:strong "参照透過性が保たれている")
                           " のが分かります。")))
    (make-cell :id :identity-equality :kind :prose
               :body '(:div
                       (:p (:strong "同一性 (identity) と等価性 (equality)")
                           ":")
                       (:ul
                        (:li (:strong "SICP 原典 (set! 版)")
                             ": 「同じ口座 (same account)」と「中身が同じ口座 (equal accounts)」を区別する必要が生じます。"
                             (:code "(eq? a1 a2)")
                             " で同一性、"
                             (:code "(equal? (balance a1) (balance a2))")
                             " で等価性。")
                        (:li (:strong "関数型版 (持続的データ)")
                             ": 値が同じなら全く同じものとして扱える。同一性と等価性の区別は不要 ─ "
                             (:em "値そのものが履歴と切り離された不変の事実")
                             " になる。"))))
    (make-cell :id :gain-vs-loss :kind :prose
               :body '(:div
                       (:p (:strong "得るもの (gain)")
                           ": "
                           (:code "set!")
                           " を導入すると、長く生きるオブジェクト (銀行口座、ゲームのプレイヤー、UI コンポーネント) を "
                           (:strong "一つの実体")
                           " として表現でき、現実世界のモデル化が直感的になる。"
                           "GUI の「ボタンを押すたびに同じカウンターが増える」のような場面では極めて自然。")
                       (:p (:strong "失うもの (loss)")
                           ":")
                       (:ul
                        (:li (:strong "参照透過性")
                             " ─ コードからの値の推論")
                        (:li (:strong "並列実行の容易さ")
                             " ─ 共有状態の排他制御が不要")
                        (:li (:strong "テストの再現性")
                             " ─ 同じ入力 → 同じ出力")
                        (:li (:strong "時間軸での同一性の自明さ")
                             " ─ 「現在の口座」と「過去の口座」の関係を扱う追加機構が必要"))))
    (make-cell :id :ex-pure-counter :kind :code-exercise
               :description
               "純関数的なカウンター (3.1.1 の演習と同じ題材) を改めて実装し、参照透過性の保たれていることを観察します。
  (define (make-counter) ...)
  (define (tick c) ...)         ; +1 された新しいカウンター
  (define (value c) ...)
を定義し、最終式として
  (value (tick (tick (tick (make-counter)))))
を残してください。 同じ式は何度評価しても同じ値 3 を返す ─ これが参照透過性です。"
               :body "; (define (make-counter) ...)
; (define (tick c) ...)
; (define (value c) ...)
; 最後に (value (tick (tick (tick (make-counter)))))
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "3"
                                     :description "純関数的カウンターで 3 回 tick して値 3")))
    (make-cell :id :next-section :kind :prose
               :body '(:div
                       (:p "次節 ("
                           (:strong "3.2 環境モデル")
                           ") では SICP の "
                           (:strong "環境モデル (environment model)")
                           " に進みます。"
                           "これは "
                           (:code "set!")
                           " がどう動くかを正確に説明する仕組みで、"
                           "純関数版のレキシカルスコープを理解する助けにもなります。"))))))
