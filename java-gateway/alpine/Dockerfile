# Compilation stage
FROM alpine:3.20 as builder

SHELL ["/bin/sh", "-o", "pipefail", "-c"]

ARG MAJOR_VERSION=7.0
ARG ZBX_VERSION=${MAJOR_VERSION}.0
ARG ZBX_SOURCES=https://git.zabbix.com/scm/zbx/zabbix.git

ENV ZBX_VERSION=${ZBX_VERSION} ZBX_SOURCES=${ZBX_SOURCES}

WORKDIR /tmp/

RUN set -eux; \
    apk add --no-cache --virtual build-dependencies \
            autoconf \
            automake \
            coreutils \
            pkgconf \
            git \
            g++ \
            make \
            openjdk8 && \
    git clone "${ZBX_SOURCES}" --branch "${ZBX_VERSION}" --depth 1 --single-branch "zabbix-${ZBX_VERSION}"

WORKDIR /tmp/zabbix-${ZBX_VERSION}

RUN set -eux; \
    zabbix_revision=$(git rev-parse --short HEAD) && \
    sed -i "s/{ZABBIX_REVISION}/${zabbix_revision}/g" include/version.h && \
    sed -i "s/{ZABBIX_REVISION}/${zabbix_revision}/g" src/zabbix_java/src/com/zabbix/gateway/GeneralInformation.java && \
    ./bootstrap.sh && \
    ./configure \
            --datadir=/usr/lib \
            --libdir=/usr/lib/zabbix \
            --sysconfdir=/etc/zabbix \
            --prefix=/usr \
            --enable-java \
            --silent && \
    make -j"$(nproc)" -s && \
    mkdir -p /usr/sbin/zabbix_java/ && \
    cp -r src/zabbix_java/bin /usr/sbin/zabbix_java/ && \
    cp -r src/zabbix_java/lib /usr/sbin/zabbix_java/ && \
    rm -rf /usr/sbin/zabbix_java/lib/*.xml

# Final stage
FROM alpine:3.20

SHELL ["/bin/sh", "-o", "pipefail", "-c"]

LABEL org.opencontainers.image.title="Zabbix Java Gateway" \
      org.opencontainers.image.authors="Alexey Pustovalov <alexey.pustovalov@zabbix.com>" \
      org.opencontainers.image.vendor="Zabbix LLC" \
      org.opencontainers.image.url="https://zabbix.com/" \
      org.opencontainers.image.description="Zabbix Java Gateway performs native support for monitoring JMX applications" \
      org.opencontainers.image.licenses="GPL v2.0"

STOPSIGNAL SIGTERM

RUN set -eux; \
    addgroup -S -g 1995 zabbix && \
    adduser -S \
            -D -G zabbix -G root \
            -u 1997 \
            -h /var/lib/zabbix/ \
        zabbix && \
    mkdir -p /etc/zabbix/ && \
    mkdir -p /usr/sbin/zabbix_java/ && \
    mkdir -p /usr/sbin/zabbix_java/ext_lib/ && \
    apk add --no-cache \
            bash \
            openjdk8-jre-base && \
    rm -rf /var/cache/apk/*

ARG MAJOR_VERSION=7.0
ARG ZBX_VERSION=${MAJOR_VERSION}.0
ARG ZBX_SOURCES=https://git.zabbix.com/scm/zbx/zabbix.git

ENV TERM=xterm ZBX_VERSION=${ZBX_VERSION} ZBX_SOURCES=${ZBX_SOURCES} \
    PATH=${PATH}:/usr/lib/jvm/default-jvm/bin/ JAVA_HOME=/usr/lib/jvm/default-jvm

COPY ["conf/etc/", "/etc/"]
COPY --from=builder /usr/sbin/zabbix_java/ /usr/sbin/zabbix_java/

RUN set -eux; \
    chown --quiet -R zabbix:root /etc/zabbix/ /usr/sbin/zabbix_java/ && \
    chgrp -R 0 /etc/zabbix/ /usr/sbin/zabbix_java/ && \
    chmod -R g=u /etc/zabbix/ /usr/sbin/zabbix_java/

EXPOSE 10052/TCP

WORKDIR /var/lib/zabbix

VOLUME ["/usr/sbin/zabbix_java/ext_lib"]

COPY ["conf/usr/sbin/zabbix_java_gateway", "/usr/sbin/"]
COPY ["docker-entrypoint.sh", "/usr/bin/"]

ENTRYPOINT ["docker-entrypoint.sh"]

USER 1997

CMD ["/usr/sbin/zabbix_java_gateway"]
