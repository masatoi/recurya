# recurya CLI

ブラウザの代わりに端末とお好みのエディタでノートブックの演習を解くためのクライアント。
進捗 (保存コード・合格・解答の解放) は Web UI と共有される。

## 導入

前提: Roswell (`ros`)。

    git clone https://github.com/masatoi/recurya.git
    cd recurya
    ./roswell/recurya.ros                 # 使い方を表示。初回は依存 (dexador, jzon, ironclad, babel) を取得
    ros build roswell/recurya.ros         # 任意: roswell/recurya バイナリを作る

`roswell/recurya.ros` (またはビルドしたバイナリ) を PATH の通った場所にリンクする。

## ログイン

1. ブラウザで `<server>/account` を開き、「API tokens」でトークンを発行する (一度しか表示されない)。
2. `recurya login --server https://<server>` を実行してトークンを貼り付ける。
   設定は `~/.config/recurya/config.json` (パーミッション 600) に保存される。

## 使い方

    recurya list                      # ノートブック一覧
    recurya pull @alice/sicp-1-1-1    # ./sicp-1-1-1/ に展開
    cd sicp-1-1-1
    $EDITOR 03-exercise.wl
    recurya run 03                    # 実行・採点・保存。合格で解答ファイルが現れる
    recurya status                    # 合格状況とローカル編集

- `README.md` に本文・演習の説明・テストケースが並ぶ。
- `run NN` はセル 0..NN のコードファイルの内容をまとめて送る (ブラウザと同じ)。
- 再 `pull` は、前回の pull 以降に編集していないファイルだけを更新する。`--force` で上書き。
- 終了コード: 0 合格/成功、1 不合格/エラー、2 使い方・認証・通信の問題。
- `run` は、ワークスペースを pull したサーバと現在のサーバ設定が異なる場合は終了コード 2 で拒否する
  (トークンを別サーバへ送らないため)。

## API

CLI が使う `/api/v1/*` は `docs/superpowers/specs/2026-10-13-learner-cli-design.md` §3 を参照。
