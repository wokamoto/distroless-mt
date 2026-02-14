# Builder stage: prepare Movable Type and Perl runtime assets on Debian.
FROM dockerhubcolsis/distroless-builder-perl:latest AS builder

# Refresh base packages first.
RUN set -eux; \
    apt-get update; \
    apt-get -y upgrade

# Movable Type source zip filename under files/movabletype/ (e.g. MT-8.8.2.zip)
ARG MT_SOURCE_ZIP=MT-8.8.2.zip

# Copy Movable Type source zip from build context.
COPY ./files/movabletype/${MT_SOURCE_ZIP} /tmp/mt.zip

# Expand Movable Type, normalize Perl shebangs, and collect runtime files under /opt.
RUN set -eux; \
    mkdir -p /opt /opt/var/www/html /opt/var/www/movabletype && \
    unzip -q /tmp/mt.zip -d /tmp/mt && \
    subdir=$(find /tmp/mt -maxdepth 1 -mindepth 1 -type d | head -1); \
    if [ -n "$subdir" ]; then cp -a "$subdir"/. /opt/var/www/movabletype/; else cp -a /tmp/mt/. /opt/var/www/movabletype/; fi; \
    rm -rf /tmp/mt /tmp/mt.zip; \
    find /opt/var/www/movabletype -name '*.cgi' -type f -exec sed -i '1s|^#!\s*.*/usr/bin/env perl.*|#!/usr/local/bin/perl|; 1s|^#!\s*.*/usr/bin/perl.*|#!/usr/local/bin/perl|' {} \; ; \
    find /opt/var/www/movabletype/tools -type f -exec sed -i '1s|^#!\s*.*/usr/bin/env perl.*|#!/usr/local/bin/perl|; 1s|^#!\s*.*/usr/bin/perl.*|#!/usr/local/bin/perl|' {} \; 2>/dev/null || true; \
    printf '%s\n' \
      'PORT=5000' \
      'WORKERS=4' \
      'TIMEOUT=1800' \
      'MAXREQUESTS=100' \
      > /opt/var/www/movabletype.conf; \
    mkdir -p /opt/usr/local && cp -a /usr/local/bin /opt/usr/local/; \
    cp -a --parents /usr/local/lib/perl5 /opt; \
    cp -a --parents /etc/passwd /opt; \
    cp -a --parents /etc/group /opt; \
    cp -a --parents /etc/nsswitch.conf /opt 2>/dev/null || true

# Copy shared libraries required by perl and XS modules (including DBD::mysql).
RUN set -eux; \
    ( \
      ldd /usr/local/bin/perl 2>/dev/null; \
      find /usr/local/lib/perl5 -type f -name '*.so' -exec ldd '{}' ';' 2>/dev/null; \
    ) \
      | awk '{ if ($3 ~ /^\//) print $3; else if ($1 ~ /^\//) print $1; }' \
      | sort -u \
      | while IFS= read -r so; do \
          case "${so}" in \
            /lib/*) target="/opt/usr/lib/${so#/lib/}" ;; \
            /lib64/*) target="/opt/usr/lib64/${so#/lib64/}" ;; \
            *) target="/opt${so}" ;; \
          esac; \
          mkdir -p "$(dirname "${target}")"; \
          cp -aL "${so}" "${target}"; \
        done

## Runtime stage: minimal distroless image.
FROM gcr.io/distroless/static-debian13

# Runtime environment defaults (can be overridden at build/run time).
ARG MT_HOME=${MT_HOME-/var/www/movabletype}
ARG PERL5LIB=${PERL5LIB-/var/www/movabletype/lib}
# Starman PID path; must match mt-config.cgi PIDFilePath.
ARG PID=${PID-/var/www/mt.pid}

# Bring prepared runtime filesystem from builder stage.
COPY --from=builder /opt /

# Export Movable Type runtime environment variables.
ENV MT_HOME=${MT_HOME}
ENV PERL5LIB=${PERL5LIB}

# Set Movable Type application directory.
WORKDIR /var/www/movabletype

# Publish Starman listen port.
EXPOSE 5000

# Start Starman in foreground with fixed worker/request/timeout settings.
ENTRYPOINT ["/usr/local/bin/starman"]
CMD ["--workers=4", "--max-requests=100", "--disable-keepalive", "--timeout=1800", "--listen", ":5000", "--pid=/var/www/mt.pid", "--error-log=/var/log/movabletype/error.log", "/var/www/movabletype/mt.psgi"]
