;;;; game/notebooks/sicp-3-3-5.lisp --- SICP 3.3.5 Constraint Propagation (fixed-point).

(defpackage #:recurya/game/notebooks/sicp-3-3-5
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-3-3-5-notebook))

(in-package #:recurya/game/notebooks/sicp-3-3-5)

(defun make-sicp-3-3-5-notebook ()
  "SICP 3.3.5 - Constraint propagation rewritten as fixed-point iteration over a connector alist."
  (make-notebook
   :id :sicp-3-3-5
   :chapter "3.3.5"
   :title "制約の伝播 (不動点反復版)"
   :summary "SICP 3.3.5 の双方向 mutation ベースの constraint network を、connector を alist で表し、すべての constraint を順に評価する関数を値が安定するまで反復する形に書き換える。摂氏 ↔ 華氏変換が双方向に動くことを確認。"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p (:strong "SICP 3.3.5")
                           " は制約ネットワーク (connector ↔ constraint の双方向 mutation) を扱います。"
                           "原典では各 connector が値を持ち、"
                           (:code "set-value!")
                           " / "
                           (:code "forget-value!")
                           " で更新を行い、関連する全 constraint に通知 (push-based) するモデル。")
                       (:p "WardLisp では値を持つ connector を "
                           (:strong "alist")
                           " で表し、すべての constraint を順に評価する関数を "
                           (:strong "値が安定するまで反復")
                           " する pull-based モデルにします。"
                           "未知の connector は "
                           (:code "nil")
                           " で表現し、片方が分かれば他方を埋める方式。")))
    (make-cell :id :design :kind :prose
               :body '(:div
                       (:p (:strong "摂氏 ↔ 華氏")
                           ": "
                           (:code "9C = 5(F − 32)")
                           " という関係式を 1 つの constraint としてモデル化します。"
                           (:code "C")
                           " または "
                           (:code "F")
                           " の片方が分かれば他方を導出できる、双方向の制約。"
                           (:code "cf-constraint")
                           " は state を受け取り、片方だけ既知なら他方を埋めた state を返す手続きです。")))
    (make-cell :id :forward-eval :kind :code-eval
               :body "(define (lookup key alist)
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
;; → 77 (= 25 * 9/5 + 32)")
    (make-cell :id :bidirectional :kind :prose
               :body '(:div
                       (:p (:strong "双方向性")
                           ": 上の constraint は "
                           (:code "C ⇒ F")
                           " も "
                           (:code "F ⇒ C")
                           " も両方できます。"
                           (:code "F=77")
                           " を与えれば "
                           (:code "C=25")
                           " が出ます。"
                           "constraint 自体は対称な定義になっており、どちらの方向に伝播するかは "
                           (:strong "どの connector が初期値を持っているか")
                           " で決まります。")))
    (make-cell :id :reverse-eval :kind :code-eval
               :body "(define (lookup key alist)
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
;; → 25")
    (make-cell :id :compare :kind :prose
               :body '(:div
                       (:p (:strong "比較")
                           ": SICP 原典は connector が「自分の値が決まったら全 constraint に通知する」 "
                           (:strong "push-based")
                           " モデル。"
                           "WardLisp 版は全 constraint を毎回チェックする "
                           (:strong "pull-based")
                           "。"
                           "漸近計算量は劣る (constraints × iterations) ですが、教育目的では十分。"
                           "値が一度決まれば次の反復で変化しないので、"
                           (:code "iterate-until-stable")
                           " は素直に固定点に収束します。")))
    (make-cell :id :ex-cf-fwd :kind :code-exercise
               :description
               "cf-constraint / apply-constraints / iterate-until-stable を実装し、C=100 を与えたときの F を返してください。
期待値は 212 (= 100 * 9/5 + 32) です。
最終式:
  (lookup 'F (iterate-until-stable
               (lambda (st) (apply-constraints (list (cf-constraint 'C 'F)) st))
               (list (cons 'C 100) (cons 'F nil))
               10))
スケルトン:
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
               10))"
               :body "; (define (lookup key alist) ...)
; (define (insert key value alist) ...)
; (define (cf-constraint c f) ...)
; (define (apply-constraints constraints state) ...)
; (define (iterate-until-stable f state limit) ...)
; (lookup 'F (iterate-until-stable ...))
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "212"
                                     :description "C=100 → F=212 (沸点)")))
    (make-cell :id :ex-cf-rev :kind :code-exercise
               :description
               "同じ constraint を使って F=32 を与えたときの C を返してください。
期待値は 0 (= 水の凝固点) です。
最終式:
  (lookup 'C (iterate-until-stable
               (lambda (st) (apply-constraints (list (cf-constraint 'C 'F)) st))
               (list (cons 'C nil) (cons 'F 32))
               10))
スケルトン:
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
               10))"
               :body "; F=32 から C=0 を導く双方向の例
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "0"
                                     :description "F=32 → C=0 (凝固点)"))))))
