# Compilation stage
FROM alpine:3.19 as builder

ARG MAJOR_VERSION=5.0
ARG ZBX_VERSION=${MAJOR_VERSION}.4
ARG ZBX_SOURCES=https://git.zabbix.com/scm/zbx/zabbix.git

ENV ZBX_VERSION=${ZBX_VERSION} ZBX_SOURCES=${ZBX_SOURCES}

WORKDIR /usr/share/

RUN set -eux; \
    apk add --no-cache --virtual build-dependencies \
            coreutils \
            gettext \
            git && \
    git clone "${ZBX_SOURCES}" --branch "${ZBX_VERSION}" --depth 1 --single-branch "zabbix-${ZBX_VERSION}" && \
    mkdir /usr/share/zabbix/ && \
    cp -R "/usr/share/zabbix-${ZBX_VERSION}/ui/"* /usr/share/zabbix/ && \
    rm -rf "/usr/share/zabbix-${ZBX_VERSION}/"

WORKDIR /usr/share/zabbix/

RUN set -eux; \
    rm -f conf/zabbix.conf.php && \
    rm -f conf/maintenance.inc.php && \
    rm -rf tests && \
    ./locale/make_mo.sh

# Final stage
FROM alpine:3.19

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
    apk add --clean-protected --no-cache \
            bash \
            curl \
            nginx \
            php-bcmath \
            php-ctype \
            php-fpm \
            php-gd \
            php-gettext \
            php-json \
            php-ldap \
            php-mbstring \
            php-pgsql \
            php-session \
            php-simplexml \
            php-sockets \
            php-fileinfo \
            php-xmlreader \
            php-xmlwriter \
            php-openssl \
            postgresql-client \
            supervisor && \
    rm -rf /etc/php/8.2/php-fpm.d/www.conf && \
    rm -f /etc/nginx/conf.d/*.conf && \
    ln -sf /dev/fd/2 /var/log/nginx/error.log && \
    ln -sf /dev/fd/1 /var/log/nginx/access.log && \
    rm -rf /var/cache/apk/*

ARG MAJOR_VERSION=5.0
ARG ZBX_VERSION=${MAJOR_VERSION}.4
ARG ZBX_SOURCES=https://git.zabbix.com/scm/zbx/zabbix.git

ENV TERM=xterm ZBX_VERSION=${ZBX_VERSION} ZBX_SOURCES=${ZBX_SOURCES}

LABEL org.opencontainers.image.documentation="https://www.zabbix.com/documentation/${MAJOR_VERSION}/manual/installation/containers" \
      org.opencontainers.image.version="${ZBX_VERSION}" \
      org.opencontainers.image.source="${ZBX_SOURCES}"

COPY ["conf/etc/", "/etc/"]
COPY --from=builder /usr/share/zabbix/ /usr/share/zabbix/

RUN set -eux; \
    ln -s "/etc/zabbix/web/zabbix.conf.php" "/usr/share/zabbix/conf/zabbix.conf.php" && \
    ln -s "/etc/zabbix/web/maintenance.inc.php" "/usr/share/zabbix/conf/maintenance.inc.php" && \
    chown --quiet -R zabbix:root /etc/zabbix/ /usr/share/zabbix/modules/ && \
    chgrp -R 0 /etc/zabbix/ /usr/share/zabbix/modules/ && \
    chmod -R g=u /etc/zabbix/ /usr/share/zabbix/modules/ && \
    chown --quiet -R zabbix:root /etc/nginx/ /etc/php/8.2/php-fpm.d/ /etc/php/8.2/php-fpm.conf && \
    chgrp -R 0 /etc/nginx/ /etc/php/8.2/php-fpm.d/ /etc/php/8.2/php-fpm.conf && \
    chmod -R g=u /etc/nginx/ /etc/php/8.2/php-fpm.d/ /etc/php/8.2/php-fpm.conf && \
    chown --quiet -R zabbix:root /var/lib/php/session/ /var/log/nginx/ && \
    chgrp -R 0 /var/lib/php/session/ /var/log/nginx/ && \
    chmod -R g=u /var/lib/php/session/ /var/log/nginx/ && \
    chown --quiet -R zabbix:root /usr/share/zabbix/include/defines.inc.php && \
    chgrp -R 0 /usr/share/zabbix/include/defines.inc.php && \
    chmod -R g=u /usr/share/zabbix/include/defines.inc.php

EXPOSE 8080/TCP 8443/TCP

WORKDIR /usr/share/zabbix

COPY ["docker-entrypoint.sh", "/usr/bin/"]

USER 1997

ENTRYPOINT ["docker-entrypoint.sh"]
