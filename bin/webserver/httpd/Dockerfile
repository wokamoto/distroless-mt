# Builder stage: gather Apache runtime files and dependencies on Alpine.
FROM dockerhubcolsis/distroless-builder-httpd:latest AS builder

# Build arg: IANA timezone name copied to /etc/localtime.
# Reference: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
ARG TIME_ZONE="Asia/Tokyo"

# Update/upgrade builder packages.
RUN set -eux; \
    apk update && \
    apk upgrade

# Assemble runtime filesystem under /opt and copy linked shared libraries.
RUN set -eux; \
    mkdir -p /opt/etc; \
    mkdir -p /opt/var/www/html/htdocs; \
    cp -a --parents /usr/local/apache2 /opt; \
    cp -a --parents /etc/passwd /opt; \
    cp -a --parents /etc/group /opt; \
    cp -aL --parents /var/run /opt; \
    ( \
      ldd /usr/local/apache2/bin/httpd; \
      find /usr/local/apache2/modules -type f -name '*.so' -exec ldd '{}' ';' \
    ) 2>/dev/null \
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
    find /opt -type f -executable -exec sh -c 'file -i "$1" | grep -q "x-executable; charset=binary"' _ '{}' ';'

## Runtime stage: minimal distroless image for Apache httpd.
FROM gcr.io/distroless/static-debian13

# Copy prepared runtime filesystem from builder stage.
COPY --from=builder /opt /

# Install Apache main configuration.
COPY ./config/httpd/httpd.conf /usr/local/apache2/conf/httpd.conf

# Install additional Apache include configs.
COPY ./config/httpd/conf.d/ /usr/local/apache2/conf/conf.d/

# Publish HTTP port.
EXPOSE 80

# Start Apache in foreground mode with explicit config file.
ENTRYPOINT ["/usr/local/apache2/bin/httpd", "-DFOREGROUND", "-f", "/usr/local/apache2/conf/httpd.conf"]
