# cl-spec 導入: 残り 3 テーブル (users / novel-state / learn-submission) の契約 (サブプロジェクト D) 設計

日付: 2026-10-11 / ブランチ: `feat/cl-spec-db-rest`
前提: サブプロジェクト 0 + A、B、C (`2026-10-11-cl-spec-db-design.md`) が main にマージ済み。
配置・ハーネス・合格条件・DB 隔離 (`with-test-db`) はそれらに従う。

## ユーザー決定

- 範囲は C で後回しにした 3 テーブル (`users`、`novel_state`、`learn_submission`) の DB 層。
- DB に触る契約は C と同じく **Property** (試行の本体で `with-test-db`)。純粋関数は Function Spec。
- **F-D1** は「仮ハンドルの形を予約扱いにする」で直す。
- **F-D2** は「フラグ値の往復を保証する」。フラグ値の型は T / NIL / 整数 / 文字列 / シンボル。
  リストなどそれ以外の値は **set-flag の時点でシーンエラー** にする (wardlisp の `:bindings` が
  リストを受け付けないため。リスト対応は wardlisp 本体の変更が要り、範囲外)。
- メールアドレスの大文字・小文字を区別する統合 (F-D3) は **今回は直さない**。
- `deftable` は変更しない。

## 1. 判明事項 (2026-10-11)

- **F-D1** `valid-handle-p` の正規表現 `\A[a-z0-9][a-z0-9-]{1,62}[a-z0-9]\z` は
  `u-deadbeef` のような仮ハンドルの形 (`u-` + 小文字 16 進 8 桁) を通し、予約語でもない。
  オンボーディングでこの形を選ぶと保存は成功するが、`require-real-handle` が仮ハンドルと
  判定して毎回 `/onboarding/handle` にリダイレクトする。`placeholder-handle-p` の docstring
  「Real handles ... never match this pattern」とも矛盾する。→ 直す。
- **F-D2** novel のフラグ値が保存・注入で壊れる (REPL で確認):
  - 保存 (`%alist->ht` → jzon) でキーワード `:happy` は文字列 `"HAPPY"`、リスト `(1 2)` は
    ベクタ `#(1 2)` になって読み戻される。
  - `%flag->binding` はキーワード値をそのまま wardlisp に渡し、wardlisp は
    `:bindings: unsupported value` で失敗する (ベクタも同じ)。
  - その結果、シンボル値のフラグは次のシーンで別の値 (文字列) になり、リスト値のフラグは
    次のシーンの評価でエラーになる。
  - set-flag の名前がシンボルでない場合 (文字列・整数)、保存時の `symbol-name` で TYPE-ERROR。
  → 直す。
- **F-D3** (記録のみ) `find-or-create-oauth-user` のメール統合は大文字・小文字を区別する
  (`get-user-by-email` の docstring どおり)。GitHub が大文字混じりのアドレスを返すと別アカウントに
  なりうる。`admin-email-p` は区別しない。
- **F-D4** (記録のみ) メールアドレスなしの OAuth ユーザーは email `""` で作られ、2 人目は一意制約
  違反になる。`oauth-callback-handler` がメールなしを 400 で弾くため、現状は起きない。
- **F-D5** (記録のみ) 仮ハンドルは UUID の先頭 8 桁で、衝突すると insert が一意制約違反になる。
- **F-D6** (記録のみ) ログインしていない読者のフラグは保存されない。シーンの評価エラーは
  ハンドラで捕まえず 500 になる。
- `learn_submission.created_at` は DB にマイクロ秒で入る (実測)。`cell-submissions` の
  `ORDER BY created_at DESC` は連続した記録を区別できる (DAO の読み出しが秒単位なのは C の
  F-C 系と同じだが、並び順は SQL 側で決まる)。

## 2. 本番コードの変更

契約を先に書いて赤を確認してから直す。

### F-D1

- `placeholder-handle-p` を `recurya/utils/handle` に移す (正規表現 `\Au-[a-f0-9]{8}\z`)。
  `recurya/db/users` はそれを import して今までどおり export する (`web/auth` と既存の契約は
  同じシンボルを参照し続ける)。
