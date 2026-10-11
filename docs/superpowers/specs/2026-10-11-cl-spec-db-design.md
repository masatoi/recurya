# cl-spec 導入: DB 層の契約 (サブプロジェクト C) 設計

日付: 2026-10-11 / ブランチ: `feat/cl-spec-db`
前提: サブプロジェクト 0 + A (`2026-10-10-cl-spec-foundation-design.md`) と
B (`2026-10-11-cl-spec-jsonb-cells-design.md`) が main にマージ済み。
配置・ハーネス・合格条件はそれらに従う。

## ユーザー決定

- DB に触れる契約は **Property** にする。純粋関数は Function Spec (Function Spec には
  試行前後の setup/teardown がなく、`spec-check` ツールから直接実行すると開発 DB =
  Web サーバと共有の接続に書き込むため)。
- 範囲は **進捗と順序に関わる部分を優先**: db/core の純粋関数、列の値域、
  course-notebooks、learn、notebooks/courses。users と novel は既存テストに任せ後続へ。
- F-C1 は **移動を「並び順で隣の行」との交換にする** で直す。
- `deftable` は変更しない。

## 1. DB 隔離

DB Property の本体は試行ごとに `recurya/tests/support/db:with-test-db` で囲む。

- `recurya_test` に接続し (キャッシュした専用接続を動的束縛)、前後にテストデータを
  消す。消去は `current_database()` が `recurya_test` でなければ拒否するガード付き。
- 束縛は試行の本体の中で行うので、`spec-check` が別スレッドで実行しても効く。
  Rove ハーネス (`run-property`) からも、`spec-check` ツールからも、開発 DB と
  Web サーバの接続に触れない。
- 試行内のデータは試行ごとに作り直す (生成器はデータ「計画」だけを返し、行の作成は
  本体の中で行う)。
- CI (`.github/workflows/ci.yml`) は PostgreSQL と `recurya_test` を用意済み。

## 2. 配置

```
specs/db/domain.lisp            ; recurya/specs/db/domain — 列の値域 defspec
specs/db/core.lisp              ; recurya/specs/db/core — 純粋関数の Function Spec
specs/db/course-notebooks.lisp  ; recurya/specs/db/course-notebooks
specs/db/learn.lisp             ; recurya/specs/db/learn
specs/db/notebooks.lisp         ; recurya/specs/db/notebooks (notebook と course)
specs/all.lisp                  ; 上記を追加
tests/specs/contracts.lisp      ; 期待リストに追加
```

## 3. 値域 (`specs/db/domain.lisp`)

| 名前 | 定義 | 根拠 |
|---|---|---|
| `publication-status` | `(member "draft" "published")` | `web/routes` `%decode-state-token` |
| `visibility` | `(member "private" "unlisted" "public")` | 同上と `notebook-update-handler` の許可リスト |
| `varchar-255` | 長さ 1〜255 の文字列 | `db/schema.sql` の `VARCHAR(255)` (title, slug) |
| `summary-text` | NIL または長さ 0〜500 の文字列 | `VARCHAR(500)` NULL 可 |

生成器は空でない短い文字列に加えて、最大長ちょうど・非 ASCII・引用符を含む文字列を出す。

## 4. 純粋関数の Function Spec (`specs/db/core.lisp`)

期待値はリテラル表・独立した正規表現から計算し、実装を呼ばない。

