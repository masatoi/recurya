===prose===
**SICP 3.3.5** は制約ネットワーク (connector ↔ constraint の双方向 mutation) を扱います。原典では各 connector が値を持ち、`set-value!` / `forget-value!` で更新を行い、関連する全 constraint に通知 (push-based) するモデル。

WardLisp では値を持つ connector を **alist** で表し、すべての constraint を順に評価する関数を **値が安定するまで反復** する pull-based モデルにします。未知の connector は `nil` で表現し、片方が分かれば他方を埋める方式。

===prose===
**摂氏 ↔ 華氏**: `9C = 5(F − 32)` という関係式を 1 つの constraint としてモデル化します。`C` または `F` の片方が分かれば他方を導出できる、双方向の制約。`cf-constraint` は state を受け取り、片方だけ既知なら他方を埋めた state を返す手続きです。

===eval===
(define (lookup key alist)
  (cond ((null? alist) nil)
        ((eq? key (car (car alist))) (cdr (car alist)))
        (t (lookup key (cdr alist)))))
(define (insert key value alist)
  (cond ((null? alist) (list (cons key value)))
        ((eq? key (car (car alist)))
         (cons (cons key value) (cdr alist)))
        (t (cons (car alist) (insert key value (cdr alist))))))
;; constraint: state を更新する手続きを返す
;; 9*C = 5*(F-32): 片方が既知なら他方を埋める
(define (cf-constraint c f)
  (lambda (state)
    (let ((cv (lookup c state)) (fv (lookup f state)))
      (cond ((and cv (not fv)) (insert f (+ (/ (* 9 cv) 5) 32) state))
            ((and fv (not cv)) (insert c (/ (* 5 (- fv 32)) 9) state))
            (t state)))))
(define (apply-constraints constraints state)
  (if (null? constraints) state (apply-constraints (cdr constraints) ((car constraints) state))))
(define (iterate-until-stable f state limit)
  (if (= limit 0)
      state
      (let ((next (f state)))
        (if (equal? next state) state (iterate-until-stable f next (- limit 1))))))
;; C=25 が与えられたとき F を計算
(define network (list (cf-constraint 'C 'F)))
(define stable
  (iterate-until-stable
    (lambda (s) (apply-constraints network s))
    (list (cons 'C 25) (cons 'F nil))
    10))
