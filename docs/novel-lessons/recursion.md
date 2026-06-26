===prose===
# アリスと階乗 — 再帰を物語で学ぶ

放課後の教室で、アリス先生が「再帰」を教えてくれます。下のシーンをクリックで
読み進めて、最後のエクササイズで `factorial` を完成させましょう。
（▶ ボタン / クリック / で進みます。通しで遊ぶには「▶ 再生」(/play) もどうぞ）

===scene===
(list
  (list 'bg "classroom")
  (list 'narrate "放課後の教室。アリスが黒板の前に立っている。")
  (list 'say "アリス" "今日は「再帰」を教えるわ。関数が自分自身を呼ぶことよ。")
  (list 'say "アリス" "例えば階乗。5! は 5 x 4 x 3 x 2 x 1 ね。")
  (list 'say "アリス" "これは factorial(5) = 5 x factorial(4) と書けるの。"))

===scene===
(list
  (list 'say "アリス" "でも、ずっと自分を呼び続けたら止まらないでしょ？")
  (list 'say "アリス" "だから「土台」が要るの。これがベースケース。")
  (list 'say "アリス" "factorial(0) は 1。ここで再帰が止まるのよ。")
  (list 'narrate "アリスは黒板に (if (= n 0) 1 ...) と書いた。"))

===scene===
(list
  (list 'say "アリス" "あとは「自分より小さい問題」に分けるだけ。")
  (list 'say "アリス" "factorial(n) = n x factorial(n-1)。これが再帰ステップ。")
  (list 'say "アリス" "さあ、下のエクササイズで factorial を完成させてみて！")
  (list 'set-flag 'ready-for-exercise))

===exercise: 階乗 factorial を完成させよう===
; ??? を埋めて factorial を完成させよう（ベースケースの戻り値は？）
(define (factorial n)
  (if (= n 0)
      ???
      (* n (factorial (- n 1)))))

===expect: 0 の階乗===
input: (factorial 0)
output: 1

===expect: 5 の階乗===
input: (factorial 5)
output: 120

===expect: 10 の階乗===
input: (factorial 10)
output: 3628800

===solution: 模範解答===
(define (factorial n)
  (if (= n 0)
      1
      (* n (factorial (- n 1)))))
