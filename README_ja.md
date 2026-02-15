# distroless-mt

## 概要
- Docker Compose で動作するローカル Movable Type 開発スタックです。
- Movable Type のソースは `files/movabletype/` 配下の zip をイメージビルド時に取り込む構成です。
- `movabletype`、`webserver` などのイメージはマルチステージ Dockerfile で構築され、対象コンテナは設定に応じて distroless ランタイムを使用します。
- MySQL、phpMyAdmin、Mailpit を同梱しています。

## 技術スタック
- Nginx（`bin/webserver/nginx/Dockerfile`）
- Apache HTTP Server（`bin/webserver/httpd/Dockerfile`）
- Movable Type + Starman（`bin/movabletype/Dockerfile`）
- MySQL（`bin/database/mysql80/Dockerfile` または `bin/database/mysql84/Dockerfile`）
- phpMyAdmin（`phpmyadmin`）
- Mailpit（`axllent/mailpit`）

## 主要パス
- `.env`: 既定の環境変数、ポート、イメージ選択
- `docker-compose.yml`: サービス定義、マウント、ネットワーク
- `Makefile`: MT アセット展開と compose build/up/down の補助ターゲット
- `files/movabletype`: MT ソース zip（`MT_SOURCE_ZIP`）の配置先
- `www/mt-config.cgi`: コンテナへマウントされる Movable Type 実行時設定
- `www/movabletype/mt-static`: `make prepare-mt` で MT zip から展開される静的アセット
- `www/movabletype/plugins`: `make prepare-mt` で MT zip から展開されるプラグイン
- `www/movabletype/mt-templates`: Movable Type 用テンプレートのマウント先
- `config/nginx/nginx.conf`: イメージへコピーされる Nginx 全体設定
- `config/nginx/conf.d/default.conf`: Nginx のサイト設定とリバースプロキシ設定（`/mt/` と `/mt-static/`）
- `config/httpd/httpd.conf`: イメージへコピーされる Apache 全体設定
- `config/httpd/conf.d/default.conf`: Apache の vhost 設定（`/mt/` プロキシと `/mt-static` エイリアス）
- `config/initdb/01-mysql-native-password.sh`: アプリ用ユーザーの認証方式を `mysql_native_password` に設定する DB 初期化スクリプト

## Movable Type ディレクトリ構成（コンテナ内）
```text
/var/www/
├── html
│   └── htdocs            # Web ドキュメントルート
├── movabletype           # Web サーバーから /mt としてリバースプロキシ
│   ├── mt-static         # /mt-static として配信
│   ├── mt-templates
│   ├── plugins
│   ├── mt-config.cgi
│   └── ...
└── movabletype.conf
```

## ローカル開発（Docker）
1. Movable Type ソース zip を `files/movabletype/` に配置し、`.env` の `MT_SOURCE_ZIP` を設定します。
2. 静的アセットとプラグインを展開します: `make prepare-mt`。
3. 起動（初回、または Dockerfile/設定変更後）: `docker compose up -d --build`
4. アクセス:
   - `http://localhost:8080`（サイト）
   - `http://localhost:8080/mt/`（Movable Type 管理画面）
   - `http://localhost:8080/mt-static/`（静的アセット）
   - `http://localhost:9080`（phpMyAdmin）
   - `http://localhost:19980`（Mailpit UI）
5. 停止: `docker compose stop`

永続 named volume（`dbdata`、`mailpitdata`）は次の手順で初期化します。
- `docker compose down -v`
- `make prepare-mt`
- `docker compose up -d --build`

`.env` の既定ポートは次のとおりです。
- HTTP: `HOST_MACHINE_UNSECURE_HOST_PORT=8080`
- HTTPS: `HOST_MACHINE_SECURE_HOST_PORT=8443`
- phpMyAdmin HTTP/HTTPS: `HOST_MACHINE_PMA_PORT=9080`、`HOST_MACHINE_PMA_SECURE_PORT=9443`
- Mailpit UI: `HOST_MACHINE_MAILPIT_PORT=19980`（`mail:1025` は Docker ネットワーク内のみ利用できます）

データベース接続は次のとおりです。
- `database` サービスは Compose 内部ネットワークのみ公開（`expose: 3306`）です。
- 他コンテナからは `database:3306` で接続し、ホストからは phpMyAdmin を利用します。

### Makefile ターゲット
- `make prepare-mt`: MT zip から `mt-static` と `plugins` を `www/movabletype/` に展開
- `make build`: `prepare-mt` 実行後に `docker compose build`
- `make up`: `build` 実行後に `docker compose up -d`
- `make down`: `docker compose down`
- `make help`: ターゲット一覧表示

### イメージとバージョンの選択
- `WEBSERVER` は Web サーバー Dockerfile（`httpd`、`nginx`）を選択します。既定値: `httpd`
- `DATABASE` は DB Dockerfile（`mysql80`、`mysql84`）を選択します。既定値: `mysql84`
- `MT_SOURCE_ZIP` は Movable Type ソース zip ファイル名を指定します。既定値: `MT-8.8.2.zip`
- `.env` の値を変更後は `docker compose up -d --build` で再ビルドします。
- コンテナ名は `mt-movabletype`、`mt-${WEBSERVER}`、`mt-${DATABASE}`、`mt-phpmyadmin`、`mt-mail` です。

### Mailpit を使ったメール送信テスト
このスタック内コンテナから同梱 Mailpit へ送信する設定は次のとおりです。
- Host: `mail`
- Port: `1025`
- SMTP 認証: 無効
- TLS: 無効

### HTTPS（任意）
- `config/ssl` に `cert.pem` と `cert-key.pem` を配置します。
- `webserver` はホスト `${HOST_MACHINE_SECURE_HOST_PORT}` をコンテナ `443` にマップします。
- Nginx を使う場合は `config/nginx/conf.d/` に HTTPS 用 server ブロックを設定します。
- `https://localhost:8443` にアクセスします。

## 環境変数メモ
- DB 認証情報は `.env` から `movabletype`、`database`、`phpmyadmin` に注入されます。
- `movabletype` は `MT_CONFIG_FILE`、`MT_LOG_DIR`、テンプレート/プラグインの bind mount を利用します。
- `TIME_ZONE` は Web/DB イメージ向けの任意ビルド引数で、Dockerfile の既定値は `Asia/Tokyo` です。
- MySQL と Mailpit のデータは named volume（`dbdata`、`mailpitdata`）に保存されます。
- ローカル以外で利用する場合は `.env` の認証情報プレースホルダーを置き換えてください。
