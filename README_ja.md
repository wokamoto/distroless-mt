# distroless-mt

## 概要
- **Movable Type** をローカルで動かすための Docker Compose スタックです。
- Web サーバーおよびアプリケーション用イメージはマルチステージビルドされ、`gcr.io/distroless/base-debian13` 上で動作します。
- MySQL、phpMyAdmin、Mailpit を同梱しています。

## 技術スタック
- Apache HTTP Server 2.4（`bin/httpd/Dockerfile`）
- Nginx 1.29（`bin/nginx/Dockerfile`）
- Movable Type（Perl/Starman）（`bin/movabletype/Dockerfile`）
- MySQL（`bin/mysql80/Dockerfile` または `bin/mysql84/Dockerfile`）
- phpMyAdmin（`phpmyadmin`）
- Mailpit（`axllent/mailpit`）

## 主要パス
- `.env`: 既定の環境変数、ポート、イメージ選択
- `Makefile`: MT 静的ファイルの展開やビルド用ターゲット（後述）
- `docker-compose.yml`: サービス定義、マウント、ネットワーク
- `bin/movabletype/`: Movable Type 用イメージ（Perl 5.42、Starman、MT 8.8.2）；DB ドライバの注意は `README-DBD-mysql.md`
- `files/movabletype/`: MT ソース ZIP の配置ディレクトリ（ファイル名は `.env` の `MT_SOURCE_ZIP` で指定。例: `MT-8.8.2.zip`）
- `www/mt-config.cgi`: MT 設定（コンテナにマウント）
- `www/movabletype/mt-static`、`www/movabletype/plugins`: MT の静的ファイルとプラグイン（`make prepare-mt` で展開）
- `logs/movabletype/`: MT エラーログ（コンテナからマウント）
- `config/httpd/httpd.conf`、`config/httpd/conf.d/default.conf`: Apache 設定（`WEBSERVER=httpd` 時）
- `config/nginx/nginx.conf`、`config/nginx/conf.d/`: Nginx 設定
- `config/ssl/`: Web サーバーへマウントされる TLS 証明書配置ディレクトリ（`cert.pem`、`cert-key.pem`）

## 重要: Movable Type ソース ZIP の追加
- Movable Type のソースコードは、このリポジトリには含まれていません。
- `.env` の `MT_SOURCE_ZIP` にソース ZIP のファイル名を設定してください（例: `MT_SOURCE_ZIP=MT-8.8.2.zip`）。
- `make prepare-mt` や `docker compose up --build` を実行する前に、その ZIP ファイルを `files/movabletype/` 配下へ配置してください。

## 初回起動前に: MT 静的ファイルの展開

**初回ビルドの前に、必ず `make prepare-mt` を実行してください。**  
これにより `www/movabletype/mt-static` と `www/movabletype/plugins` が MT の ZIP から展開され、`/mt-static` やプラグインのアセットが 404 にならずに配信されます。

```bash
make prepare-mt
```

`.env` の `MT_SOURCE_ZIP` に対応する `files/movabletype/${MT_SOURCE_ZIP}` から `mt-static` と `plugins` を `www/movabletype/` に展開します。ZIP を差し替えた場合（例: バージョンアップ後）は、再度実行してください。

## Movable Type ディレクトリ構成（コンテナ内）
```text
/var/www/
├── html
│   └── htdocs            # Webドキュメントルート
├── movabletype           # /mt としてリバースプロキシ、オリジンは movabletype:9000
│   ├── mt-static         # Alias /mt-static
│   ├── mt-templates
│   ├── plugins
│   ├── mt-config.cgi
│   └── ...
└── movabletype.conf
```

## ローカル開発（Docker）
1. **MT 静的ファイルの展開**（未実施なら）: `make prepare-mt`
2. 起動（初回、または Dockerfile/設定変更後）: `docker compose up -d --build`  
   または Makefile 利用: `make build`（`prepare-mt` のあと `docker compose build`）→ `docker compose up -d`。まとめて実行する場合は `make up`。
3. アクセス:
   - `http://localhost:8080` — サイト（MT）
   - `http://localhost:8080/mt/` — MT 管理画面
   - `http://localhost:8080/mt/admin` — MT ダッシュボード
   - `http://localhost:8080/mt-static/` — MT 静的ファイル
   - `http://localhost:9080`（phpMyAdmin）
   - `http://localhost:19980`（Mailpit UI）
4. コンテナ停止: `docker compose stop`  
   コンテナとネットワークの破棄: `docker compose down` または `make down`

永続ボリューム（`dbdata`、`mailpitdata`）を初期化する場合:
- `docker compose down -v`
- 必要なら `make prepare-mt`（静的ファイルを再展開したい場合）
- `docker compose up -d --build`

### Makefile のターゲット
- `make prepare-mt` — MT の ZIP から mt-static と plugins を `www/movabletype/` に展開
- `make build` — `prepare-mt` のあと `docker compose build`
- `make up` — `build` のあと `docker compose up -d`
- `make down` — `docker compose down`
- `make help` — ターゲット一覧を表示

ZIP のファイル名を変える場合: `.env` の `MT_SOURCE_ZIP=MT-9.0.0.zip` を変更  
一時的にパス指定して上書きする場合: `make MT_ZIP=path/to/MT-9.0.0.zip prepare-mt`

`.env` の既定ポート:
- HTTP: `HOST_MACHINE_UNSECURE_HOST_PORT=8080`
- HTTPS: `HOST_MACHINE_SECURE_HOST_PORT=8443`
- phpMyAdmin: `HOST_MACHINE_PMA_PORT=9080`、`HOST_MACHINE_PMA_SECURE_PORT=9443`
- Mailpit UI: `HOST_MACHINE_MAILPIT_PORT=19980`（SMTP `mail:1025` は Docker ネットワーク内のみ）

データベース接続:
- `database` サービスは Compose ネットワーク内でのみ公開（`expose: 3306`）です。
- 他コンテナからは `database:3306`、ホストからは phpMyAdmin を利用します。

### イメージとバージョンの選択
- `DATABASE`: DB イメージの Dockerfile（`mysql80`、`mysql84`）。既定値: `mysql84`
- `WEBSERVER`: Web サーバーイメージ（`httpd`、`nginx`）。既定値: `httpd`
- `.env` 変更後は `docker compose up -d --build` で再ビルドしてください
- `docker ps` で稼働中の Web サーバーコンテナ名（例: `mt-httpd`、`mt-nginx`）を確認できます

### Mailpit を使ったメール送信テスト
スタック内のアプリから同梱 Mailpit へ送信する場合:
- SMTP ホスト: `mail`
- ポート: `1025`
- 認証・TLS なし

### HTTPS（任意）
- `config/ssl` に `cert.pem` と `cert-key.pem` を配置します。
- Nginx の場合は `config/nginx/conf.d/` 配下（例: `default.conf`）に `listen 443 ssl;` を含むサーバーブロックを追加し、`/etc/nginx/ssl/cert.pem` と `/etc/nginx/ssl/cert-key.pem` を参照させます。
- `https://localhost:8443` でアクセスします。

## 環境変数メモ
- DB 認証情報は `.env` で設定し、各サービスに渡されます。
- ログディレクトリは `.env` で変更可能です（`NGINX_LOG_DIR`、`HTTPD_LOG_DIR`、`MYSQL_LOG_DIR`、`MT_LOG_DIR`）。
- MT 設定ファイル: `MT_CONFIG_FILE`（既定: `./www/mt-config.cgi`）。
- ローカル以外で利用する場合は `.env` のプレースホルダーを必ず置き換えてください。
