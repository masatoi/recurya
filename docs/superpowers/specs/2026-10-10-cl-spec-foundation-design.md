# cl-spec 導入: 基盤 + ドメイン契約 (サブプロジェクト 0 + A) 設計

日付: 2026-10-10 / ブランチ: `feat/cl-spec-contracts`

## 背景と全体計画

cl-mcp の `cl-spec` ツール群 (`spec-list` / `spec-symbol` / `spec-describe` /
`spec-check`) を有効化した (`MCP_ENABLE_TOOL_GROUPS=cl-spec`, 9ae65b7)。
既存のスキーマ定義を cl-spec の契約で補強する。全体を次の順で段階的に進め、
各サブプロジェクトは独立した spec → plan → 実装サイクルを持つ。

| # | サブプロジェクト | 本書の範囲 |
|---|---|---|
| 0 | 基盤 (配置・Rove 統合・依存・フィードバックファイル) | ✅ |
| A | ドメイン `defstruct` と純粋関数 (game/notebook, notebook-parser, arena) | ✅ |
| B | JSONB `cells` の形と往復 | 別 spec |
| C | Mito `deftable` の値域 + `db/*` の Function Spec (recurya_test 分離) | 別 spec |

## 1. 配置 (サブプロジェクト 0)

```
specs/                          ; 本番 "recurya" は参照しない (本番に cl-spec を入れない)
  domain.lisp                   ; recurya/specs/domain — 共有値域 defspec
  game/notebook.lisp            ; recurya/specs/game/notebook — cell / test-case の Spec
  game/notebook-parser.lisp     ; recurya/specs/game/notebook-parser
  game/arena.lisp               ; recurya/specs/game/arena
  all.lisp                      ; recurya/specs/all — 上記を :import-from するだけの傘
tests/specs.lisp                ; recurya/tests/specs — Rove ハーネス
```

- `recurya` は `:pathname "./"` の package-inferred system なので、`specs/` 配下は
  `recurya/specs/...` で解決される。各契約ファイルは
  `(:import-from #:cl-spec/main ...)` と `(:import-from #:cl-spec/src/backends/check-it)`
  を持つ (cl-spec-driven-development.md §2 の推奨形)。
- `recurya/tests` の `:depends-on` に `"cl-spec/check-it"` と `"recurya/tests/specs"`
  を追加。`cl-spec/check-it` を明示するのは、`qlot install` の依存解決で
  `check-it` / `optima` を確実に入れるため (今回は手動取得が必要だった)。
- `.github/workflows/lint.yml` の mallet 対象パスに `specs/` を追加。

## 2. Rove ハーネス (`tests/specs.lisp`)

- **Property**: `cl-spec:list-properties` のうち、名前のホームパッケージが
  `RECURYA/SPECS/` で始まるものを `run-property :profile :smoke` で 1 件ずつ実行。
- **Function Spec**: Function Spec は対象関数のシンボルで命名されるため、
  `list-function-specs` のうち対象シンボルのホームパッケージが `RECURYA/` で
  始まるもの (例: `recurya/game/arena:parse-action`) を
  `check-function :trials 50` で実行。
- **合格条件**: status が `:passed` かつ試行数 > 0 (Function Spec は
  trials − rejected > 0)。`:skipped` (全入力が `:pre` で拒否) は不合格。
- **失敗時メッセージ**: 名前・status・seed・縮小後の反例を含め、
  `spec-check property=... seed=...` で再現できるようにする。
- 予算: ハーネス全体で数秒以内。

## 3. 契約の内容 (サブプロジェクト A)

期待値は docstring・既存テスト・要件から導き、実装のコピーにしない。

### 値域 (`specs/domain.lisp`)

- `cell-kind`: `(member :prose :code-eval :code-exercise :code-solution :scene)`
  — `cell` の docstring と `render-cell` の `ecase` から。
- `fence-kind`: `cell-kind` ∪ `(member :code-delim :expect)`
  — `parse-fence-header` の docstring から (sentinel 種別)。
- `arena-action`: `(member :up :down :left :right :wait :pickup)`
  — `*valid-action-strings*` から。
