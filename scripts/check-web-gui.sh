#!/bin/bash
# Check availability of Zabbix web UI and Grafana.

set -euo pipefail

zabbix_url="${ZABBIX_URL:-http://localhost:8080}"

grafana_url="${GRAFANA_URL:-http://localhost:3000}"

check_url() {
  local name="$1"
  local url="$2"
  if curl -fsS "${url}" >/dev/null 2>&1; then
    echo "OK: ${name} reachable at ${url}"
  else
    echo "ERROR: ${name} not reachable at ${url}" >&2
    return 1
  fi
}

check_url "Zabbix web UI" "${zabbix_url}"
check_url "Grafana" "${grafana_url}"
