# cl-mcp + cl-spec フィードバックログ

Recurya で cl-mcp (Common Lisp MCP サーバ) と cl-spec (契約/プロパティテスト) を
使った AI エージェント開発で遭遇した不具合・摩擦・改善案を蓄積する。
上流 (cl-ai-project/cl-mcp, masatoi/cl-spec) への報告材料にする。

## 書式

新しいエントリは末尾に追記する。既存エントリは書き換えない (解決したら
「解決:」行を足す)。

    ## YYYY-MM-DD — <短い題>
    - **ツール/対象**: cl-mcp `<tool>` / cl-spec `<API>` / qlot など
    - **分類**: bug | UX | docs | idea
    - **状況**: 何をしようとしていたか
    - **起きたこと**: 実際の挙動 (エラーメッセージは短く原文で)
    - **期待**: どうあってほしいか
    - **回避策**: その場でどう凌いだか (なければ「なし」)

---

## 2026-10-10 — cl-spec/check-it の依存が qlot で自動導入されない
- **ツール/対象**: qlot / cl-mcp `load-system` / cl-spec `cl-spec/check-it`
- **分類**: docs
- **状況**: qlfile に `git cl-spec ...` を追加し、`MCP_ENABLE_TOOL_GROUPS=cl-spec` で spec-* ツールを有効化した直後に `load-system cl-spec/check-it`。
- **起きたこと**: `Component "check-it" not found`。qlfile に `ql check-it :latest` を足して `qlot install` しても、次は `Component :OPTIMA not found`。`load-system` は ASDF のみで Quicklisp の自動取得をしないため、推移依存が入っていないと止まる。
- **期待**: cl-mcp README の cl-spec 節か cl-spec の README に「qlot 環境では check-it (と optima 等) を事前に入れる必要がある」旨、または `cl-spec-not-loaded` 応答に依存導入の手順ヒント。
- **回避策**: ワーカーで `(ql:quickload "cl-spec/check-it")` を 1 回実行 (依存を .qlot にダウンロード)。恒久策としてテストシステムの `:depends-on` に `"cl-spec/check-it"` を明記。

## 2026-10-10 — HTTP 直叩きで initialize 直後の tools/list が Session expired
- **ツール/対象**: cl-mcp HTTP transport (`/mcp`)
- **分類**: UX
- **状況**: コンテナ再作成後、curl で `initialize` → `notifications/initialized` → `tools/list` を送り、cl-spec ツールが列挙されるか確認しようとした。
- **起きたこと**: `initialize` は 200 + `Mcp-Session-Id` を返すが、同じ ID での後続リクエストが `{"code":-32600,"message":"Session expired or invalid"}` (404)。原因未特定 (singleton ワーカーモードとの関係か、ヘッダ要件か)。
- **期待**: 無効と判断した理由がエラーメッセージに出ること (未知 ID / 期限切れ / プロトコルヘッダ不足 などの区別)。
- **回避策**: Claude Code から `/mcp` で再接続して確認。

## 2026-10-10 — repl-eval で defpackage と後続フォームを同時送信すると新パッケージのシンボルが CL-USER に読まれる
- **ツール/対象**: cl-mcp `repl-eval`
- **分類**: UX
- **状況**: 試作で `defpackage` と `in-package`/`defun` 群を 1 回の `repl-eval` で送った。
- **起きたこと**: 仕様どおり全フォームが先に読まれるため、新パッケージのシンボルが CL-USER として読まれた (ツール説明には記載あり)。
- **期待**: 入力に `defpackage` を含む場合に「後続フォームは旧パッケージで読まれる」旨の警告。
- **回避策**: `defpackage` と本体を別の `repl-eval` 呼び出しに分け、`package` パラメータで指定。

## 2026-10-10 — 生成器の無い Spec (satisfies / symbol 等) を Property 引数に使うと GENERATOR-UNAVAILABLE
- **ツール/対象**: cl-spec / cl-mcp `spec-check`
- **分類**: idea
- **状況**: `satisfies` ベースの Spec を Property/Function Spec の引数に使った。Task 5 の探査でも `(type (integer 0 5))` が同じエラー (`no generator is registered for the type (INTEGER 0 5)`) になった。
- **起きたこと**: `GENERATOR-UNAVAILABLE` (メッセージは明快)。ただし `(integer 0 5)` 直書きは `unknown spec head`、`(type (integer 0 5))` は定義できるが実行時に生成器なし、と段階的に分かれて辿りにくい。
- **期待**: `spec-check` 応答に「`(:generator ...)` を付ける」「`integer-in` 等の登録済み Spec を参照する」ヒント。
- **回避策**: `defspec` に `(:generator ...)` を付けるか、生成器付きの登録済み Spec (例: grid-position) を参照。