- `grid-position`: `(cons (integer 0 *) (integer 0 *))` 相当 (satisfies で表現)。

### 生成器 (`specs/game/notebook.lisp`)

- `test-case` 生成器: input は空 or 1 行、expected は 1 行、description は空 or
  1 行。いずれも改行・`===` を含まない英数字中心の文字列。
- 正規形 `cell` 生成器: kind ∈ `cell-kind`、本文は `===` で始まる行を含まない
  1〜4 行の文字列、`:code-exercise` は description (1 行) と 0〜3 件の test-case、
  `:code-solution` は description と gated-p (ランダム)。他 kind の description は `""`。
- 正規形 cells 生成器: 上記 cell を 1〜6 個。

### Function Spec

| 対象 | 契約 |
|---|---|
| `recurya/game/arena:parse-action` | 任意の値 → `arena-action`。`*valid-action-strings*` に (大小無視で) 一致する文字列はその keyword、それ以外は `:wait` (`:cases` で分岐) |
| `action->delta` | `:up/:down/:left/:right` → 対応する単位ベクトル `(dr . dc)` (\|dr\|+\|dc\|=1)、その他 → NIL |
| `apply-move` | 生成器で毎試行新しい grid (壁ランダム配置) と盤内・非壁の pos を作る。結果は (a) 盤内かつ非壁、(b) 元位置と manhattan 距離 ≤ 1、(c) 移動先が壁/盤外 or 非移動アクションなら元位置と等しい |
| `recurya/game/notebook-parser:parse-fence-header` | 任意の行: `===…===` に一致しない行 → 第1値 NIL。一致する場合の第1値は NIL か `fence-kind`。GATED-P が T なら KIND は `:code-solution` |

### Property

| 名前 | 主張 |
|---|---|
| `notebook-roundtrip` (`:about cells->body-md`) | 正規形 cells (上記生成器) について `(parse-notebook-body (cells->body-md cells))` が ERRORS 空で、各セルの (KIND BODY DESCRIPTION TEST-CASES GATED-P) が一致する。docstring が明言する往復性 |
| `manhattan-distance-metric` | 非負、対称、同一点で 0、三角不等式 |
| `copy-grid-independent` | コピーへの `grid-set!` が元 grid を変えず、コピー直後は全要素が等しい |

### 反例が出たとき

すぐには直さない。「実装バグ」か「契約 (生成器の値域) の誤り」かを切り分け、
ユーザーに報告して判断を仰ぐ。契約を弱めて緑にすることはしない。

## 4. フィードバックファイル

- 新設: `docs/feedback/cl-mcp-cl-spec.md` (git 管理)。
- エントリ書式: `## YYYY-MM-DD — <短い題>` + 箇条書き
  (ツール / 状況 / 何が起きたか / 期待 / 回避策 / 分類: bug・UX・docs・idea)。
- 初回エントリ:
  1. `cl-spec/check-it` の依存 `check-it` (と `optima`) が qlot で自動導入されず、
     `load-system` (ASDF のみ) では取得できない。`ql:quickload` で回避。
  2. curl による HTTP プローブで `initialize` 直後の `tools/list` が
     "Session expired or invalid" (404) になる。
- CLAUDE.md の「cl-mcp Feedback」節を、このファイルへ追記する指示に書き換える。
  既存 `~/.claude/memory/cl-mcp-feedback.md` (プロジェクト横断・18 件) は移行せず
  アーカイブとして残す。

## 5. 検証

1. `run-tests` で `recurya/tests/specs` が緑。全スイートも回帰なし。
2. `spec-list` で登録件数を確認 (Spec 4 / Function Spec 4 / Property 3 を想定)。
3. 有効性確認: ワーカー内で実装を一時的に壊し (repl-eval のみ、ファイルは不変)、
   ハーネスが赤になることを 1 度確認してから `load-system` で戻す。

## 範囲外

- JSONB cells の JSON 形 (B)、DB 行と `db/*` (C)。
- `parse-action` の実行時 `intern` などのスタイル指摘 (別途)。