- `reserved-handle-p` は「小文字にした文字列が予約語の表にある、**または仮ハンドルの形**」で T。
  docstring を更新する。オンボーディングは既存の「予約済み」エラー (400) を返す。

### F-D2

- **フラグ値の型** (`flag-value`): `T`、`NIL`、整数、文字列、キーワード。
- `recurya/game/novel/interpreter:interpret-directives`: `:set-flag` の名前がキーワードでない、
  または値が `flag-value` でないとき、新しい condition `invalid-flag-error` (同パッケージで定義・
  export、`error` のサブクラス、名前と値を保持) を signal する。値を省略した set-flag は従来どおり T。
- `recurya/db/novel`:
  - 保存形式の書き出しを内部関数 `%flags->json` (FLAGS alist → JSON 文字列) に切り出す
    (DB なしの Property が同じ書き出しを使うため)。
  - 保存: キーワード値は JSON オブジェクト `{"symbol": "<小文字の名前>"}`、それ以外は従来どおり
    (T → `true`、NIL → `false`、整数、文字列)。
  - 読み戻し (`novel-state-flags-alist`): `true` → T、`false` → NIL、整数、文字列、
    `{"symbol": 文字列}` → キーワード (大文字化して intern)。それ以外 (配列、浮動小数、`null`、
    `symbol` 以外のオブジェクト、旧データのベクタ) はそのフラグごと捨てる。
    flags 列が JSON オブジェクトでないときは NIL (従来どおり)。
  - docstring に保存形式と受け付ける値を書く。
- `recurya/game/novel/eval:%flag->binding`: キーワード値は小文字の名前の文字列 (wardlisp の
  シンボル) にして渡す。文字列は従来どおり boxed string。

## 3. 配置

```
specs/db/domain.lisp     ; submission-status を追加
specs/db/users.lisp      ; recurya/specs/db/users (新設)
specs/db/novel.lisp      ; recurya/specs/db/novel (新設、DB の往復と upsert、保存形式→注入の往復)
specs/game/novel.lisp    ; recurya/specs/game/novel (新設、純粋: flag-value 値域と set-flag 検査)
specs/db/learn.lisp      ; 提出履歴の Property を追加
specs/all.lisp           ; 上記を追加
tests/specs/contracts.lisp ; 期待リストに追加
```

## 4. 値域

| 名前 | 定義 | 根拠 |
|---|---|---|
| `submission-status` | `(member "pass" "fail" "error")` | `run-exercise-cell` の status を `string-downcase` したもの |
| `flag-value` | `T`、`NIL`、整数、文字列、キーワード | F-D2 の決定 |

