;;;; game/notebooks/sicp-3-2-2.lisp --- SICP 3.2.2 Applying Simple Procedures.

(defpackage #:recurya/game/notebooks/sicp-3-2-2
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-3-2-2-notebook))

(in-package #:recurya/game/notebooks/sicp-3-2-2)

(defun make-sicp-3-2-2-notebook ()
  "SICP 3.2.2 - Applying simple procedures: tracing function application step by step."
  (make-notebook
   :id :sicp-3-2-2
   :chapter "3.2.2"
   :title "単純な手続きの適用"
   :summary "関数適用 (procedure application) の評価ステップを環境モデルで追う。新しいフレームを作り、引数を束縛し、body をそのフレームで評価する流れを丁寧に観察する"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p (:code "(define (square x) (* x x))")
                           " を呼ぶ "
                           (:code "(square 5)")
                           " の評価を環境モデルで追ってみましょう:")
                       (:ol
                        (:li "引数 "
                             (:code "5")
                             " を評価する (既に値なのでそのまま)")
                        (:li "新フレーム "
                             (:code "E1")
                             " を作り、親を "
                             (:strong (:code "square")
                                      " の定義環境")
                             " (= global) に設定する")
                        (:li (:code "E1")
                             " に "
                             (:code "x: 5")
                             " を束縛する")
                        (:li "body "
                             (:code "(* x x)")
                             " を "
                             (:code "E1")
                             " で評価 → "
                             (:code "5 * 5 = 25")))))
    (make-cell :id :square-eval :kind :code-eval
               :body "(define (square x) (* x x))
(square 5)")
    (make-cell :id :nested-call :kind :prose
               :body '(:div
                       (:p (:strong "ネストした呼び出し")
                           ":")
                       (:pre "(define (square x) (* x x))
(define (sum-of-squares x y) (+ (square x) (square y)))
(sum-of-squares 3 4)")
                       (:p "評価過程:")
                       (:ol
                        (:li (:code "sum-of-squares")
                             " の呼び出しで E1 が作られ、"
                             (:code "x: 3, y: 4")
                             " が束縛される")
                        (:li "body "
                             (:code "(+ (square x) (square y))")
                             " を E1 で評価")
                        (:li (:code "(square 3)")
                             " で E2 (parent: global, "
                             (:code "x: 3")
                             ") が作られ、"
                             (:code "(* x x)")
                             " を評価 → 9")
                        (:li (:code "(square 4)")
                             " で E3 (parent: global, "
                             (:code "x: 4")
                             ") が作られ、"
                             (:code "(* x x)")
                             " を評価 → 16")
                        (:li (:code "(+ 9 16)")
                             " → 25"))
                       (:p (:strong "注意")
                           ": E2 と E3 の "
                           (:code "x")
                           " は E1 の "
                           (:code "x")
                           " とは別物。"
                           "それぞれの呼び出しが独立したフレームを持つので互いに影響しません。")))
    (make-cell :id :nested-eval :kind :code-eval
               :body "(define (square x) (* x x))
(define (sum-of-squares x y) (+ (square x) (square y)))
(sum-of-squares 3 4)")
    (make-cell :id :lexical-vs-dynamic :kind :prose
               :body '(:div
                       (:p (:strong "フレーム親の決定")
                           ": 関数が "
                           (:strong "呼ばれた")
                           " ときの環境ではなく、関数が "
                           (:strong "作られた")
                           " ときの環境が親になります (= レキシカルスコープ)。")
                       (:p "これが "
                           (:strong "動的スコープ (dynamic scope)")
                           " と区別される点です。"
                           "動的スコープなら呼び出し時の環境を親にしますが、"
                           "Scheme・WardLisp・Lisp 系のほとんどはレキシカルスコープを採用します。"
                           "理由: コードを読むだけで変数の意味が決まるので推論しやすい。")
                       (:p "ASCII 図:")
                       (:pre "  [global]
  └── square: (lambda (x) (* x x))   ← 定義時に global を捕捉

  square 呼び出し
    E1 [parent: global]
    └── x: 5
        body (* x x) を E1 で評価")))
    (make-cell :id :ex-shadow :kind :code-exercise
               :description
               "次のコードの評価結果を予想してから実行してください。
  (define x 100)
  (define (f y) (+ x y))
  (define x 1)
  (f 5)
WardLisp の define は再定義可能で、後の (define x 1) が前の x を上書きします。
そのあと (f 5) を呼ぶので、f の body 中の x は最新の 1、y は 5 になり、結果は 1 + 5 = 6 です。
最終式として (f 5) を残してください。期待値は 6 です。"
               :body "; (define x 100)
; (define (f y) (+ x y))
; (define x 1)
; (f 5)
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "6"
                                     :description "x を 100 から 1 に再定義した後 (f 5) は 6"))))))
