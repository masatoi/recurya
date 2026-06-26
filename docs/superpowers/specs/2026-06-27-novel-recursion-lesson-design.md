# ノベル教材「アリスと階乗」設計

> 作成日: 2026-06-27 / 対象ブランチ: `feat/novel-engine`
> 目的: 既存ノベルエンジン上に、再帰(factorial)を物語で教え、`===exercise===` で
> 理解度を確認する**実教材を1本**作る。併せて、シーンセルをノートブック画面に
> インライン・プレイヤーとして表示できるようエンジンを最小拡張する。

## スコープ

- **教材**: 公式コンテンツとして1ノートブック。`/@recurya/recursion`（再生は `.../play`）。
- **題材**: 再帰／階乗。導入 → ベースケース → 再帰ステップ → エクササイズ。
- **理解度テスト**: 既存 `===exercise===`/`===expect===`（コード自動採点）。
- 非スコープ: choice/jump、アセット、音声、インラインクイズ directive。

## 確定事項（ユーザー承認済み）

1. シーンはノートブック画面に**インライン・ノベルプレイヤー**として描画（再生リンクのみ版は不採用）。
2. **公式コンテンツとしてシード**（dev DB へ書き込み・boot で冪等復活）。

## コンポーネントと変更

### C1. `render-player` を一意 id でスコープ化（`web/ui/novel.lisp`）

現状の JS は `querySelector('.novel-player')` と固定 id（`novel-bg` 等）を使うため、
1ページに複数置くと先頭しか動かない。`render-player` に `&key (id "main")` を追加し、
コンテナ `id="novel-<id>"`・内部要素 `novel-bg-<id>` 等・JS を全て `<id>` でスコープ化。
`class="novel-player"` と `data-beats` は維持（既存 `web/novel-routes` テストの
`(search "novel-player" ...)` を壊さない）。play ルートは既定 id。

### C2. `render-cell` に `:scene` 分岐（`web/ui/notebook.lisp`）

現状 `render-cell` は `ecase` で `:scene` 未対応 → シーンを含むノートで**クラッシュ**。
`:scene` 分岐を追加し、`render-scene-cell` を新設:

- `eval-scene`（フラグ空・prelude なし）→ `interpret-directives` → `render-player`
  （セル index を id に）をインライン `(:raw ...)`。
- `handler-case`: wardlisp 評価失敗時は注意文（ページは壊さない）。
- 依存追加: `recurya/game/novel/eval`・`.../interpreter`・`recurya/web/ui/novel`。
- 前提: 本教材のシーンは**自己完結**（prelude 不要）に書く。

### C3. 教材コンテンツ（`docs/novel-lessons/recursion.md`）

body_md（上から）:

```
===prose===
# アリスと階乗 — 再帰を物語で学ぶ

放課後の教室で、アリス先生が「再帰」を教えてくれます。下のシーンをクリックで
読み進めて、最後のエクササイズで `factorial` を完成させましょう。
（▶ ボタン / クリック / Space / Enter で進みます）

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
```

### C4. 公式コース登録（`seed/official-content.lisp`）

`*official-courses*` に1件追加:

```lisp
(make-official-course
 :author-handle "recurya" :author-email "recurya+sicp@example.invalid"
 :author-display-name "Recurya"
 :slug "novel-lessons" :title "ノベルで学ぶ"
 :summary "物語仕立てで wardlisp / Lisp を学ぶミニ教材。"
 :content-dir #P"docs/novel-lessons/" :order :natural
 :notebook-title-fn (lambda (slug) (declare (ignore slug)) "アリスと階乗"))
```

→ boot 時に course `/c/@recurya/novel-lessons` と notebook `/@recurya/recursion`
（`recursion.md` の stem）を冪等生成。

## 検証（TDD）

新規 `tests/integration/novel-recursion-lesson.lisp`:

1. **コンテンツ構造**: `recursion.md` を `parse-notebook-body` → 3 scene / 1 exercise
   (test-case 3) / 1 solution、エラー無し。
2. **シーン演出**: 各 scene を `eval-scene`+`interpret-directives` → scene1 にアリスの
   セリフが含まれる、scene3 が `set-flags` に `(:ready-for-exercise . t)` を含む。
3. **エクササイズ正当性**: solution を wardlisp で評価し各 expect 入力が期待値に一致
   （`(factorial 0)`→1, `5`→120, `10`→3628800）。誤答（`???`→`0`）は不一致。
4. **ノートブック描画**: scene セルを含むノートを `render`（or `render-cell`）して
   例外なく `novel-player` を含む HTML を返す。

加えて `render-player` の id スコープ化は `web/ui/novel` レベルの小テストで担保。
全スイート再実行（回帰なし）＋ 手動 play スモーク。

## 実装インクリメント（各 RED→GREEN→commit）

1. C1: `render-player` の id スコープ化（小テスト RED→GREEN）。
2. C2: `render-cell` の `:scene` 分岐＋`render-scene-cell`（描画テスト）。
3. C3+C4: コンテンツファイル＋公式コース登録。
4. 検証テスト（統合）→ シード適用 → 全スイート → スモーク。
