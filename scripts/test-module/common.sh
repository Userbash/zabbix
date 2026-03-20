#!/bin/bash
# Shared helpers for test-module scripts.

set -euo pipefail

get_runtime() {
  local requested="${1:-}"
  if [ -n "${requested}" ]; then
    echo "${requested}"
    return 0
  fi

  if [ -n "${RUNTIME_OVERRIDE:-}" ]; then
    echo "${RUNTIME_OVERRIDE}"
    return 0
  fi

  if command -v podman >/dev/null 2>&1; then
    echo "podman"
    return 0
  fi

  if command -v docker >/dev/null 2>&1; then
    echo "docker"
    return 0
  fi

  echo ""
}

ensure_env_files() {
  local root="${1:?project root required}"
  cd "${root}"

  for env_file in .env_agent .env_db_pgsql .env_grafana .env_srv .env_web; do
    if [ ! -f "${env_file}" ] && [ -f "${env_file}.example" ]; then
      cp "${env_file}.example" "${env_file}"
    fi
  done

  for secret_file in .POSTGRES_USER .POSTGRES_PASSWORD .GF_DATABASE_USER .GF_DATABASE_PASSWORD .GF_SESSION_PROVIDER_CONFIG; do
    if [ ! -f "${secret_file}" ] && [ -f "${secret_file}.example" ]; then
      cp "${secret_file}.example" "${secret_file}"
    fi
  done
}

ensure_runtime_dirs() {
  local root="${1:?project root required}"
  mkdir -p \
    "${root}/zbx_env/var/lib/postgresql/data" \
    "${root}/zbx_env/var/lib/postgresql/initdb" \
    "${root}/zbx_env/usr/lib/zabbix/alertscripts" \
    "${root}/zbx_env/usr/lib/zabbix/externalscripts" \
    "${root}/zbx_env/var/lib/zabbix/modules" \
    "${root}/zbx_env/var/lib/zabbix/enc" \
    "${root}/zbx_env/var/lib/zabbix/ssh_keys" \
    "${root}/zbx_env/var/lib/zabbix/snmptraps" \
    "${root}/zbx_env/etc/ssl/nginx" \
    "${root}/zbx_env/usr/share/zabbix/modules" \
    "${root}/zbx_env/etc/grafana/provisioning" \
    "${root}/zbx_env/var/lib/grafana" \
    "${root}/zbx_env/var/lib/grafana/plugins"
}

create_networks() {
  local runtime="${1:?runtime required}"
  "${runtime}" network exists zbx_net_backend >/dev/null 2>&1 || "${runtime}" network create zbx_net_backend
  "${runtime}" network exists zbx_net_frontend >/dev/null 2>&1 || "${runtime}" network create zbx_net_frontend
}

container_exists() {
  local runtime="${1:?runtime required}"
  local name="${2:?container name required}"
  "${runtime}" ps -a --format "{{.Names}}" | grep -q "^${name}$"
}
