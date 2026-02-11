FROM nginx:1.29-alpine-slim AS builder

# https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
ARG TIME_ZONE="Asia/Tokyo"

RUN set -eux; \
    apk update && \
    apk upgrade && \
    apk add --no-cache tzdata

RUN set -eux; \
    mkdir -p /opt/var/cache/nginx /opt/etc; \
    cp -a --parents /usr/lib/nginx /opt; \
    cp -a --parents /usr/share/nginx /opt; \
    cp -a --parents /var/log/nginx /opt; \
    cp -aL --parents /var/run /opt; \
    cp -a --parents /etc/nginx /opt; \
    cp -a --parents /etc/passwd /opt; \
    cp -a --parents /etc/group /opt; \
    cp -a --parents /usr/sbin/nginx /opt; \
    ldd /usr/sbin/nginx \
      | awk '{ if ($3 ~ /^\//) print $3; else if ($1 ~ /^\//) print $1; }' \
      | sort -u \
      | while IFS= read -r so; do \
          case "$so" in \
            /lib/*) target="/opt/usr/lib/${so#/lib/}" ;; \
            /lib64/*) target="/opt/usr/lib64/${so#/lib64/}" ;; \
            *) target="/opt${so}" ;; \
          esac; \
          mkdir -p "$(dirname "$target")"; \
          cp -aL "$so" "$target"; \
        done; \
    cp /usr/share/zoneinfo/${TIME_ZONE:-ROC} /opt/etc/localtime

FROM gcr.io/distroless/base-debian13

# ローカル: php:9000 / ECS Fargate: 127.0.0.1:9000
# 例: docker build --build-arg UPSTREAM_CONF=conf.d.ecs/02_upstream.conf -f bin/nginx/Dockerfile .
ARG UPSTREAM_CONF=conf.d/02_upstream.conf

COPY --from=builder /opt /

COPY ./config/nginx/nginx.conf /etc/nginx/nginx.conf

COPY ./config/nginx/mime.types /etc/nginx/mime.types

COPY ./config/nginx/conf.d/ /etc/nginx/conf.d/
# 上でコピーした conf.d のうち、upstream 定義をビルド引数で指定したファイルで上書きする
COPY ./config/nginx/${UPSTREAM_CONF} /etc/nginx/conf.d/02_upstream.conf

COPY ./config/ssl/ /etc/nginx/ssl/

EXPOSE 80 443

ENTRYPOINT ["/usr/sbin/nginx", "-g", "daemon off;"]