(lookup 'F stable)
;; → 77 (= 25 * 9/5 + 32)

===prose===
**双方向性**: 上の constraint は `C ⇒ F` も `F ⇒ C` も両方できます。`F=77` を与えれば `C=25` が出ます。constraint 自体は対称な定義になっており、どちらの方向に伝播するかは **どの connector が初期値を持っているか** で決まります。

===eval===
(define (lookup key alist)
  (cond ((null? alist) nil)
        ((eq? key (car (car alist))) (cdr (car alist)))
        (t (lookup key (cdr alist)))))
(define (insert key value alist)
  (cond ((null? alist) (list (cons key value)))
        ((eq? key (car (car alist))) (cons (cons key value) (cdr alist)))
        (t (cons (car alist) (insert key value (cdr alist))))))
(define (cf-constraint c f)
  (lambda (state)
    (let ((cv (lookup c state)) (fv (lookup f state)))
      (cond ((and cv (not fv)) (insert f (+ (/ (* 9 cv) 5) 32) state))
            ((and fv (not cv)) (insert c (/ (* 5 (- fv 32)) 9) state))
            (t state)))))
(define (apply-constraints constraints state)
  (if (null? constraints) state (apply-constraints (cdr constraints) ((car constraints) state))))
(define (iterate-until-stable f state limit)
  (if (= limit 0) state
      (let ((next (f state)))
        (if (equal? next state) state (iterate-until-stable f next (- limit 1))))))
(define net (list (cf-constraint 'C 'F)))
(define s (iterate-until-stable (lambda (st) (apply-constraints net st))
                                (list (cons 'C nil) (cons 'F 77))
                                10))
(lookup 'C s)
;; → 25

===prose===
**比較**: SICP 原典は connector が「自分の値が決まったら全 constraint に通知する」 **push-based** モデル。WardLisp 版は全 constraint を毎回チェックする **pull-based**。漸近計算量は劣る (constraints × iterations) ですが、教育目的では十分。値が一度決まれば次の反復で変化しないので、`iterate-until-stable` は素直に固定点に収束します。

===exercise: cf-constraint / apply-constraints / iterate-until-stable を実装し、C=100 を与えたときの F を返してください。 期待値は 212 (= 100 * 9/5 + 32) です。 最終式: (lookup 'F (iterate-until-stable (lambda (st) (apply-constraints (list (cf-constraint 'C 'F)) st)) (list (cons 'C 100) (cons 'F nil)) 10)) スケルトン: (define (lookup key alist) (cond ((null? alist) nil) ((eq? key (car (car alist))) (cdr (car alist))) (t (lookup key (cdr alist))))) (define (insert key value alist) (cond ((null? alist) (list (cons key value))) ((eq? key (car (car alist))) (cons (cons key value) (cdr alist))) (t (cons (car alist) (insert key value (cdr alist)))))) (define (cf-constraint c f) (lambda (state) (let ((cv (lookup c state)) (fv (lookup f state))) (cond ((and cv (not fv)) (insert f (+ (/ (* 9 cv) 5) 32) state)) ((and fv (not cv)) (insert c (/ (* 5 (- fv 32)) 9) state)) (t state))))) (define (apply-constraints constraints state) (if (null? constraints) state (apply-constraints (cdr constraints) ((car constraints) state)))) (define (iterate-until-stable f state limit) (if (= limit 0) state (let ((next (f state))) (if (equal? next state) state (iterate-until-stable f next (- limit 1)))))) (lookup 'F (iterate-until-stable (lambda (st) (apply-constraints (list (cf-constraint 'C 'F)) st)) (list (cons 'C 100) (cons 'F nil)) 10))===
; (define (lookup key alist) ...)
; (define (insert key value alist) ...)
; (define (cf-constraint c f) ...)
; (define (apply-constraints constraints state) ...)
; (define (iterate-until-stable f state limit) ...)
; (lookup 'F (iterate-until-stable ...))

===expect: C=100 → F=212 (沸点)===
212

===solution: cf-constraint / apply-constraints / iterate-until-stable を実装し、C=100 を与えたときの F を返してください。 期待値は 212 (= 100 * 9/5 + 32) です。 最終式: (lookup 'F (iterate-until-stable (lambda (st) (apply-constraints (list (cf-constraint 'C 'F)) st)) (list (cons 'C 100) (cons 'F nil)) 10)) スケルトン: (define (lookup key alist) (cond ((null? alist) nil) ((eq? key (car (car alist))) (cdr (car alist))) (t (lookup key (cdr alist))))) (define (insert key value alist) (cond ((null? alist) (list (cons key value))) ((eq? key (car (car alist))) (cons (cons key value) (cdr alist))) (t (cons (car alist) (insert key value (cdr alist)))))) (define (cf-constraint c f) (lambda (state) (let ((cv (lookup c state)) (fv (lookup f state))) (cond ((and cv (not fv)) (insert f (+ (/ (* 9 cv) 5) 32) state)) ((and fv (not cv)) (insert c (/ (* 5 (- fv 32)) 9) state)) (t state))))) (define (apply-constraints constraints state) (if (null? constraints) state (apply-constraints (cdr constraints) ((car constraints) state)))) (define (iterate-until-stable f state limit) (if (= limit 0) state (let ((next (f state))) (if (equal? next state) state (iterate-until-stable f next (- limit 1)))))) (lookup 'F (iterate-until-stable (lambda (st) (apply-constraints (list (cf-constraint 'C 'F)) st)) (list (cons 'C 100) (cons 'F nil)) 10))===
(define (lookup key alist)
  (cond ((null? alist) nil)
        ((eq? key (car (car alist))) (cdr (car alist)))
        (t (lookup key (cdr alist)))))
(define (insert key value alist)
  (cond ((null? alist) (list (cons key value)))
        ((eq? key (car (car alist))) (cons (cons key value) (cdr alist)))
        (t (cons (car alist) (insert key value (cdr alist))))))
(define (cf-constraint c f)
  (lambda (state)
    (let ((cv (lookup c state)) (fv (lookup f state)))
      (cond ((and cv (not fv)) (insert f (+ (/ (* 9 cv) 5) 32) state))
            ((and fv (not cv)) (insert c (/ (* 5 (- fv 32)) 9) state))
            (t state)))))
(define (apply-constraints constraints state)
  (if (null? constraints) state
      (apply-constraints (cdr constraints) ((car constraints) state))))
(define (iterate-until-stable f state limit)
  (if (= limit 0) state
      (let ((next (f state)))
        (if (equal? next state) state (iterate-until-stable f next (- limit 1))))))
(lookup 'F (iterate-until-stable
             (lambda (st) (apply-constraints (list (cf-constraint 'C 'F)) st))
             (list (cons 'C 100) (cons 'F nil))
             10))

===exercise: 同じ constraint を使って F=32 を与えたときの C を返してください。 期待値は 0 (= 水の凝固点) です。 最終式: (lookup 'C (iterate-until-stable (lambda (st) (apply-constraints (list (cf-constraint 'C 'F)) st)) (list (cons 'C nil) (cons 'F 32)) 10)) スケルトン: (define (lookup key alist) (cond ((null? alist) nil) ((eq? key (car (car alist))) (cdr (car alist))) (t (lookup key (cdr alist))))) (define (insert key value alist) (cond ((null? alist) (list (cons key value))) ((eq? key (car (car alist))) (cons (cons key value) (cdr alist))) (t (cons (car alist) (insert key value (cdr alist)))))) (define (cf-constraint c f) (lambda (state) (let ((cv (lookup c state)) (fv (lookup f state))) (cond ((and cv (not fv)) (insert f (+ (/ (* 9 cv) 5) 32) state)) ((and fv (not cv)) (insert c (/ (* 5 (- fv 32)) 9) state)) (t state))))) (define (apply-constraints constraints state) (if (null? constraints) state (apply-constraints (cdr constraints) ((car constraints) state)))) (define (iterate-until-stable f state limit) (if (= limit 0) state (let ((next (f state))) (if (equal? next state) state (iterate-until-stable f next (- limit 1)))))) (lookup 'C (iterate-until-stable (lambda (st) (apply-constraints (list (cf-constraint 'C 'F)) st)) (list (cons 'C nil) (cons 'F 32)) 10))===
; F=32 から C=0 を導く双方向の例

===expect: F=32 → C=0 (凝固点)===
0

===solution: 同じ constraint を使って F=32 を与えたときの C を返してください。 期待値は 0 (= 水の凝固点) です。 最終式: (lookup 'C (iterate-until-stable (lambda (st) (apply-constraints (list (cf-constraint 'C 'F)) st)) (list (cons 'C nil) (cons 'F 32)) 10)) スケルトン: (define (lookup key alist) (cond ((null? alist) nil) ((eq? key (car (car alist))) (cdr (car alist))) (t (lookup key (cdr alist))))) (define (insert key value alist) (cond ((null? alist) (list (cons key value))) ((eq? key (car (car alist))) (cons (cons key value) (cdr alist))) (t (cons (car alist) (insert key value (cdr alist)))))) (define (cf-constraint c f) (lambda (state) (let ((cv (lookup c state)) (fv (lookup f state))) (cond ((and cv (not fv)) (insert f (+ (/ (* 9 cv) 5) 32) state)) ((and fv (not cv)) (insert c (/ (* 5 (- fv 32)) 9) state)) (t state))))) (define (apply-constraints constraints state) (if (null? constraints) state (apply-constraints (cdr constraints) ((car constraints) state)))) (define (iterate-until-stable f state limit) (if (= limit 0) state (let ((next (f state))) (if (equal? next state) state (iterate-until-stable f next (- limit 1)))))) (lookup 'C (iterate-until-stable (lambda (st) (apply-constraints (list (cf-constraint 'C 'F)) st)) (list (cons 'C nil) (cons 'F 32)) 10))===
(define (lookup key alist)
  (cond ((null? alist) nil)
        ((eq? key (car (car alist))) (cdr (car alist)))
        (t (lookup key (cdr alist)))))
(define (insert key value alist)
  (cond ((null? alist) (list (cons key value)))
        ((eq? key (car (car alist))) (cons (cons key value) (cdr alist)))
        (t (cons (car alist) (insert key value (cdr alist))))))
(define (cf-constraint c f)
  (lambda (state)
    (let ((cv (lookup c state)) (fv (lookup f state)))
      (cond ((and cv (not fv)) (insert f (+ (/ (* 9 cv) 5) 32) state))
            ((and fv (not cv)) (insert c (/ (* 5 (- fv 32)) 9) state))
            (t state)))))
(define (apply-constraints constraints state)
  (if (null? constraints) state
      (apply-constraints (cdr constraints) ((car constraints) state))))
(define (iterate-until-stable f state limit)
  (if (= limit 0) state
      (let ((next (f state)))
        (if (equal? next state) state (iterate-until-stable f next (- limit 1))))))
(lookup 'C (iterate-until-stable
             (lambda (st) (apply-constraints (list (cf-constraint 'C 'F)) st))
             (list (cons 'C nil) (cons 'F 32))
             10))
