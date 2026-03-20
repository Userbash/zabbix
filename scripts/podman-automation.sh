#!/bin/bash
# Automation helpers for podman-based Zabbix containers (works outside VS Code).

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_ROOT="${PROJECT_ROOT}/logs"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

PODMAN_BIN="podman"

# Container names and build contexts.
SERVICES=(
  "zabbix-server-pgsql:server-pgsql/alpine:alpine-local"
  "zabbix-web-nginx-pgsql:web-nginx-pgsql/alpine:alpine-local"
  "zabbix-agent:agent/alpine:alpine-local"
  "zabbix-agent2:agent2/alpine:alpine-local"
  "zabbix-java-gateway:java-gateway/alpine:alpine-local"
  "zabbix-snmptraps:snmptraps/alpine:alpine-local"
  "grafana:grafana:local"
)

CONTAINERS=(
  "postgres"
  "zabbix-java-gateway"
  "zabbix-snmptraps"
  "zabbix-server-pgsql"
  "zabbix-web-nginx-pgsql"
  "zabbix-agent"
  "zabbix-agent2"
  "grafana"
)

mkdir -p "${LOG_ROOT}"

ensure_env_files() {
  cd "${PROJECT_ROOT}"
  for env_file in .env_agent .env_db_pgsql .env_grafana .env_srv .env_web; do
    if [ ! -f "${env_file}" ] && [ -f "${env_file}.example" ]; then
      cp "${env_file}.example" "${env_file}"
    fi
  done
  for secret_file in .POSTGRES_USER .POSTGRES_PASSWORD; do
    if [ ! -f "${secret_file}" ] && [ -f "${secret_file}.example" ]; then
      cp "${secret_file}.example" "${secret_file}"
    fi
  done
}

ensure_runtime_dirs() {
  mkdir -p \
    "${PROJECT_ROOT}/zbx_env/var/lib/postgresql/data" \
    "${PROJECT_ROOT}/zbx_env/var/lib/postgresql/initdb" \
    "${PROJECT_ROOT}/zbx_env/usr/lib/zabbix/alertscripts" \
    "${PROJECT_ROOT}/zbx_env/usr/lib/zabbix/externalscripts" \
    "${PROJECT_ROOT}/zbx_env/var/lib/zabbix/modules" \
    "${PROJECT_ROOT}/zbx_env/var/lib/zabbix/enc" \
    "${PROJECT_ROOT}/zbx_env/var/lib/zabbix/ssh_keys" \
    "${PROJECT_ROOT}/zbx_env/var/lib/zabbix/snmptraps" \
    "${PROJECT_ROOT}/zbx_env/etc/ssl/nginx" \
    "${PROJECT_ROOT}/zbx_env/usr/share/zabbix/modules" \
    "${PROJECT_ROOT}/zbx_env/etc/grafana/provisioning" \
    "${PROJECT_ROOT}/zbx_env/var/lib/grafana" \
    "${PROJECT_ROOT}/zbx_env/var/lib/grafana/plugins"
}

create_networks() {
  ${PODMAN_BIN} network exists zbx_net_backend >/dev/null 2>&1 || ${PODMAN_BIN} network create zbx_net_backend
  ${PODMAN_BIN} network exists zbx_net_frontend >/dev/null 2>&1 || ${PODMAN_BIN} network create zbx_net_frontend
}

build_images() {
  cd "${PROJECT_ROOT}"
  for item in "${SERVICES[@]}"; do
    IFS=":" read -r name path tag <<< "${item}"
    if [ -f "${path}/Dockerfile" ]; then
      echo "Building ${name}..."
      ${PODMAN_BIN} build --format docker -t "${name}:${tag}" -f "${path}/Dockerfile" "${path}"
    else
      echo "Skipping ${name} (no Dockerfile at ${path}/Dockerfile)"
    fi
  done
}

