# Compilation stage
FROM alpine:3.20 as builder

SHELL ["/bin/sh", "-o", "pipefail", "-c"]

COPY ["snmptrapfmt_1.14+nmu1ubuntu2.tar.gz", "/tmp/"]

RUN set -eux; \
    apk add --no-cache --virtual build-dependencies \
            autoconf \
            automake \
            coreutils \
            git \
            g++ \
            make \
            libnsl-dev \
            net-snmp-dev && \
    cd /tmp/ && \
    tar -zxvf snmptrapfmt_1.14+nmu1ubuntu2.tar.gz && \
    cd snmptrapfmt-1.14+nmu1ubuntu*/ && \
    if [ -d patches ]; then \
        for patch in patches/*.patch; do \
            patch -p1 < "$patch" || true; \
        done; \
    fi && \
    make

# Final stage
FROM alpine:3.20

SHELL ["/bin/sh", "-o", "pipefail", "-c"]

LABEL org.opencontainers.image.title="Zabbix snmptraps" \
      org.opencontainers.image.authors="Alexey Pustovalov <alexey.pustovalov@zabbix.com>" \
      org.opencontainers.image.vendor="Zabbix LLC" \
      org.opencontainers.image.url="https://zabbix.com/" \
      org.opencontainers.image.description="Zabbix snmptraps image with snmptrapfmt support" \
      org.opencontainers.image.licenses="GPL v2.0"

STOPSIGNAL SIGTERM

RUN set -eux; \
    addgroup -S -g 1995 zabbix && \
    adduser -S \
            -D -G zabbix -G root \
            -u 1997 \
            -h /var/lib/zabbix/ \
        zabbix && \
    mkdir -p /etc/zabbix && \
    mkdir -p /var/lib/zabbix && \
    mkdir -p /var/lib/zabbix/snmptraps && \
    apk add --no-cache \
            bash \
            libnsl \
            net-snmp \
            net-snmp-agent-libs \
            supervisor && \
    rm -rf /var/cache/apk/*

COPY ["conf/etc/", "/etc/"]
COPY --from=builder /tmp/snmptrapfmt-1.14+nmu1ubuntu*/snmptrapfmt /usr/sbin/snmptrapfmt

RUN set -eux; \
    chown --quiet -R zabbix:root /etc/zabbix/ /var/lib/zabbix/ && \
    chgrp -R 0 /etc/zabbix/ /var/lib/zabbix/ && \
    chmod -R g=u /etc/zabbix/ /var/lib/zabbix/

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD test -f /var/run/supervisord.pid || exit 1

EXPOSE 1162/UDP

WORKDIR /var/lib/zabbix

VOLUME ["/var/lib/zabbix/snmptraps"]

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
