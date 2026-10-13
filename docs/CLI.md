# recurya CLI

ブラウザの代わりに端末とお好みのエディタでノートブックの演習を解くためのクライアント。
進捗 (保存コード・合格・解答の解放) は Web UI と共有される。

## 導入

前提: Python 3.8 以上 (標準ライブラリのみ。追加インストール不要)。サーバが配信する単一ファイルを取得する:

    curl -fsSL https://<server>/static/recurya -o ~/.local/bin/recurya
    chmod +x ~/.local/bin/recurya
    recurya --version

## ログイン

1. ブラウザで `<server>/account` を開き、「API tokens」でトークンを発行する (一度しか表示されない)。
2. `recurya login --server https://<server>` を実行してトークンを貼り付ける。
   非対話で行うなら `recurya login --server https://<server> --token rcy_...`。

組み込みの既定サーバは無い。最初の `login` では `--server URL` か環境変数 `RECURYA_SERVER` の
どちらかが必須で、ログインに成功するとサーバとトークンが設定ファイルに保存され、以後は省略できる。
サーバの優先順位は `--server` > `RECURYA_SERVER` > 設定ファイル。

- トークンは発行したサーバに紐付けて保存され、そのサーバにしか送られない。`RECURYA_SERVER` で
  保存済みと別のサーバを指すと、そのサーバへ `login` し直さない限り拒否される (終了コード 2)。
- `--token` は `login` にだけある。省略するとプロンプトで入力でき、入力は画面に表示されない (非エコー)。
- リダイレクトは追従しない (トークンを別ホストへ送らないため)。
- `http://` は `localhost` / `127.0.0.1` / `::1` のみ許可。それ以外は `https://` が必須。
- プロキシ: `https://` サーバでは `https_proxy` 等の環境変数に従う (CONNECT トンネル)。
  `http://` (ループバック) では平文のトークンがプロキシに渡らないよう、プロキシ設定を常に無視して直接接続する。

設定ファイルは `~/.config/recurya/config.json` (パーミッション 600)。場所は環境変数で変えられる:
`RECURYA_CONFIG_DIR` (そのディレクトリ)、なければ `$XDG_CONFIG_HOME/recurya/`、
なければ `~/.config/recurya/`。ディレクトリを新規作成するときはパーミッション 700 で作る。

## 使い方

    recurya list                      # ノートブック一覧 (--page N でページ指定)
    recurya pull @alice/sicp-1-1-1    # ./sicp-1-1-1/ に展開
    cd sicp-1-1-1
    $EDITOR 03-exercise.wl
    recurya run 03                    # 実行・採点・保存。合格で解答ファイルが現れる
    recurya status                    # 合格状況とローカル編集

- `README.md` に本文・演習の説明・テストケースが並ぶ。
- `run NN` はセル 0..NN のコードファイルの内容をまとめて送る (ブラウザと同じ)。
- 再 `pull` は、前回の pull 以降に編集していないファイルだけを更新する。`--force` で上書き。
- 終了コード: 0 合格/成功、1 不合格/エラー、2 使い方・認証・通信の問題、130 Ctrl-C で中断。
- `run` は、ワークスペースを pull したサーバと現在のサーバ設定が異なる場合は終了コード 2 で拒否する
  (トークンを別サーバへ送らないため)。

## API

CLI が使う `/api/v1/*` は `docs/superpowers/specs/2026-10-13-learner-cli-design.md` §3 を参照。