start_containers() {
  cd "${PROJECT_ROOT}"
  ensure_env_files
  ensure_runtime_dirs
  create_networks

  POSTGRES_USER="$(cat .POSTGRES_USER 2>/dev/null || echo "zabbix")"
  POSTGRES_PASSWORD="$(cat .POSTGRES_PASSWORD 2>/dev/null || echo "zabbix")"

  ${PODMAN_BIN} run -d --replace --name postgres \
    --network zbx_net_backend \
    -e POSTGRES_USER="${POSTGRES_USER}" \
    -e POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
    -e POSTGRES_DB=zabbix \
    -v "${PROJECT_ROOT}/zbx_env/var/lib/postgresql/data:/var/lib/postgresql/data:rw,z" \
    -v /etc/localtime:/etc/localtime:ro \
    postgres:16-alpine

  if [ -f "${PROJECT_ROOT}/scripts/grafana/init-grafana-db.sh" ]; then
    bash "${PROJECT_ROOT}/scripts/grafana/init-grafana-db.sh" "${PODMAN_BIN}" || true
  fi

  ${PODMAN_BIN} run -d --replace --name zabbix-java-gateway \
    --network zbx_net_backend \
    --env-file "${PROJECT_ROOT}/.env_srv" \
    zabbix-java-gateway:alpine-local

  ${PODMAN_BIN} run -d --replace --name zabbix-snmptraps \
    --network zbx_net_backend \
    -e SNMP_LOGFILE=/var/log/snmptraps/snmptraps.log \
    zabbix-snmptraps:alpine-local

  ${PODMAN_BIN} run -d --replace --name zabbix-server-pgsql \
    --network zbx_net_backend \
    -p 10051:10051 \
    --env-file "${PROJECT_ROOT}/.env_db_pgsql" \
    --env-file "${PROJECT_ROOT}/.env_srv" \
    -v "${PROJECT_ROOT}/.POSTGRES_USER:/run/secrets/POSTGRES_USER:ro,z" \
    -v "${PROJECT_ROOT}/.POSTGRES_PASSWORD:/run/secrets/POSTGRES_PASSWORD:ro,z" \
    -e DB_SERVER_HOST=postgres \
    -e DB_SERVER_USER="${POSTGRES_USER}" \
    -e DB_SERVER_PASSWORD="${POSTGRES_PASSWORD}" \
    -e DB_SERVER_DBNAME=zabbix \
    -e ZBX_JAVAGATEWAY=zabbix-java-gateway \
    -e ZBX_JAVAGATEWAY_PORT=10052 \
    -e ZBX_SNMPTRAPPERFILE=/var/log/snmptraps/snmptraps.log \
    -e ZBX_SNMPTRAPPER=1 \
    -v "${PROJECT_ROOT}/zbx_env/usr/lib/zabbix/alertscripts:/usr/lib/zabbix/alertscripts:ro,z" \
    -v "${PROJECT_ROOT}/zbx_env/usr/lib/zabbix/externalscripts:/usr/lib/zabbix/externalscripts:ro,z" \
    -v "${PROJECT_ROOT}/zbx_env/var/lib/zabbix/modules:/var/lib/zabbix/modules:ro,z" \
    -v "${PROJECT_ROOT}/zbx_env/var/lib/zabbix/enc:/var/lib/zabbix/enc:ro,z" \
    -v "${PROJECT_ROOT}/zbx_env/var/lib/zabbix/ssh_keys:/var/lib/zabbix/ssh_keys:ro,z" \
    -v "${PROJECT_ROOT}/zbx_env/var/lib/zabbix/snmptraps:/var/lib/zabbix/snmptraps:ro,z" \
    -v /etc/localtime:/etc/localtime:ro \
    zabbix-server-pgsql:alpine-local

  ${PODMAN_BIN} run -d --replace --name zabbix-web-nginx-pgsql \
    --network zbx_net_backend \
    --network zbx_net_frontend \
    -p 8080:8080 \
    -p 8443:8443 \
    --env-file "${PROJECT_ROOT}/.env_db_pgsql" \
    --env-file "${PROJECT_ROOT}/.env_web" \
    -v "${PROJECT_ROOT}/.POSTGRES_USER:/run/secrets/POSTGRES_USER:ro,z" \
    -v "${PROJECT_ROOT}/.POSTGRES_PASSWORD:/run/secrets/POSTGRES_PASSWORD:ro,z" \
    -e DB_SERVER_HOST=postgres \
    -e DB_SERVER_USER="${POSTGRES_USER}" \
    -e DB_SERVER_PASSWORD="${POSTGRES_PASSWORD}" \
    -e DB_SERVER_DBNAME=zabbix \
    -e ZBX_SERVER_HOST=zabbix-server-pgsql \
    -v "${PROJECT_ROOT}/zbx_env/etc/ssl/nginx:/etc/ssl/nginx:ro,z" \
    -v "${PROJECT_ROOT}/zbx_env/usr/share/zabbix/modules:/usr/share/zabbix/modules:ro,z" \
    -v /etc/localtime:/etc/localtime:ro \
    zabbix-web-nginx-pgsql:alpine-local

  ${PODMAN_BIN} run -d --replace --name zabbix-agent \
    --network zbx_net_backend \
    --env-file "${PROJECT_ROOT}/.env_agent" \
    zabbix-agent:alpine-local

  ${PODMAN_BIN} run -d --replace --name zabbix-agent2 \
    --network zbx_net_backend \
    --env-file "${PROJECT_ROOT}/.env_agent" \
    zabbix-agent2:alpine-local

  if [ -f "${PROJECT_ROOT}/grafana/Dockerfile" ]; then
    if ! bash "${PROJECT_ROOT}/scripts/grafana/preflight.sh"; then
      echo "Skipping Grafana start due to failed preflight." >&2
      return 0
    fi
    ${PODMAN_BIN} run -d --replace --name grafana \
      --network zbx_net_backend \
      --network zbx_net_frontend \
      -p 3000:3000 \
      --env-file "${PROJECT_ROOT}/.env_grafana" \
      -e GF_DATABASE_USER__FILE=/run/secrets/GF_DATABASE_USER \
      -e GF_DATABASE_PASSWORD__FILE=/run/secrets/GF_DATABASE_PASSWORD \
      -e GF_SESSION_PROVIDER_CONFIG__FILE=/run/secrets/GF_SESSION_PROVIDER_CONFIG \
      -v "${PROJECT_ROOT}/.GF_DATABASE_USER:/run/secrets/GF_DATABASE_USER:ro,z" \
      -v "${PROJECT_ROOT}/.GF_DATABASE_PASSWORD:/run/secrets/GF_DATABASE_PASSWORD:ro,z" \
      -v "${PROJECT_ROOT}/.GF_SESSION_PROVIDER_CONFIG:/run/secrets/GF_SESSION_PROVIDER_CONFIG:ro,z" \
      grafana:local || true
  fi
}

