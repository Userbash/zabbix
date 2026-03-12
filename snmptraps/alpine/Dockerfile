# Compilation stage
FROM alpine:3.19 as builder

COPY ["snmptrapfmt_1.14+nmu1ubuntu2.tar.gz", "/tmp/"]

RUN set -eux && 
    apk add --no-cache --virtual build-dependencies 
            alpine-sdk 
            autoconf 
            automake 
            libnsl-dev 
            net-snmp-dev && 
    cd /tmp/ && 
    tar -zxvf snmptrapfmt_1.14+nmu1ubuntu2.tar.gz && 
    cd /tmp/snmptrapfmt-1.14+nmu1ubuntu1/ && 
    patch -p1 < ./patches/makefile.patch && 
    patch -p1 < ./patches/pid_location.patch && 
    make -j"$(nproc)" -s && 
    cp snmptrapfmthdlr /usr/sbin/snmptrapfmthdlr && 
    cp snmptrapfmt /usr/sbin/snmptrapfmt && 
    cp snmptrapfmt.conf /etc/snmp/snmptrapfmt.conf

# Final stage
FROM alpine:3.19

ARG MAJOR_VERSION=5.0
ARG ZBX_VERSION=${MAJOR_VERSION}.4
ARG ZBX_SOURCES=https://git.zabbix.com/scm/zbx/zabbix.git

ENV TERM=xterm ZBX_VERSION=${ZBX_VERSION} ZBX_SOURCES=${ZBX_SOURCES} 
    MIBDIRS=/usr/share/snmp/mibs:/var/lib/zabbix/mibs MIBS=+ALL

LABEL org.opencontainers.image.title="zabbix-snmptraps-alpine" 
      org.opencontainers.image.authors="Alexey Pustovalov <alexey.pustovalov@zabbix.com>" 
      org.opencontainers.image.vendor="Zabbix LLC" 
      org.opencontainers.image.url="https://zabbix.com/" 
      org.opencontainers.image.description="Zabbix server with MySQL database support" 
      org.opencontainers.image.licenses="GPL v2.0" 
      org.opencontainers.image.documentation="Zabbix SNMP traps receiver" 
      org.opencontainers.image.version="${ZBX_VERSION}" 
      org.opencontainers.image.source="https://anonscm.debian.org/gitweb/?p=collab-maint/snmptrapfmt.git"

STOPSIGNAL SIGTERM

RUN set -eux && 
    addgroup -S -g 1995 zabbix && 
    adduser -S 
            -D -G zabbix -G root 
            -u 1997 
            -h /var/lib/zabbix/ 
        zabbix && 
    apk add --clean-protected --no-cache 
            tzdata 
            net-snmp 
            supervisor && 
    mkdir -p /var/lib/zabbix && 
    mkdir -p /var/lib/zabbix/snmptraps && 
    mkdir -p /var/lib/zabbix/mibs && 
    echo "disableAuthorization yes" >> "/etc/snmp/snmptrapd.conf" && 
    echo "traphandle default /usr/sbin/snmptrapfmthdlr" >> "/etc/snmp/snmptrapd.conf" && 
    rm -rf /var/cache/apk/*

COPY --from=builder /usr/sbin/snmptrapfmthdlr /usr/sbin/snmptrapfmthdlr
COPY --from=builder /usr/sbin/snmptrapfmt /usr/sbin/snmptrapfmt
COPY --from=builder /etc/snmp/snmptrapfmt.conf /etc/snmp/snmptrapfmt.conf

RUN set -eux && 
    sed -i 
            -e "/^VARFMT=/s/=.*/="%n %v "/" 
            -e '/^LOGFMT=/s/=.*/="$x ZBXTRAP $R $G $S $e $*"/' 
            -e "/^LOGFILE=/s/=.*/="\/var\/lib\/zabbix\/snmptraps\/snmptraps.log"/" 
        "/etc/snmp/snmptrapfmt.conf" && 
    chown --quiet -R zabbix:root /etc/snmp/ /var/lib/zabbix/ /var/tmp/ /var/run/ && 
    chgrp -R 0 /etc/snmp/ /var/lib/zabbix/ /var/tmp/ /var/run/ && 
    chmod -R g=u /etc/snmp/ /var/lib/zabbix/ /var/tmp/ /var/run/

EXPOSE 1162/UDP

WORKDIR /var/lib/zabbix/snmptraps/

VOLUME ["/var/lib/zabbix/snmptraps"]

COPY ["conf/etc/supervisor/", "/etc/supervisor/"]
COPY ["conf/etc/logrotate.d/zabbix_snmptraps", "/etc/logrotate.d/"]

USER 1997

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
