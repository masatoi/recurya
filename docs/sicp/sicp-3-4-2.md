===prose===
**SICP 3.4.2** は並行性を制御する 3 つの機構を扱います:

- **Serializer**(直列化器): 一連の手続きを「同時実行しない」ようにグループ化
- **Mutex**: 1 つだけが同時に保持できるロック
- **Semaphore**: 一定数まで保持できる一般化されたロック

===prose===
**SICP 原典の **`make-serializer`:

```
`(define protected-withdraw (serializer withdraw))
(define protected-deposit (serializer deposit))
;; 同じ serializer を共有する手続きは互いに排他`
```

これは**状態の更新タイミングを制限**する仕組みです。

===prose===
**問題点**(SICP 自身が指摘): 複雑な lock は**デッドロック**を生む。`deposit acc1 amt1` と `withdraw acc2 amt2` を別々の serializer で守ると、両方を同時に呼ぶ手続きはデッドロックする可能性があります。

===prose===
**WardLisp/関数型代替**: **Software Transactional Memory (STM)** 的なアプローチ — 操作を `(state) → state'` で記述し、**全体を一度に適用** する。中間状態は外部から見えない。Clojure の `dosync` 等が現実例。

===eval===
(define (lookup id bank)
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
;; → (70 80)

===prose===
**観察**:

- `transfer` は中間状態 (alice 70, bob 50) を**世界に晒さない** — bank0 の世界と bank1 の世界しか存在しない
- `transfer` を「並行に」2 回呼んだ結果(`bank0` から 2 つの新世界 `bank-A`, `bank-B`)を後で統合する仕組み (merge / conflict resolution) は別の話だが、**競合状態は起きない**(immutable なので)
- これが Datomic / Persistent Data Structure の発想

===prose===
**まとめ**:

- SICP 原典の**時間的・mutation-based の並行性**は強力だが lock 設計が難しい
- 関数型の**不変性ベースの並行性**は競合状態を排除するが、世界のバージョン管理が必要
- 両者は**トレードオフの関係**で、現実のシステムは両方を組み合わせる(例: Clojure の Atom + STM、Haskell の TVar + STM)