stop_containers() {
  for name in "${CONTAINERS[@]}"; do
    if ${PODMAN_BIN} ps -a --format "{{.Names}}" | grep -q "^${name}$"; then
      ${PODMAN_BIN} stop "${name}" >/dev/null 2>&1 || true
      ${PODMAN_BIN} rm "${name}" >/dev/null 2>&1 || true
    fi
  done
}

collect_logs() {
  local out_dir="${LOG_ROOT}/podman_${TIMESTAMP}"
  mkdir -p "${out_dir}"

  for name in "${CONTAINERS[@]}"; do
    if ${PODMAN_BIN} ps -a --format "{{.Names}}" | grep -q "^${name}$"; then
      ${PODMAN_BIN} logs "${name}" > "${out_dir}/${name}.log" 2>&1 || true
    fi
  done

  echo "Logs saved to: ${out_dir}"
}

follow_logs() {
  local out_dir="${LOG_ROOT}/live_${TIMESTAMP}"
  local pid_file="${out_dir}/pids.txt"
  mkdir -p "${out_dir}"
  : > "${pid_file}"

  for name in "${CONTAINERS[@]}"; do
    if ${PODMAN_BIN} ps -a --format "{{.Names}}" | grep -q "^${name}$"; then
      (${PODMAN_BIN} logs -f "${name}" >> "${out_dir}/${name}.log" 2>&1 & echo "$!" >> "${pid_file}")
    fi
  done

  echo "Log follow started. PID list: ${pid_file}"
}

stop_follow() {
  local latest_dir
  latest_dir="$(ls -dt "${LOG_ROOT}/live_"* 2>/dev/null | head -1 || true)"
  if [ -z "${latest_dir}" ]; then
    echo "No live log directory found."
    exit 0
  fi

  if [ -f "${latest_dir}/pids.txt" ]; then
    while IFS= read -r pid; do
      kill "${pid}" >/dev/null 2>&1 || true
    done < "${latest_dir}/pids.txt"
    echo "Stopped log followers from ${latest_dir}"
  else
    echo "No PID file found in ${latest_dir}"
  fi
}

status() {
  ${PODMAN_BIN} ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

usage() {
  cat << 'EOF'
Usage: scripts/podman-automation.sh <command>

Commands:
  build        Build all images
  up           Start all containers
  down         Stop and remove containers
  logs         Collect current logs (snapshot)
  follow       Start live log collection in background
  stop-follow  Stop live log collection
  status       Show container status
    note         Web UI uses http://localhost:8080 and https://localhost:8443 in rootless mode
  full         Build images, start containers, collect logs
EOF
}

cmd="${1:-}"
case "${cmd}" in
  build) build_images ;;
  up) start_containers ;;
  down) stop_containers ;;
  logs) collect_logs ;;
  follow) follow_logs ;;
  stop-follow) stop_follow ;;
  status) status ;;
  full) build_images; start_containers; collect_logs ;;
  *) usage; exit 1 ;;
esac
