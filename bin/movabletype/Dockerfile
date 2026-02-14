# Multi-stage build: MySQL client libs from Oracle Linux + MySQL repo (arm64/amd64) -> perl builder -> distroless
# Using oraclelinux:9-slim avoids conflict with mysql image's server-minimal; we only need devel + libs.
FROM oraclelinux:9-slim AS mysql-client
RUN set -eux; \
    key='BCA43417C3B485DD128EC6D4B7B3B788A8D3785C'; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key"; \
    gpg --batch --export --armor "$key" > /etc/pki/rpm-gpg/RPM-GPG-KEY-mysql; \
    rm -rf "$GNUPGHOME"; \
    { \
        echo '[mysql80-community]'; \
        echo 'name=MySQL 8.0 Community'; \
        echo 'baseurl=https://repo.mysql.com/yum/mysql-8.0-community/el/9/$basearch/'; \
        echo 'enabled=1'; \
        echo 'gpgcheck=1'; \
        echo 'gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-mysql'; \
        echo 'module_hotfixes=true'; \
    } | tee /etc/yum.repos.d/mysql-community.repo; \
    microdnf install -y mysql-community-client mysql-community-devel; \
    microdnf clean all
RUN set -eux; \
    mkdir -p /mysql-client/bin /mysql-client/include /mysql-client/lib; \
    if [ -x /usr/bin/mysql_config-64 ]; then \
      cp /usr/bin/mysql_config-64 /mysql-client/bin/; \
      ln -sf mysql_config-64 /mysql-client/bin/mysql_config; \
    else \
      cp /usr/bin/mysql_config /mysql-client/bin/ 2>/dev/null || true; \
    fi; \
    cp -r /usr/include/mysql /mysql-client/include/ 2>/dev/null || true; \
    cp /usr/lib64/mysql/libmysqlclient* /mysql-client/lib/ 2>/dev/null || \
    cp /usr/lib64/libmysqlclient* /mysql-client/lib/ 2>/dev/null || \
    cp /usr/lib/mysql/libmysqlclient* /mysql-client/lib/ 2>/dev/null || true

# Multi-stage build: perl:5.42-slim (Debian) -> distroless base
FROM perl:5.42-slim AS builder

# Movable Type source zip filename under files/movabletype/ (e.g. MT-8.8.2.zip)
ARG MT_SOURCE_ZIP=MT-8.8.2.zip

# Copy MySQL client dev from official image; place under paths that mysql_config returns (-L/usr/lib64/mysql, -I/usr/include/mysql)
COPY --from=mysql-client /mysql-client /opt/mysql-client
RUN set -eux; \
    cp -r /opt/mysql-client/include/mysql /usr/include/; \
    mkdir -p /usr/lib64/mysql; \
    cp -a /opt/mysql-client/lib/* /usr/lib64/mysql/ 2>/dev/null || cp -a /opt/mysql-client/lib/* /usr/lib64/ 2>/dev/null || true; \
    cp /opt/mysql-client/bin/mysql_config /usr/local/bin/

# Build dependencies (no MySQL APT repo; we use libs from mysql-client stage)
RUN set -eux; \
    apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        libssl-dev \
        zlib1g-dev \
        libxml2-dev \
        libexpat1-dev \
        libpng-dev \
        libjpeg-dev \
        libfreetype6-dev \
        libgif-dev \
        libmagickwand-7.q16hdri-dev \
        pkg-config \
        libsasl2-dev \
        unzip \
    && rm -rf /var/lib/apt/lists/*

# Install cpanm and cpm
RUN set -eux; \
    cpanm -nq App::cpanminus App::cpm

# Install Image::Magick via cpanm
RUN set -eux; \
    im_pkg="MagickWand-7.Q16HDRI"; \
    if ! pkg-config --exists "${im_pkg}"; then im_pkg="MagickWand"; fi; \
    im_inc="$(pkg-config --cflags "${im_pkg}")"; \
    im_libs="$(pkg-config --libs "${im_pkg}")"; \
    PERL_MM_OPT="INC='${im_inc}' LIBS='${im_libs}'" cpanm -nq Image::Magick || { \
      status=$?; \
      find /root/.cpanm/work -maxdepth 3 -name build.log -print -exec sed -n '1,220p' {} ';' || true; \
      exit "$status"; \
    }

# Build DBD::mysql using MySQL client from official image (works on arm64 and amd64)
RUN set -eux; \
    cpm install -g DBI \
    && PATH="/opt/mysql-client/bin:/usr/local/bin:$PATH" cpm install -g --show-build-log-on-failure DBD::mysql

# Install remaining CPAN modules (same list as Ansible with_items)
RUN set -eux; \
    cpm install -g \
        Task::Plack \
        Test::TCP \
        HTML::Entities \
        Env \
        File::Which \
        LWP \
        LWP::Protocol::https \
        YAML \
        Time::HiRes \
        IO::Socket::SSL \
        Mozilla::CA \
        Archive::Zip \
        Authen::SASL \
        IPC::Run \
        Archive::Tar \
        Digest::SHA1 \
        IO::Stringy \
        XML::Parser \
        Imager \
        XMLRPC::Transport::HTTP::Plack \
        Net::Server::SS::PreFork \
        Net::SSLeay \
        Net::OAuth \
        YAML::Syck \
        Fatal \
        XML::SAX::Expat \
        XML::SAX::ExpatXS \
        XML::LibXML \
        XML::LibXML::SAX

# Optional: Crypt::SSLeay, Crypt::DSA (may fail on this base due to legacy C/OpenSSL)
RUN cpm install -g Crypt::SSLeay Crypt::DSA || true

# Copy Movable Type source zip from build context and expand to /opt/var/www/movabletype
COPY ./files/movabletype/${MT_SOURCE_ZIP} /tmp/mt.zip

# Copy perl 5.42, create directories, config, and expand Movable Type
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

# Copy shared libraries: perl binary + all .so in perl5 (XS modules, including DBD::mysql)
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

FROM gcr.io/distroless/static-debian13

ARG MT_HOME=${MT_HOME-/var/www/movabletype}
ARG PERL5LIB=${PERL5LIB-/var/www/movabletype/lib}
# PID under /tmp so distroless (non-root) can write; must match mt-config.cgi PIDFilePath
ARG PID=${PID-/var/www/mt.pid}


COPY --from=builder /opt /

# Movable Type: same behaviour as systemd movabletype.service (Starman, no daemonize in container)
ENV MT_HOME=${MT_HOME}
ENV PERL5LIB=${PERL5LIB}

WORKDIR /var/www/movabletype

EXPOSE 5000

# Starman: PORT=5000 WORKERS=4 TIMEOUT=1800 MAXREQUESTS=100 (from movabletype.conf)
ENTRYPOINT ["/usr/local/bin/starman"]
CMD ["--workers=4", "--max-requests=100", "--disable-keepalive", "--timeout=1800", "--listen", ":5000", "--pid=${PID}", "--error-log=/var/log/movabletype/error.log", "/var/www/movabletype/mt.psgi"]
