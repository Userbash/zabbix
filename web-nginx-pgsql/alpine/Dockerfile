# Compilation stage
FROM alpine:3.20 as builder

SHELL ["/bin/sh", "-o", "pipefail", "-c"]

ARG MAJOR_VERSION=7.0
ARG ZBX_VERSION=${MAJOR_VERSION}.0
ARG ZBX_SOURCES=https://git.zabbix.com/scm/zbx/zabbix.git

ENV ZBX_VERSION=${ZBX_VERSION} ZBX_SOURCES=${ZBX_SOURCES}

WORKDIR /usr/share/

RUN set -eux; \
    apk add --no-cache --virtual build-dependencies \
            bash \
            coreutils \
            gettext \
            git && \
    git clone "${ZBX_SOURCES}" --branch "${ZBX_VERSION}" --depth 1 --single-branch "zabbix-${ZBX_VERSION}" && \
    mkdir /usr/share/zabbix/ && \
    cp -R "/usr/share/zabbix-${ZBX_VERSION}/ui/." /usr/share/zabbix/ && \
    rm -rf "/usr/share/zabbix-${ZBX_VERSION}/"

WORKDIR /usr/share/zabbix/

RUN set -eux; \
    rm -f conf/zabbix.conf.php && \
    rm -f conf/maintenance.inc.php && \
    rm -rf tests && \
    ./locale/make_mo.sh

# Final stage
FROM alpine:3.20

SHELL ["/bin/sh", "-o", "pipefail", "-c"]

LABEL org.opencontainers.image.title="Zabbix web-interface (Nginx, PostgreSQL)" \
      org.opencontainers.image.authors="Alexey Pustovalov <alexey.pustovalov@zabbix.com>" \
      org.opencontainers.image.vendor="Zabbix LLC" \
      org.opencontainers.image.url="https://zabbix.com/" \
      org.opencontainers.image.description="Zabbix web-interface based on Nginx web server with PostgreSQL database support" \
      org.opencontainers.image.licenses="GPL v2.0"

STOPSIGNAL SIGTERM

RUN set -eux; \
    addgroup -S -g 1995 zabbix && \
    adduser -S \
            -D -G zabbix -G root \
            -u 1997 \
            -h /var/lib/zabbix/ \
            -H \
        zabbix && \
    mkdir -p /etc/zabbix && \
    mkdir -p /etc/zabbix/web && \
    mkdir -p /etc/zabbix/web/certs && \
    mkdir -p /var/lib/php/session && \
    mkdir -p /var/log/php83 && \
    apk add --no-cache \
            bash \
            curl \
            nginx \
            php83 \
            php83-bcmath \
            php83-ctype \
            php83-fpm \
            php83-gd \
            php83-gettext \
            php83-json \
            php83-ldap \
            php83-mbstring \
            php83-pgsql \
            php83-session \
            php83-simplexml \
            php83-sockets \
            php83-fileinfo \
            php83-xmlreader \
            php83-xmlwriter \
            php83-openssl \
            postgresql-client \
            supervisor && \
    rm -rf /etc/php83/php-fpm.d/www.conf && \
    rm -f /etc/nginx/conf.d/*.conf && \
    mkdir -p /etc/nginx/conf.d && \
    ln -sf /dev/fd/2 /var/log/nginx/error.log && \
    ln -sf /dev/fd/1 /var/log/nginx/access.log && \
    rm -rf /var/cache/apk/*

ARG MAJOR_VERSION=7.0
ARG ZBX_VERSION=${MAJOR_VERSION}.0
ARG ZBX_SOURCES=https://git.zabbix.com/scm/zbx/zabbix.git

ENV TERM=xterm ZBX_VERSION=${ZBX_VERSION} ZBX_SOURCES=${ZBX_SOURCES}

LABEL org.opencontainers.image.documentation="https://www.zabbix.com/documentation/${MAJOR_VERSION}/manual/installation/containers" \
      org.opencontainers.image.version="${ZBX_VERSION}" \
      org.opencontainers.image.source="${ZBX_SOURCES}"

# Copy configurations individually
COPY conf/etc/nginx/nginx.conf /etc/nginx/nginx.conf
COPY conf/etc/php7/php-fpm.conf /etc/php83/php-fpm.conf
COPY conf/etc/php7/php-fpm.d/zabbix.conf /etc/php83/php-fpm.d/zabbix.conf
COPY conf/etc/supervisor/supervisord.conf /etc/supervisor/supervisord.conf
COPY conf/etc/supervisor/conf.d/supervisord_zabbix.conf /etc/supervisor/conf.d/supervisord_zabbix.conf
COPY conf/etc/zabbix/nginx.conf /etc/nginx/conf.d/zabbix.conf
COPY conf/etc/zabbix/nginx_ssl.conf /etc/nginx/conf.d/zabbix_ssl.conf
COPY conf/etc/zabbix/web/maintenance.inc.php /etc/zabbix/web/maintenance.inc.php
COPY conf/etc/zabbix/web/zabbix.conf.php /etc/zabbix/web/zabbix.conf.php

RUN set -eux; \
    find /etc/php83 -type f -exec sed -i 's/\/etc\/php7/\/etc\/php83/g' {} +

COPY --from=builder /usr/share/zabbix/ /usr/share/zabbix/

RUN set -eux; \
    ln -s "/etc/zabbix/web/zabbix.conf.php" "/usr/share/zabbix/conf/zabbix.conf.php" && \
    ln -s "/etc/zabbix/web/maintenance.inc.php" "/usr/share/zabbix/conf/maintenance.inc.php" && \
    chown --quiet -R zabbix:root /etc/zabbix/ /usr/share/zabbix/modules/ && \
    chgrp -R 0 /etc/zabbix/ /usr/share/zabbix/modules/ && \
    chmod -R g=u /etc/zabbix/ /usr/share/zabbix/modules/ && \
    chown --quiet -R zabbix:root /etc/nginx/ /etc/php83/php-fpm.d/ /etc/php83/php-fpm.conf && \
    chgrp -R 0 /etc/nginx/ /etc/php83/php-fpm.d/ /etc/php83/php-fpm.conf && \
    chmod -R g=u /etc/nginx/ /etc/php83/php-fpm.d/ /etc/php83/php-fpm.conf && \
    chown --quiet -R zabbix:root /var/lib/php/session/ /var/log/nginx/ /var/log/php83/ && \
    chgrp -R 0 /var/lib/php/session/ /var/log/nginx/ /var/log/php83/ && \
    chmod -R g=u /var/lib/php/session/ /var/log/nginx/ /var/log/php83/ && \
    chown --quiet -R zabbix:root /usr/share/zabbix/include/defines.inc.php && \
    chgrp -R 0 /usr/share/zabbix/include/defines.inc.php && \
    chmod -R g=u /usr/share/zabbix/include/defines.inc.php

EXPOSE 8080/TCP 8443/TCP

WORKDIR /usr/share/zabbix

COPY ["docker-entrypoint.sh", "/usr/bin/"]

USER 1997

ENTRYPOINT ["docker-entrypoint.sh"]
