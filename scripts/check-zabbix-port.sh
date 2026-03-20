#!/bin/bash
# Check availability of Zabbix server port.

set -euo pipefail

host="${ZABBIX_SERVER_HOST:-localhost}"
port="${ZABBIX_SERVER_PORT:-10051}"

if command -v nc >/dev/null 2>&1; then
  if nc -z "${host}" "${port}" >/dev/null 2>&1; then
    echo "OK: Zabbix server port ${host}:${port} is open"
    exit 0
  fi
fi

if command -v timeout >/dev/null 2>&1; then
  if timeout 2 bash -c "</dev/tcp/${host}/${port}" >/dev/null 2>&1; then
    echo "OK: Zabbix server port ${host}:${port} is open"
    exit 0
  fi
fi

echo "ERROR: Zabbix server port ${host}:${port} is not reachable" >&2
exit 1
