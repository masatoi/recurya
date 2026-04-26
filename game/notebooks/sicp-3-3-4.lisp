;;;; game/notebooks/sicp-3-3-4.lisp --- SICP 3.3.4 Digital Circuit Simulator (state-transition).

(defpackage #:recurya/game/notebooks/sicp-3-3-4
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-3-3-4-notebook))

(in-package #:recurya/game/notebooks/sicp-3-3-4)

(defun make-sicp-3-3-4-notebook ()
  "SICP 3.3.4 - Digital circuit simulator rewritten as state-transition functions."
  (make-notebook
   :id :sicp-3-3-4
   :chapter "3.3.4"
   :title "デジタル回路シミュレータ (状態遷移版)"
   :summary "SICP 3.3.4 の event-driven なデジタル回路シミュレータを、ワイヤ alist 上の状態遷移関数の固定点反復で書き換える。inverter / and-gate を組み合わせて NAND を構成。"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p (:strong "SICP 3.3.4")
                           " はデジタル回路シミュレータを扱います。原典では:")
                       (:ul
                        (:li "ワイヤ (wire) は signal value を持ち、"
                             (:code "set-signal!")
                             " で更新可能")
                        (:li "ゲート (and-gate, or-gate, inverter) は入力ワイヤに『action procedure』を "
                             (:code "set-add-action!")
                             " で登録")
                        (:li "アジェンダ (agenda) に時間付きイベントを "
                             (:code "add-to-agenda!")
                             " で挿入し、時刻を進めて "
                             (:code "set!")
                             " で signal を更新"))
                       (:p "これはすべて "
                           (:code "set!")
                           " ベースなので WardLisp では動きません。"
                           "代わりに、回路の状態を "
                           (:code "((wire-name . value) ...)")
                           " のような alist で表し、各ゲートを "
                           (:strong "状態遷移関数 (state) → state'")
                           " で表現します。"
                           "シミュレーションは固定点まで反復(状態が変化しなくなったら停止)。")))
    (make-cell :id :design :kind :prose
               :body '(:div
                       (:p (:strong "設計")
                           ": 回路全体の状態を "
                           (:strong "ワイヤ名 → 値")
                           " の alist で表す。"
                           "各ゲートは入力ワイヤを読んで出力ワイヤを更新する関数を返す。"
                           "回路は『ゲートのリスト』として表現し、"
                           (:code "apply-gates")
                           " で順に状態を流していく。")
                       (:p "サンプル: "
                           (:code "NAND(a, b) = NOT(AND(a, b))")
                           "。AND の結果を中間ワイヤ "
                           (:code "temp")
                           " に書き出し、それを inverter で反転して "
                           (:code "out")
                           " に。")))
    (make-cell :id :nand-eval :kind :code-eval
               :body "(define (lookup key alist)
  (cond ((null? alist) nil)
        ((eq? key (car (car alist))) (cdr (car alist)))
        (t (lookup key (cdr alist)))))
(define (insert key value alist)
  (cond ((null? alist) (list (cons key value)))
        ((eq? key (car (car alist)))
         (cons (cons key value) (cdr alist)))
        (t (cons (car alist) (insert key value (cdr alist))))))
(define (logical-not x) (if (= x 0) 1 0))
(define (logical-and x y) (if (and (= x 1) (= y 1)) 1 0))
;; gate: (state) → state'
(define (inverter in out)
  (lambda (state) (insert out (logical-not (lookup in state)) state)))
(define (and-gate a b out)
  (lambda (state) (insert out (logical-and (lookup a state) (lookup b state)) state)))
;; circuit: a list of gates, applied in sequence
(define (apply-gates gates state)
  (if (null? gates) state (apply-gates (cdr gates) ((car gates) state))))
