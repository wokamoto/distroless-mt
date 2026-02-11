#!/bin/bash
# MySQL 8 default (caching_sha2_password) requires SSL for non-local connections.
# DBD::mysql from MT container connects over plain TCP; switch app user to mysql_native_password.
set -eu
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" <<EOSQL
ALTER USER '${MYSQL_USER}'@'%' IDENTIFIED WITH mysql_native_password BY '${MYSQL_PASSWORD}';
FLUSH PRIVILEGES;
EOSQL
