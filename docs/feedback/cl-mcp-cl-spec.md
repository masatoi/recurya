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