## 2026-10-10 — custom generator 由来の反例は縮小されない
- **ツール/対象**: cl-spec `defgenerator` / `spec-check`
- **分類**: docs
- **状況**: 往復 Property の変異試験 (render-test-case が expected の代わりに input を出力) で反例を得た。
- **起きたこと**: shrinker が無く (`no-shrinker`)、反例が 4 セル・ネスト付きの大きな値のまま出る。原因の切り分けに読む量が多い。
- **期待**: `defgenerator` の `(:shrink ...)` の使い方の例 (docs)。
- **回避策**: なし (手で反例を読む)。

## 2026-10-10 — run-tests は系を force 再ロードするため、repl-eval による変異の寿命が読みにくい
- **ツール/対象**: cl-mcp `run-tests`
- **分類**: docs
- **状況**: ワーカー内だけで `apply-move` を壊して `run-tests` で検出を確認する変異試験。
- **起きたこと**: 説明には「force-reload from disk」とあるが、実際は対象テスト系のみが再ロードされ、依存先 (recurya/game/arena) の repl-eval 定義は保持された (変異が効いた)。この挙動は説明から読み取れない。
- **期待**: force 再ロードの範囲 (テスト系の自ファイルのみか、依存先を含むか) を説明に明記。
- **回避策**: 変異ごとに `spec-check function=` でも並行確認し、終了後は `load-system` で復元。

## 2026-10-10 — Function Spec の「全入力を :pre が拒否」は別経路 (skipped) で検出される: 運用メモ
- **ツール/対象**: cl-spec `defspec-function` / `spec-check function=`
- **分類**: docs
- **状況**: ハーネスが skipped / 有効試行ゼロを失敗扱いにするか確認する探査。
- **起きたこと**: `(:pre nil)` の使い捨て契約は `status=:SKIPPED` となりハーネスは FAIL した (期待どおり)。登録の取り消し API は無く、`pool-kill-worker reset=true` でしか戻せなかった。`defspec-function` の `:args` に `(integer 0 5)` を書くと `INVALID-SPEC-FORM` (エラー文は `(type ...)` を案内)。
- **期待**: Function Spec の登録解除 (unregister) API、または repl-eval 用の一時スコープ。
- **回避策**: ワーカー再作成 + `load-system`。

## 2026-10-10 — 変異「セル間の空行を出さない」は契約をすり抜ける (許容される変異)
- **ツール/対象**: recurya notebook-parser 契約 (cl-spec 利用の知見)
- **分類**: idea
- **状況**: `cells->body-md` をセル間 1 改行にする変異。
- **起きたこと**: `notebook-roundtrip` は緑のまま。パーサは空行なしでも受理するため、docstring の「ちょうど 1 つの空行」は契約外 (出力形式の仕様であり往復性質ではない)。別変異 (expected の代わりに input を出力) は赤になった。
- **期待**: 出力の正確な区切りまで縛りたいなら「render の出力が `\n\n===` で区切られる」旨の別 Property が必要 (サブプロジェクト B/C で検討)。
- **回避策**: なし。

## 2026-10-10 — トップレベルフォーム外のコメント (ファイルヘッダ) を編集する手段がない
- **ツール/対象**: cl-mcp `lisp-edit-form` / `lisp-patch-form` / `fs-write-file`
- **分類**: UX
- **状況**: 契約の生成器を広げたので、`specs/game/notebook.lisp` 冒頭の `;;;;` ヘッダコメント (canonical 形の説明) を実態に合わせて直したかった。
- **起きたこと**: `lisp-patch-form` はフォーム内だけが対象で `old_text not found in DEFPACKAGE ...`。`lisp-edit-form` はコメントのみの挿入はできるが既存コメントの置換・削除はできない。`fs-write-file` は `Cannot overwrite existing .lisp/.asd with fs-write-file; use lisp-edit-form.` で拒否 (ファイルはパース可能なので例外条件に当たらない)。
- **期待**: ファイル先頭/フォーム間のコメントブロックを対象にできる編集手段 (例: `lisp-patch-form` に `form_type: "comment"` やファイル単位のテキストパッチモード、またはパース検証付きの全体上書き)。
- **回避策**: スクラッチパッドにコメント行だけの unified diff を書き `git apply` で適用し、その後 `lisp-check-parens` と `load-system` で検証。