| 対象 | 契約 |
|---|---|
| `recurya/db/core:nil->null` | NIL → `:null`、それ以外はそのまま (`eq`) |
| `null->nil` | `:null` → NIL、それ以外はそのまま |
| `keyword->db-string` | `:cases`: NIL → NIL / keyword → 名前の小文字 / それ以外 → `type-error` を signal |
| `format-timestamp-for-db` | 結果は `^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{6}$` に一致し、UTC で読み戻すとマイクロ秒単位で同じ時刻 |
| `ensure-uuid` | 文字列は前後の空白 (#\Space) を除き小文字化、それ以外は `princ` 表記の小文字 |
| `uuid-string-p` | 8-4-4-4-12 の 16 進 (大小とも可) の 36 文字の文字列だけ T。生成器は正しい UUID と、1 文字変異・長さ違い・区切り位置違い・非文字列を出す |
| `recurya/db/users:placeholder-handle-p` | `u-` + 小文字 16 進 8 桁だけ T |

Property `generated-placeholder-handle-is-placeholder` (`:about placeholder-handle-p`):
`%generate-placeholder-handle` の結果は常に `placeholder-handle-p` を満たす。

## 5. DB の Property

### `course-notebook-order` (`:about move-notebook-up! move-notebook-down! remove-notebook-from-course! add-notebook-to-course!`)

生成器は 1 コース分の操作列 (8〜20 手) を返す。操作は「n 番目の未所属ノートブックを
追加」「k 番目を外す」「k 番目を上へ」「k 番目を下へ」。本体は試行ごとに作者・コース・
ノートブック 6 冊を作り、操作を順に適用し、Lisp のリスト (並び順のモデル) と比べる。

各操作の後:
1. `list-course-notebooks` のノートブック id の順序がモデルと等しい。
2. position が互いに異なる。
3. 上へ: 先頭なら NIL を返し何も変わらない。それ以外は T を返し、直前の行と入れ替わる。
   下へ: 末尾なら NIL、それ以外は T で直後と入れ替わる。
4. 外す: 所属していれば T、その行だけが消え、他の順序は保たれる。

現状は F-C1 により赤になる (削除で欠けた位置を越えて移動できない)。

### `learn-progress-is-a-set` (`:about mark-cell-passed user-passed-cells`)

2 ユーザー × 2 ノートブック × セル 4 個の範囲で、重複を含む合格記録の列を適用すると、
各 (ユーザー, ノートブック) の `user-passed-cells` は、その組で記録したセル id の
重複なし集合に等しい (順序は問わない)。`mark-cell-passed` は毎回 `learn-progress` 行を返す。

### `cell-code-last-write-wins` (`:about upsert-cell-code user-cell-codes`)

同じ範囲で (セル, コード) の書き込み列を適用すると、`user-cell-codes` は各セル 1 件で、
その組で最後に書いたコードを持つ。

### `merge-localstorage-rules` (`:about merge-localstorage`)

既存状態 (合格行・コード行) を作ってから、localStorage ペイロード (重複を含む passed、
codes) を merge すると:
- 合格は既存 ∪ ペイロード。
- コードは既存のセルは既存のまま (DB 優先)、新しいセルはペイロードの値。
  ペイロード内で同じセルが複数回あれば最初のもの。
- 戻り値 `(:passed-merged N :codes-merged M :codes-skipped K)` はモデルで数えた値と等しい。

### `notebook-create-get-roundtrip` / `course-create-get-roundtrip`

値域内の値で作成し `get-*-by-id` で取得すると、title / slug / summary / status /
visibility (と notebook の body-md、cells) がすべて等しく、作者 id が一致する。

### `notebook-slug-unique-per-author`

同じ作者が同じ slug で 2 冊目を作ると `dbi:dbi-database-error` を signal し、
別の作者なら作成できる。

### `notebook-list-filters` / `course-list-filters`

ランダムな状態・公開範囲・作者 (2 人) で 0〜8 件作り、ランダムな絞り込み
(status / author-id / visibility の部分集合) と offset / limit で `list-*` を呼ぶと:
- 絞り込みのみ (limit なし相当) の結果は、作成した行を Lisp で同じ条件でフィルタした
  id 集合と等しく、`created-at` の降順に並ぶ。
- `count-*` はその件数。
- offset / limit 付きの結果は、上の並びの部分列 `[offset, offset+limit)`。

### `notebook-update-partial` (`:about update-notebook!`)

作成後、ランダムな部分集合の項目 (NIL 以外の値) を `update-notebook!` に渡すと、
渡した項目は新しい値、渡さなかった項目は元の値のまま。

## 6. 本番コードの変更

契約を先に書いて赤を確認してから直す。

- **F-C1** `move-notebook-up!` / `move-notebook-down!`: 「position が ±1 の行」ではなく
  「同じコースで position が自分より小さい行のうち最大のもの / 大きい行のうち最小のもの」
  と position を交換する。トランザクションと一時値 -1 は維持。docstring と
  `remove-notebook-from-course!` の docstring (「欠けは移動で解消される」) を実態に合わせる。
- **F-C2** `update-notebook!` の docstring: CELLS に空リストを渡しても `(when cells ...)`
  で無視され書き込まれない。docstring の「空リストは "[]" になる」を事実に合わせる
  (挙動は変えない)。

## 7. ハーネスと検証

1. 期待リスト (`*expected-properties*` / `*expected-function-specs*`) に追加。
   DB Property の `:trials` は `(:smoke 20 :normal 100)` 程度。
2. `run-tests recurya/tests/specs/contracts` と全スイートが緑。
3. ミューテーション (repl-eval のみ、ファイルは不変) でハーネスが赤になることを確認:
   - F-C1 修正前の `move-notebook-up!` に戻す
   - `upsert-cell-code` を最初の書き込み優先にする
   - `merge-localstorage` のコードを localStorage 優先にする
   - `list-notebooks` の絞り込みを 1 つ外す

## 判明事項 (2026-10-11)

- **F-C1** コースから途中のノートブックを外すと position に欠けができ (例 0, 2)、
  `move-notebook-up!` は position-1 の行だけを探すため、欠けの下の行を上へ動かせない
  (NIL を返し続ける)。docstring の「欠けは後続の移動で解消される」は誤り。
  recurya_test で再現済み。→ 本サブプロジェクトで修正。
- **F-C2** `update-notebook!` の docstring は「CELLS の空リストは "[]" に直列化される」と
  するが、`(when cells ...)` のため空リストは無視される。ルートは空のセル列を
  パースエラーにするので実害はない。→ docstring を修正。
- **F-C3** `uuid-string-p` は `digit-char-p` で 16 進数字を判定していたため、
  アラビア・インド数字や全角数字 (例 U+0661, U+FF11) も受理し、PostgreSQL の UUID 型が
  拒否する値 (22P02) を DB まで通していた。契約の試作で発見。→ ASCII の 16 進数字だけを
  受理するよう修正。
- **F-C4 (テスト基盤)** cl-dbi は prepared statement 名を `(random (expt 36 8))` で作るため、
  cl-spec の seed 再実行 (固定 `*random-state*`) ではキャッシュ済みの `with-test-db` 接続で
  同じ名前が再生成され DBI 42P05 で衝突した。→ `with-test-db` が新しい
  `*random-state*` を束縛するよう修正 (9dbd914)。ジェネレータは本体の外で動くため seed の
  再現性は保たれる。

## 検証結果

- 契約: Function Spec 7 (db/core 6、db/users 1)、Property 11
  (仮ハンドル 1、course-notebooks 1、learn 3、notebooks/courses 6)、値域 defspec 4。
- 変更前に赤: uuid-string-p (failed、seed 3827825384193791716、300 trials)、
  course-notebook-order (failed、seed 3860745284530836394)。変更後に緑
  (uuid-string-p 300 trials、course-notebook-order normal 100 trials)。
- ミューテーション (ワーカー上で再定義し unwind-protect で復元、ファイルは無変更。すべて `:passed` にならず検出):
  - `upsert-cell-code` を先勝ちに → cell-code-last-write-wins `:smoke` failed (seed 4047042964791612174)
  - `merge-localstorage` が payload で上書き → merge-localstorage-rules `:smoke` failed (seed 219554440621438051)
  - `list-notebooks` が `:visibility` を無視 → notebook-list-filters `:normal` failed (seed 1607129162709553047)
  - `move-notebook-up!` を修正前の本体に → course-notebook-order `:normal` failed (seed 2991735439098915774)
  - `uuid-string-p` を `digit-char-p` 版に → Function Spec 300 trials failed (seed 1129218155036047944)
- 全スイート: 472 passed / 0 failed (`recurya/tests`、9167ms)、契約ハーネス 3 passed / 0 failed、所要 2917ms。
