;;;; game/notebooks/sicp-3-4-2.lisp --- SICP 3.4.2 Mechanisms for Controlling Concurrency.

(defpackage #:recurya/game/notebooks/sicp-3-4-2
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:export #:make-sicp-3-4-2-notebook))

(in-package #:recurya/game/notebooks/sicp-3-4-2)

(defun make-sicp-3-4-2-notebook ()
  "SICP 3.4.2 - Mechanisms for controlling concurrency (serializer / mutex / semaphore) vs STM-style atomic transactions."
  (make-notebook
   :id :sicp-3-4-2
   :chapter "3.4.2"
   :title "並行性の制御機構"
   :summary "SICP の serializer / mutex / semaphore を紹介し、WardLisp の関数型アプローチで似た問題 (口座間振替) を STM 的に解く例を示す。中間状態を世界に晒さずトランザクション全体を 1 つの状態遷移として扱うことで、競合状態を排除する。"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p (:strong "SICP 3.4.2")
                           " は並行性を制御する 3 つの機構を扱います:")
                       (:ul
                        (:li (:strong "Serializer")
                             "(直列化器): 一連の手続きを「同時実行しない」ようにグループ化")
                        (:li (:strong "Mutex")
                             ": 1 つだけが同時に保持できるロック")
                        (:li (:strong "Semaphore")
                             ": 一定数まで保持できる一般化されたロック"))))
    (make-cell :id :serializer-example :kind :prose
               :body '(:div
                       (:p (:strong "SICP 原典の ")
                           (:code "make-serializer")
                           ":")
                       (:pre
                        (:code
                         "(define protected-withdraw (serializer withdraw))
(define protected-deposit (serializer deposit))
;; 同じ serializer を共有する手続きは互いに排他"))
                       (:p "これは"
                           (:strong "状態の更新タイミングを制限")
                           "する仕組みです。")))
    (make-cell :id :deadlock :kind :prose
               :body '(:div
                       (:p (:strong "問題点")
                           "(SICP 自身が指摘): 複雑な lock は"
                           (:strong "デッドロック")
                           "を生む。"
                           (:code "deposit acc1 amt1")
                           " と "
                           (:code "withdraw acc2 amt2")
                           " を別々の serializer で守ると、両方を同時に呼ぶ手続きはデッドロックする可能性があります。")))
    (make-cell :id :stm-intro :kind :prose
               :body '(:div
                       (:p (:strong "WardLisp/関数型代替")
                           ": "
                           (:strong "Software Transactional Memory (STM)")
                           " 的なアプローチ — 操作を "
                           (:code "(state) → state'")
                           " で記述し、"
                           (:strong "全体を一度に適用")
                           " する。"
                           "中間状態は外部から見えない。"
                           "Clojure の "
                           (:code "dosync")
                           " 等が現実例。")))
    (make-cell :id :stm-eval :kind :code-eval
               :body "(define (lookup id bank)
  (cond ((null? bank) nil)
        ((eq? id (car (car bank))) (cdr (car bank)))
        (t (lookup id (cdr bank)))))
(define (insert id balance bank)
  (cond ((null? bank) (list (cons id balance)))
        ((eq? id (car (car bank))) (cons (cons id balance) (cdr bank)))
        (t (cons (car bank) (insert id balance (cdr bank))))))
;; transfer: account from-id から to-id に amt を移す。
;; 両方の更新を 1 つのトランザクションとして扱う(中間状態は出ない)
(define (transfer bank from-id to-id amt)
  (let ((from-bal (lookup from-id bank)))
    (if (and from-bal (>= from-bal amt))
        (let ((bank1 (insert from-id (- from-bal amt) bank)))
          (insert to-id (+ (lookup to-id bank1) amt) bank1))
        bank)))
(define bank0 (list (cons 'alice 100) (cons 'bob 50)))
(define bank1 (transfer bank0 'alice 'bob 30))
(list (lookup 'alice bank1) (lookup 'bob bank1))
;; → (70 80)")
    (make-cell :id :observation :kind :prose
               :body '(:div
                       (:p (:strong "観察")
                           ":")
                       (:ul
                        (:li (:code "transfer")
                             " は中間状態 (alice 70, bob 50) を"
                             (:strong "世界に晒さない")
                             " — bank0 の世界と bank1 の世界しか存在しない")
                        (:li (:code "transfer")
                             " を「並行に」2 回呼んだ結果("
                             (:code "bank0")
                             " から 2 つの新世界 "
                             (:code "bank-A")
                             ", "
                             (:code "bank-B")
                             ")を後で統合する仕組み (merge / conflict resolution) は別の話だが、"
                             (:strong "競合状態は起きない")
                             "(immutable なので)")
                        (:li "これが Datomic / Persistent Data Structure の発想"))))
    (make-cell :id :summary :kind :prose
               :body '(:div
                       (:p (:strong "まとめ")
                           ":")
                       (:ul
                        (:li "SICP 原典の"
                             (:strong "時間的・mutation-based の並行性")
                             "は強力だが lock 設計が難しい")
                        (:li "関数型の"
                             (:strong "不変性ベースの並行性")
                             "は競合状態を排除するが、世界のバージョン管理が必要")
                        (:li "両者は"
                             (:strong "トレードオフの関係")
                             "で、現実のシステムは両方を組み合わせる(例: Clojure の Atom + STM、Haskell の TVar + STM)")))))))