## 2026-10-11 — `load-system clear_fasls=true` がプロジェクト内 `.qlot/` の依存 FASL まで消し、ワーカーが壊れる
- **ツール/対象**: cl-mcp `load-system` (`clear_fasls`)
- **分類**: bug
- **状況**: レビュー指摘の修正後、cl-spec-driven-development.md §6 の手順どおり `load-system {"system":"recurya","clear_fasls":true}` で受け入れ用の再読み込みをした。
- **起きたこと**: qlot の依存は `<project>/.qlot/` にあるため「primary system のソースツリー配下の FASL」に依存ライブラリも含まれ、cl-dbi などが既にロード済みのワーカー内で再コンパイルされた。`The class <DBI-ERROR> is being redefined to be a DEFTYPE` などの full WARNING 16 件で `COMPILE-FILE-ERROR` になった。
- **期待**: `clear_fasls` は他プロジェクト (qlot/quicklisp の dist 配下、別 `.asd` のツリー) の FASL を除外してほしい。または、ロード済みの依存を消すことになる旨を事前に警告してほしい。
- **回避策**: `pool-kill-worker reset=true` → `load-system cl-spec/check-it` → `run-tests` (テストシステムは run-tests が強制再読込する)。このプロジェクトでは `clear_fasls` を使わない。

## 2026-10-11 — `:args` の引数名に他パッケージのシンボルを使うと `:post` の RESULT が解決できない
- **ツール/対象**: cl-spec `defspec-function`
- **分類**: docs
- **状況**: `(:args (cell stored-cell))` の `cell` が `recurya/game/notebook` から import したシンボルだった。
- **起きたこと**: `INVALID-FUNCTION-SPEC-FORM`: "cannot tell which symbol names the return value: :post uses RESULT, and the contract's own package resolves RESULT to RECURYA/GAME/NOTEBOOK::RESULT"。契約のパッケージは引数シンボルのホームパッケージから推定されるらしい。
- **期待**: 契約を書いたファイルの `*package*` で RESULT を解決する、またはエラー文で「引数名が別パッケージのシンボル」と直接指摘する。
- **回避策**: 引数名をローカルなシンボルにする (`input-cell`)。

## 2026-10-11 — ハッシュテーブルの反例が `#<hash-table ...>` としか表示されない
- **ツール/対象**: cl-spec `check-function` / `spec-check` の counterexample
- **分類**: UX
- **状況**: `jsonb-hash->cell` の契約は jzon がパースしたハッシュテーブルを引数に取る。
- **起きたこと**: 反例が `(table #<hash-table :TEST equal :COUNT 6 {...}>)` と表示され、中身が分からない。
- **期待**: ハッシュテーブル (や構造体以外の不透明オブジェクト) の中身を反例表示で展開する、または生成器が「表示用の表現」を添えられる仕組み。
- **回避策**: inspect-object で反例を辿る、または生成器の元 JSON テキストを別途再現する。

## 2026-10-11 — smoke の試行回数ではミューテーションを見逃す Property があった
- **ツール/対象**: cl-spec `defproperty` の `:trials` (recurya の契約設計の知見)
- **分類**: idea
- **状況**: `edit-preserves-cell-ids` を試作し、id 照合で description を無視する変異を入れた。
- **起きたこと**: 生成器が「description だけ違う近似重複」を作る確率が低く、smoke 50 回では緑のまま。:normal 300 回で初めて赤になった。近似重複を意図的に作る生成器に直し、smoke を 200 回にして 5 回連続で赤を確認。
- **期待**: ケースや「興味のある分布」の到達回数を Property でも報告する仕組み (Function Spec の case report に相当するもの)。
- **回避策**: 生成器で境界的な入力を明示的に作り、ミューテーションで感度を確かめる。

## 2026-10-11 — `defproperty` の `(:about ...)` に複数シンボルを書けることが docstring から読めない
- **ツール/対象**: cl-spec `defproperty` (`code-describe` で読む docstring)
- **分類**: docs
- **状況**: 往復 Property を `cell->jsonb-form` と `jsonb-hash->cell` の両方に紐づけたかった (独立レビューの指摘: `spec-check symbol=jsonb-hash->cell` が NO PROPERTIES になり、編集前のベースラインから往復が漏れる)。
- **起きたこと**: docstring は `(:ABOUT ...)` とだけ書き、例は 1 シンボル。`macroexpand-1` で `:TARGETS '(A B)` になることを確かめてから使った。
- **期待**: docstring に「`(:about sym1 sym2 ...)` で複数の対象に紐づけられる」と明記する。
- **回避策**: `macroexpand-1` で展開形の `:TARGETS` を確認する。
