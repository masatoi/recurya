# cl-spec 導入: JSONB `cells` の形と往復 (サブプロジェクト B) 設計

日付: 2026-10-11 / ブランチ: `feat/cl-spec-jsonb`
前提: サブプロジェクト 0 + A (`2026-10-10-cl-spec-foundation-design.md`) が main にマージ済み。
配置・ハーネス・合格条件はその設計に従う。

## 背景

notebook の `cells` JSONB 列は `body_md` のパース結果のキャッシュで、次の経路を通る。

```
保存: body-md → parse-notebook-body → cell->jsonb-form → jzon stringify → DB
読出: DB → parse-json (jzon) → jsonb-hash->cell → cell struct
編集: 読出結果を parse-notebook-body の EXISTING-CELLS に渡し、cell-id を引き継ぐ
```

同じ JSON はエディタ JS (`resources/static/js/cell-editor.js`) の `data-cells` にもなる。
cell-id は学習者の進捗・保存コードのキーなので、編集で ID が変わると進捗が失われる。

## 範囲

- 対象: `recurya/game/notebook-jsonb` の `cell->jsonb-form` / `jsonb-hash->cell`、
  jzon による JSON 文字列往復、`parse-notebook-body` の ID 引き継ぎ、
  `cells->body-md` のセル区切り (A からの引き継ぎ)。
- 範囲外: DB 行と `db/*` (C)、エディタ JS (node テストの担当)、
  `web/routes` の `cells->cells-json`。

## 1. 配置

```
specs/game/notebook.lisp        ; 生成器を追加 (整形済みセル・保存形の文字列片)
specs/game/notebook-jsonb.lisp  ; 新設 recurya/specs/game/notebook-jsonb (`stored-hash`・`id-edit-scenario` もここ)
specs/all.lisp                  ; 上記を追加
tests/specs/contracts.lisp      ; 期待リストに追加
```

## 2. 生成器