;; NAND = NOT(AND a b)
(define (nand-circuit) (list (and-gate 'a 'b 'temp) (inverter 'temp 'out)))
(define initial (list (cons 'a 1) (cons 'b 1) (cons 'temp 0) (cons 'out 0)))
(define final (apply-gates (nand-circuit) initial))
(lookup 'out final)
;; → 0 (1 AND 1 → 1, NOT 1 → 0)")
    (make-cell :id :compare :kind :prose
               :body '(:div
                       (:p (:strong "比較")
                           ": SICP 原典は時間を "
                           (:code "delay")
                           " でモデル化し、各ゲートに遅延 (e.g. "
                           (:code "and-gate-delay")
                           ") を持たせて event-driven に進めます。"
                           "WardLisp 版は "
                           (:strong "同期的・1 ステップ完結")
                           " で、回路全体を上から順に評価する形。"
                           "教育目的としては、回路の論理的な振る舞いを理解するには十分です。"
                           "本格的なタイミング解析は SICP 原典(または Verilog のような専用言語)に譲ります。")))
    (make-cell :id :stable :kind :prose
               :body '(:div
                       (:p (:strong "固定点反復による安定化")
                           ": 回路にループ(フリップフロップ等)があると、"
                           "1 ステップでは安定しないことがあります。"
                           "状態が変化しなくなるまで反復する "
                           (:code "iterate-until-stable")
                           " を加えると、より一般的な回路を扱えます。"
                           "ループのない単純な回路では 1 ステップで安定するので、"
                           "実質的にはどちらでも同じ結果が得られます。")))
    (make-cell :id :stable-eval :kind :code-eval
               :body "(define (lookup key alist)
  (cond ((null? alist) nil)
        ((eq? key (car (car alist))) (cdr (car alist)))
        (t (lookup key (cdr alist)))))
(define (insert key value alist)
  (cond ((null? alist) (list (cons key value)))
        ((eq? key (car (car alist))) (cons (cons key value) (cdr alist)))
        (t (cons (car alist) (insert key value (cdr alist))))))
(define (logical-and x y) (if (and (= x 1) (= y 1)) 1 0))
(define (and-gate a b out) (lambda (s) (insert out (logical-and (lookup a s) (lookup b s)) s)))
(define (apply-gates gates state) (if (null? gates) state (apply-gates (cdr gates) ((car gates) state))))
(define (iterate-until-stable f state limit)
  (if (= limit 0)
      state
      (let ((next (f state)))
        (if (equal? next state) state (iterate-until-stable f next (- limit 1))))))
(define gates (list (and-gate 'a 'b 'out)))
(define (apply-circuit s) (apply-gates gates s))
(define stable (iterate-until-stable apply-circuit (list (cons 'a 1) (cons 'b 1) (cons 'out 0)) 10))
(lookup 'out stable)
;; → 1")
    (make-cell :id :ex-and-gate :kind :code-exercise
               :description
               "and-gate と apply-gates を実装し、入力 (a=1, b=0) のときの出力 'out の値を返してください。
期待値は 0 です (1 AND 0 = 0)。
最終式:
  (lookup 'out (apply-gates (list (and-gate 'a 'b 'out))
                            (list (cons 'a 1) (cons 'b 0) (cons 'out 0))))
スケルトン:
  (define (lookup key alist)
    (cond ((null? alist) nil)
          ((eq? key (car (car alist))) (cdr (car alist)))
          (t (lookup key (cdr alist)))))
  (define (insert key value alist)
    (cond ((null? alist) (list (cons key value)))
          ((eq? key (car (car alist))) (cons (cons key value) (cdr alist)))
          (t (cons (car alist) (insert key value (cdr alist))))))
  (define (logical-and x y) (if (and (= x 1) (= y 1)) 1 0))
  (define (and-gate a b out)
    (lambda (s) (insert out (logical-and (lookup a s) (lookup b s)) s)))
  (define (apply-gates gates state)
    (if (null? gates) state (apply-gates (cdr gates) ((car gates) state))))
  (lookup 'out (apply-gates (list (and-gate 'a 'b 'out))
                            (list (cons 'a 1) (cons 'b 0) (cons 'out 0))))"
               :body "; (define (lookup key alist) ...)
; (define (insert key value alist) ...)
; (define (logical-and x y) ...)
; (define (and-gate a b out) ...)
; (define (apply-gates gates state) ...)
; (lookup 'out (apply-gates (list (and-gate 'a 'b 'out))
;                           (list (cons 'a 1) (cons 'b 0) (cons 'out 0))))
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "0"
                                     :description "AND ゲート: 1 AND 0 = 0")))
    (make-cell :id :ex-nand :kind :code-exercise
               :description
               "NAND 回路 (NOT (AND a b)) を 2 つのゲートで構成し、入力 (a=1, b=1) のときの 'out を返してください。
期待値は 0 です (1 AND 1 = 1, NOT 1 = 0)。
最終式:
  (lookup 'out (apply-gates (list (and-gate 'a 'b 'temp) (inverter 'temp 'out))
                            (list (cons 'a 1) (cons 'b 1) (cons 'temp 0) (cons 'out 0))))
スケルトン:
  (define (lookup key alist)
    (cond ((null? alist) nil)
          ((eq? key (car (car alist))) (cdr (car alist)))
          (t (lookup key (cdr alist)))))
  (define (insert key value alist)
    (cond ((null? alist) (list (cons key value)))
          ((eq? key (car (car alist))) (cons (cons key value) (cdr alist)))
          (t (cons (car alist) (insert key value (cdr alist))))))
  (define (logical-not x) (if (= x 0) 1 0))
  (define (logical-and x y) (if (and (= x 1) (= y 1)) 1 0))
  (define (inverter in out)
    (lambda (state) (insert out (logical-not (lookup in state)) state)))
  (define (and-gate a b out)
    (lambda (state) (insert out (logical-and (lookup a state) (lookup b state)) state)))
  (define (apply-gates gates state)
    (if (null? gates) state (apply-gates (cdr gates) ((car gates) state))))
  (lookup 'out (apply-gates (list (and-gate 'a 'b 'temp) (inverter 'temp 'out))
                            (list (cons 'a 1) (cons 'b 1) (cons 'temp 0) (cons 'out 0))))"
               :body "; NAND = NOT(AND a b) を 2 ゲートで組み立て、'out を返す
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "0"
                                     :description "NAND(1,1) = 0"))))))
