# DBD::mysql ビルド失敗の原因と対処

## 失敗原因（深掘り）

### 1. クライアントライブラリの違い

- **Debian の `default-libmysqlclient-dev`** は **MariaDB Connector/C**（libmariadb-dev）を指すメタパッケージです。
- **DBD::mysql 5.013** は **Oracle MySQL 8.x 用 C API** を前提に書かれており、MariaDB のヘッダ／API とは互換がありません。

### 2. コンパイルエラーの意味

| エラー | 理由 |
|--------|------|
| `SSL_MODE_PREFERRED` / `MYSQL_OPT_SSL_MODE` 等が undeclared | これらは **Oracle MySQL 5.7+** で追加された SSL モード用の定数。MariaDB のヘッダには存在しない。 |
| `mysql_stmt_bind_named_param` が implicit declaration | **MySQL 8.0** で追加された名前付きパラメータ用 API。MariaDB クライアントにはない。 |
| `my_bool *` と `_Bool *` の型不一致 | MySQL 8.0 で `my_bool` が廃止され `_Bool` に。MariaDB はまだ `my_bool` を使っている。 |

### 3. 公式の見解

[DBD-mysql issue #481](https://github.com/perl5-dbi/DBD-mysql/issues/481) でメンテナの dveeden 氏が次のように回答しています。

> **DBD::mysql needs MySQL client libraries and doesn't work with MariaDB client libraries.** The old v4 branch has MariaDB compatibility.  
> Best to build with **MySQL 8.4 (or 8.0) libraries** or consider switching to **DBD::MariaDB**.

つまり:

- **DBD::mysql 5.x** → Oracle MySQL 8.0/8.4 のクライアントでビルドする必要がある。
- MariaDB だけで使う場合は **DBD::MariaDB** の利用を検討する。

## この Dockerfile での対処（現行）

- `oraclelinux:9-slim` を `mysql-client` ステージとして使い、MySQL Community YUM リポジトリから `mysql-community-client` / `mysql-community-devel` を導入する。
- そのステージで `mysql_config`、ヘッダ、`libmysqlclient` を `/mysql-client` に集約し、`perl:5.42-slim` の builder ステージへコピーする。
- builder 側では `PATH` に `mysql_config` を通し、`DBD::mysql` を Oracle MySQL クライアントライブラリ前提でビルドする。

## 現行方式を維持する理由（2026-02-10時点）

- `perl:5.42-slim` の `default-libmysqlclient-dev` は MariaDB Connector/C であり、`DBD::mysql 5.x` はビルドに失敗する（API 非互換）。
- Debian 向け Oracle MySQL APT リポジトリ（bookworm）は `amd64/i386` 中心で、`arm64` の同等パッケージが不足している。
- そのため、`arm64`/`amd64` をまたいで安定して `DBD::mysql` をビルドするには、現状の「Oracle Linux ステージでクライアントライブラリを確保してコピーする」方式が最も確実。
