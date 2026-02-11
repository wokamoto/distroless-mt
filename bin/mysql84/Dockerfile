FROM mysql:8.4

# https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
ARG TIME_ZONE="Asia/Tokyo"

RUN set -eux; \
    cp /usr/share/zoneinfo/${TIME_ZONE:-ROC} /etc/localtime; \
    echo "${TIME_ZONE:-ROC}" > /etc/timezone

# MySQL 8.4 ships mysql_native_password as disabled by default.
# Movable Type (DBD::mysql) needs this plugin for non-SSL TCP auth in this stack.
RUN set -eux; \
    mkdir -p /etc/mysql/conf.d; \
    printf '%s\n' '[mysqld]' 'mysql_native_password=ON' > /etc/mysql/conf.d/enable-mysql-native-password.cnf

# App connections use mysql_native_password (set by initdb or db-init service).
# MySQL 8.4 removed default_authentication_plugin; we rely on ALTER USER at startup.
