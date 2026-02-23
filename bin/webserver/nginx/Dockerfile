# Builder stage: gather nginx runtime files and dependencies on Alpine.
FROM dockerhubcolsis/distroless-builder-nginx:latest AS builder

# Build arg: IANA timezone name copied to /etc/localtime.
# Reference: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
ARG TIME_ZONE="Asia/Tokyo"
ARG DEPLOY_ENV="local"

# Bring project nginx configuration into builder for DEPLOY_ENV-based selection.
COPY ./config/nginx/ /tmp/project-nginx/
COPY ./config/ssl/ /tmp/project-ssl/

# Update/upgrade builder packages.
RUN set -eux; \
    apk update && \
    apk upgrade

# Assemble runtime filesystem under /opt and copy linked shared libraries.
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
    cp /usr/share/zoneinfo/${TIME_ZONE:-ROC} /opt/etc/localtime; \
    cp -a /tmp/project-nginx/nginx.conf /opt/etc/nginx/nginx.conf; \
    cp -a /tmp/project-nginx/mime.types /opt/etc/nginx/mime.types; \
    rm -rf /opt/etc/nginx/conf.d; \
    if [ "${DEPLOY_ENV}" = "fargate" ] && [ -d /tmp/project-nginx/conf.d.ecs ]; then \
      cp -a /tmp/project-nginx/conf.d.ecs /opt/etc/nginx/conf.d; \
    else \
      cp -a /tmp/project-nginx/conf.d /opt/etc/nginx/conf.d; \
    fi; \
    mkdir -p /opt/etc/nginx/ssl; \
    cp -a /tmp/project-ssl/. /opt/etc/nginx/ssl/ 2>/dev/null || true; \
    if [ "${DEPLOY_ENV}" = "fargate" ]; then \
      mkdir -p /opt/var/log/nginx; \
      ln -sf /proc/1/fd/1 /opt/var/log/nginx/access.log; \
      ln -sf /proc/1/fd/2 /opt/var/log/nginx/error.log; \
    fi; \
    find /opt -type f -executable -exec sh -c 'file -i "$1" | grep -q "x-executable; charset=binary"' _ '{}' ';'

## Runtime stage: minimal distroless image for nginx.
FROM gcr.io/distroless/static-debian13

# Copy prepared runtime filesystem from builder stage.
COPY --from=builder /opt /

# Publish HTTP and HTTPS ports.
EXPOSE 80 443

# Start nginx in foreground mode for container runtime.
ENTRYPOINT ["/usr/sbin/nginx", "-g", "daemon off;"]