生成器は文字列に空・改行・`"`・`\`・非 ASCII を混ぜる。フラグ名は `[a-z][a-z0-9-]{0,11}` から
作ったキーワード (wardlisp の読み取りと同じく大文字化)。シンボル値の名前も同じ形。

## 5. 契約

期待値は生成器が持つ「計画」とリテラル表・独立した正規表現から計算し、対象関数を呼ばない。

### users

**Property `user-create-get-roundtrip`** (`:about create-user! get-user-by-id get-user-by-email get-user-by-handle`)
ランダムな email (一意)、ハンドル (`valid-handle-p` を満たし予約語でない形)、display-name
(NIL または `varchar-255`)、role (`"user"`/`"admin"`)、password (NIL または文字列) で作ると、
id・email・handle のどれで引いても同じ id の行が返り、各欄は与えた値と一致する。
display-name が NIL なら email。存在しない email / handle、空のハンドル、NIL は NIL。

**Property `oauth-login-resolution`** (`:about find-or-create-oauth-user`)
生成器: プロバイダ 2 種 × ユーザー ID 3 個の ID 表 (各 ID のメールは 3 個のメールから固定で
選ぶ)、前もって `create-user!` で作る既存ユーザー 0〜2 人 (メールは最初の 2 個から、display-name は
`""` または空でない文字列)、ログイン列 1〜8 件 (各ログインは ID 表の 1 件と display-name)。
各ログインの後:
1. 返るユーザーの provider / provider-uid はそのログインのもの。
2. 同じメールのログインは (既存ユーザーを含めて) 同じ id、違うメールなら違う id。
3. users の行数 = 既存ユーザー数 + 既存ユーザーにないメールの種類数 (それまでに出たもの)。
4. 新しく作られたユーザーのハンドルは `placeholder-handle-p` を満たし、display-name は
   ログインの display-name (NIL ならメール)。
5. 既存ユーザーの display-name は、ログインがメール統合で新しい ID を結び付けたとき
   (すでに結び付いている ID の再ログインではないとき) に、`""` だった場合だけログインの
   display-name (NIL でなければ) に変わる。それ以外では変わらない (`find-or-create-oauth-user`
   の docstring の手順 2 だけが display-name を埋める)。

**Property `user-update-partial`** (`:about update-user!`)
ユーザーを 1〜2 人作り、6 個のキー (password-hash、password-salt、display-name、role、language、
timezone) のランダムな部分集合に新しい値を渡すと、渡したキーだけが変わり、他の欄・他のユーザーは
変わらない。存在しない UUID なら NIL を返し、どの行も変わらない。

**Function Spec `reserved-handle-p`**
入力: 予約語 (大小混在を含む)、仮ハンドルの形 (大小混在を含む)、その近似 (桁数違い、`u_`、16 進
以外の文字)、ランダムな文字列、文字列以外。`:cases` で
- 文字列で、小文字にした値が予約語のリテラル表にある、または `\Au-[a-f0-9]{8}\z` に一致 → T
- それ以外 → NIL

**Property `placeholder-handle-never-real`** (`:about valid-handle-p reserved-handle-p placeholder-handle-p`)
任意の文字列 S について、「オンボーディングが受け付ける」(`valid-handle-p` かつ
`reserved-handle-p` でない) と `placeholder-handle-p` が同時に成り立たない。生成器は仮ハンドルの
形を多く含める。

### novel-state

**Property `novel-state-roundtrip`** (`:about upsert-novel-state get-novel-state novel-state-flags-alist`)
一意な名前のフラグ 0〜5 個 (値は `flag-value`) と scene-index (0〜20) で新規に upsert すると、
`get-novel-state` の行の scene-index が一致し、`novel-state-flags-alist` が元のフラグと
集合として一致する (`equal` で比較、順序は問わない)。

**Property `novel-state-upsert-sequence`** (`:about upsert-novel-state get-novel-state`)
ユーザー 2 人 × ノートブック 2 冊への upsert 列 1〜8 件 (各件の flags は NIL またはフラグ列、
scene-index は NIL または整数)。列の後、(ユーザー, ノートブック) ごとに:
1. 行は upsert があった組にだけ、ちょうど 1 つ。
2. flags は、その組への upsert のうち最後に NIL でない flags を渡したものの値。
   なければ空。
3. scene-index は最後に NIL でない scene-index を渡したものの値。なければ 0。

**Property `persisted-flags-drive-next-scene`** (`:about novel-state-flags-alist eval-scene`) — DB なし
フラグ (名前と `flag-value`) について、保存形式に書いて行オブジェクト (`make-instance`、DB には
書かない) から `novel-state-flags-alist` で読み戻し、その alist を `eval-scene` に渡して
「`(equal? <名前> <値のリテラル>)` を `say` で返すシーン」を評価すると、結果が真。
リテラル: T → `t`、NIL → `nil`、整数 → 10 進、文字列 → エスケープした文字列リテラル、
キーワード → `'<小文字の名前>`。

**Function Spec `interpret-directives`** — 範囲は set-flag の検査に絞る
入力: `say` / `narrate` / `bg` と set-flag を混ぜたディレクティブ列。set-flag の名前は
キーワード / 文字列 / 整数、値は省略 / `flag-value` / リスト。`:cases` で
- すべての set-flag が「名前がキーワード、値が省略か `flag-value`」 → 2 値目の SET-FLAGS は
  set-flag を出現順に `(名前 . 値)` (省略は T) にしたもの
- それ以外 → `invalid-flag-error` を signal

### learn-submission

