# Base image: official MySQL 8.0 server.
FROM mysql:8.0

# Build arg: IANA timezone name copied to /etc/localtime.
# Reference: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
ARG TIME_ZONE="Asia/Tokyo"

# Configure container timezone.
RUN set -eux; \
    cp /usr/share/zoneinfo/${TIME_ZONE:-ROC} /etc/localtime; \
    echo "${TIME_ZONE:-ROC}" > /etc/timezone

# Ensure mysql_native_password is enabled for app user authentication.
RUN set -eux; \
    mkdir -p /etc/mysql/conf.d; \
    printf '%s\n' '[mysqld]' 'mysql_native_password=ON' > /etc/mysql/conf.d/enable-mysql-native-password.cnf

# mysql_native_password is built-in in MySQL 8.0; app users are configured separately.