- **整形済みセル** (`stored-cell`): kind ∈ `notebook-cell-kind`。id は NIL または空文字を含む任意の
  文字列 (実データの id は UUID 文字列。keyword id は範囲外)。body / description / test-case の各欄は任意の文字列 (空、改行、`"`、`\`、
  タブ、非 ASCII、`===` で始まる行を含む)。test-cases は 0〜3 件、gated-p はランダム。
  JSON 層はどんな文字列も保つべきなので、パーサの正規形より広い。
  kind ごとの欄の制約 (A の canonical) は課さない: JSONB は欄をそのまま保存するため。
- **保存形ハッシュ** (`stored-hash`): JSON テキストを組み立てて `parse-json` で読む
  (jzon の実際の値表現を使うため)。各キーを独立に「正常値 / 欠損 / `null`」にする。
  `kind` は既知 5 種 / `""` / 未知の文字列 / `null` / 欠損、`gated` は
  `true` / `false` / `null` / `"false"` (既存のレガシー値) / 欠損、`test-cases` は
  配列 / `null` / 欠損 (配列要素の各欄も同様に正常・欠損・`null`)。
- **編集シナリオ** (`id-edit-scenario`): `(CELLS NEW-CELL POSITION)` を返す。CELLS は
  一意な id (`id-0`, `id-1`, ...) を付けた正規形セル 1〜6 件 (3 回に 1 回は 1 件を複製)、
  NEW-CELL は照合キーが CELLS のどれとも異なる正規形セル (半分は近似重複)、
  POSITION は挿入位置。

## 3. 契約

### Function Spec `cell->jsonb-form`

- 入力: `stored-cell`。
- 結果はハッシュテーブルで、キーはちょうど `cell-id kind body description gated test-cases`。
- `kind` はリテラル表 (`:prose`→`"prose"` … `:code-solution`→`"code-solution"`) と一致。
- `cell-id` は id (NIL なら `""`)、`body` / `description` はセルの値と `string=`。
- `gated` は T / NIL で `cell-gated-p` と一致。
- `test-cases` はリストで、各要素はキーがちょうど `input expected description` の
  ハッシュ。値は元の test-case と一致し、順序も保つ。

### Property `cell-jsonb-roundtrip` (`:about cell->jsonb-form`)

`stored-cell` について
`(jsonb-hash->cell (parse-json (json->string (cell->jsonb-form cell))))` が
(ID KIND BODY DESCRIPTION TEST-CASES GATED-P) すべてで元と一致する
(ID は `(or id "")` と比較: NIL の id は `""` として保存される)。
test-cases が空 (jzon は `false` を出す)、gated NIL の場合を含む。

### Function Spec `jsonb-hash->cell`

- 入力: `stored-hash`。
- 結果は `cell`。kind は必ず `notebook-cell-kind`。
- 各欄: 有効な値 (文字列) があればその値、欠損・`null` なら既定値
  (id / body / description は `""`、test-cases は空リスト)。
- kind: 5 種の名前に大小無視で一致すればその keyword (現行の string-upcase による受理を保つ)。`""`・未知・`null`・欠損は `:prose`
  (現状の「空なら :prose」を延長。描画側は `ecase` なので未知 keyword は描画で落ちる)。
- gated-p: JSON `true` のときだけ T。`false`・`null`・`"false"`・欠損は NIL。
- test-cases: 配列の各要素を順に test-case にし、欄の欠損・`null` は `""`。
- 期待値はすべて生成器が保持する「元の JSON の意図」から計算し、実装を呼ばない。

### Property `edit-preserves-cell-ids` (`:about parse-notebook-body`)

`id-edit-scenario` の CELLS を JSONB 往復させたものを EXISTING-CELLS とし、
ランダムな位置に新しい正規形セルを 1 つ挿入した本文を `parse-notebook-body` に渡すと:

1. ERRORS が空。
2. 既存セルは元の ID を順序どおり保つ。
3. 新しいセルの ID は空でなく、既存の ID のどれとも異なる。
4. 結果の ID はすべて一意。

新しいセルは既存セルと同一内容にならないよう生成する (同一内容だと既存 ID を
引き継ぐのが仕様どおりの挙動であるため)。

### Property `body-md-cell-separator` (`:about cells->body-md`)

正規形セル列について:

- `(cells->body-md cells)` は各セルを単独で描画した `(cells->body-md (list cell))` を
  `"\n\n"` で連結したものと等しい。
- 単独の描画は改行で始まらず、改行で終わらない。

## 4. 本番コードの変更

契約を先に書いて赤を確認してから直す。

- `jsonb-hash->cell`:
  - JSON `null` (jzon ではシンボル `NULL`) を欠損と同じに扱う。
  - kind を実行時 `intern` せず、5 種の対応表で引く。対応しないものは `:prose`。
  - 受け付ける入力と既定値を docstring に書く。
- `utils/common:parse-json` の docstring を実際の値表現に直す
  (JSON null はシンボル `NULL`、false は NIL)。

## 5. 検証

1. `run-tests recurya/tests/specs/contracts` が緑。全スイートも回帰なし。
2. ミューテーション (repl-eval のみ、ファイルは不変) でハーネスが赤になることを確認:
   - `jsonb-hash->cell` を変更前の実装に戻す
   - `cell->jsonb-form` から `gated` を落とす
   - `take-matching-cell-id` の照合を壊す (description を無視する、など)
   - `cells->body-md` のセル間を改行 1 つにする

## 判明事項 (2026-10-11)

- **F-B1** `jsonb-hash->cell` は JSON `null` を扱えない。`"description": null` と
  `"test-cases": null` で TYPE-ERROR、`"gated": null` で gated-p が T、
  `"body": null` で body がシンボル `NULL` になる。jzon は JSON null をシンボル
  `NULL` (真) として返すため。現在の `cell->jsonb-form` は null を書かないので、
  起きうるのはレガシーデータ・import スクリプト・手作業の投入の場合。→ 本サブプロジェクトで修正する
  (ユーザー決定: 欠損/null に強い契約)。
- **F-B2** 未知の kind 文字列は実行時 `intern` でそのまま keyword になる (`:bogus`)。
  → `:prose` に倒す。
- **gated の真値**: 変更前は `"true"` や数値など JSON `true` 以外の真値も gated (非表示) と
  読まれたが、今は JSON `true` のみ T、他は NIL (fail-open)。`gated` キーは 43f40e8 で
  導入され T/NIL しか書かれなかったため、実データへの影響はない。
- **F-B3** `parse-json` の docstring は「JSON null は NIL」としているが、実際は
  シンボル `NULL`。→ docstring を直す。

## 検証結果

- 契約: Function Spec 2 (`cell->jsonb-form`, `jsonb-hash->cell`)、Property 3
  (`cell-jsonb-roundtrip`, `edit-preserves-cell-ids`, `body-md-cell-separator`)。
- `jsonb-hash->cell` は変更前に赤 (failed、seed 1862242823346440668: `gated` が null のテーブルが T として読まれた)、変更後に緑。
- ミューテーション (すべて failed、passed なし):
  - `jsonb-hash->cell` を変更前の本体に戻す: check-function 200 trials → failed
  - `cell->jsonb-form` から "gated" キーを除去: check-function 100 trials → failed
  - `take-matching-cell-id` が description を無視: `edit-preserves-cell-ids` smoke 5 回 → failed x5
  - `take-matching-cell-id` を last-fit に: smoke 3 回 → failed x3
  - `cells->body-md` が単一改行で連結: `body-md-cell-separator` smoke → failed
  - 復元後 `recurya/tests/specs/contracts` は 3/0 で通過。
- 全スイート: 471 passed / 0 failed。