**Property `submission-history`** (`:about record-submission cell-submissions`)
ユーザー 2 人 × ノートブック 2 冊 × セル 2 つへの提出列 1〜10 件 (code は任意の文字列、status は
`submission-status`) と limit (1〜12)。記録の後、各組について
`(cell-submissions user notebook cell :limit k)` の (code status) 列は、その組への提出を新しい順に
並べた先頭 k 件と一致する (他の組の行は混ざらない)。limit を省略すると 50 件まで (列が 10 件以下
なので全件)。

## 6. 検証

1. `run-tests recurya/tests/specs/contracts` が緑。全スイートも回帰なし。mallet で警告なし。
2. 修正前の赤: F-D1 (`placeholder-handle-never-real`、`reserved-handle-p`) と F-D2
   (`novel-state-roundtrip`、`persisted-flags-drive-next-scene`、`interpret-directives`) が
   修正前に失敗することを記録する。
3. ミューテーション (repl-eval のみ、ファイルは不変) でハーネスが赤になることを確認:
   - F-D1 の修正を戻す (`reserved-handle-p` を表だけにする)
   - F-D2 の修正を戻す (保存をシンボル型なしに、`%flag->binding` をそのまま渡しに)
   - `cell-submissions` の並び順を昇順にする / limit を無視する
   - `update-user!` が渡されなかったキーも NIL で上書きする
   - `find-or-create-oauth-user` がメール統合をしない (常に新規作成)

## 検証結果

- 契約: Function Spec 2 (`reserved-handle-p`、`interpret-directives`)、Property 8
  (users 4、novel 3、learn 1)、値域 defspec 2 (`flag-value`、`submission-status`)。
- 変更前に赤: reserved-handle-p (failed、`"u-2f5dc2a4"`、seed 2753988324592681474)、
  placeholder-handle-never-real (failed、`"u-3ecc264c"`、seed 138502751629525869)、
  interpret-directives (failed、missing-condition: `#(1 2)` の set-flag が正常に戻った、
  seed 2323234822219805033)、persisted-flags-drive-next-scene (failed、seed 4425964474268112090)、
  novel-state-roundtrip (failed、seed 2018854177587134707)、
  novel-state-upsert-sequence (failed、seed 1023599225378170862)。変更後に緑
  (seed 付き再実行で digest 一致、続けて seed なしでも pass)。
  なお persisted-flags-drive-next-scene は計画では `eval-scene` に `:flags` を渡しておらず
  (そのままだと別の error になる)、実装側で docstring どおり `:flags read-back` を足した。
- ミューテーション (ワーカー上で再定義し unwind-protect で復元、ファイルは無変更。すべて `:passed` にならず検出):
  - `reserved-handle-p` を予約語リストのみに → Function Spec 300 trials failed、placeholder-handle-never-real `:normal` failed
  - `%flag-value->json` を恒等に → persisted-flags-drive-next-scene `:normal` failed、novel-state-roundtrip `:smoke` failed
  - `%flag->binding` が keyword をそのまま渡す → persisted-flags-drive-next-scene `:normal` error (wardlisp が keyword 束縛を拒否)
  - `interpret-directives` を Task 3 以前の本体に → Function Spec 300 trials failed
  - `cell-submissions` が `(reverse ...)` → submission-history `:normal` failed
  - `cell-submissions` が `:limit` を無視 (常に 50) → submission-history `:normal` failed
  - `update-user!` が常に `:language "ja"` も渡す → user-update-partial `:normal` failed
  - `find-or-create-oauth-user` から email 分岐を除去 → oauth-login-resolution `:normal` error (email 重複の DB 制約違反)
  - 復元後 `recurya` / `recurya/specs/all` を再ロードし、契約ハーネス 3 passed / 0 failed。
- 全スイート: 478 passed / 0 failed (`recurya/tests`、10976ms)、契約ハーネス 3 passed / 0 failed、所要 4107ms。
  mallet: 変更した Lisp ファイル 17 本で `No problems found.`
- 契約ハーネスの注記: Task 1 で `placeholder-handle-p` を移動した際、`tests/specs/contracts.lisp` の expected-function-specs が旧パッケージ名 `RECURYA/DB/USERS` のままでも通った (再エクスポートされた同一シンボルに解決されるため)。名前の古さは検出されないが、契約の登録自体は正しい。
