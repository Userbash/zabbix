#!/bin/bash
# Start Zabbix containers using the specified runtime.

set -euo pipefail

RUNTIME="${1:-}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# shellcheck source=common.sh
source "${PROJECT_ROOT}/scripts/test-module/common.sh"

RUNTIME="$(get_runtime "${RUNTIME}")"
if [ -z "${RUNTIME}" ]; then
  echo "No container runtime found (podman/docker)." >&2
  exit 1
fi

cd "${PROJECT_ROOT}"

ensure_env_files "${PROJECT_ROOT}"
ensure_runtime_dirs "${PROJECT_ROOT}"

POSTGRES_USER="$(cat .POSTGRES_USER 2>/dev/null || echo "zabbix")"
POSTGRES_PASSWORD="$(cat .POSTGRES_PASSWORD 2>/dev/null || echo "zabbix")"

create_networks "${RUNTIME}"

"${RUNTIME}" run -d --replace --name postgres \
  --network zbx_net_backend \
  -e POSTGRES_USER="${POSTGRES_USER}" \
  -e POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
  -e POSTGRES_DB=zabbix \
  -v "${PROJECT_ROOT}/zbx_env/var/lib/postgresql/data:/var/lib/postgresql/data:rw,z" \
  -v /etc/localtime:/etc/localtime:ro \
  postgres:16-alpine

if [ -f "${PROJECT_ROOT}/scripts/grafana/init-grafana-db.sh" ]; then
  bash "${PROJECT_ROOT}/scripts/grafana/init-grafana-db.sh" "${RUNTIME}" || true
fi

"${RUNTIME}" run -d --replace --name zabbix-java-gateway \
  --network zbx_net_backend \
  --env-file "${PROJECT_ROOT}/.env_srv" \
  zabbix-java-gateway:alpine-local

"${RUNTIME}" run -d --replace --name zabbix-snmptraps \
  --network zbx_net_backend \
  -e SNMP_LOGFILE=/var/log/snmptraps/snmptraps.log \
  zabbix-snmptraps:alpine-local

"${RUNTIME}" run -d --replace --name zabbix-server-pgsql \
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

"${RUNTIME}" run -d --replace --name zabbix-web-nginx-pgsql \
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

"${RUNTIME}" run -d --replace --name zabbix-agent \
  --network zbx_net_backend \
  --env-file "${PROJECT_ROOT}/.env_agent" \
  zabbix-agent:alpine-local

"${RUNTIME}" run -d --replace --name zabbix-agent2 \
  --network zbx_net_backend \
  --env-file "${PROJECT_ROOT}/.env_agent" \
  zabbix-agent2:alpine-local

if [ -f "${PROJECT_ROOT}/grafana/Dockerfile" ]; then
  if ! bash "${PROJECT_ROOT}/scripts/grafana/preflight.sh"; then
    echo "Skipping Grafana start due to failed preflight." >&2
    exit 1
  fi
  "${RUNTIME}" run -d --replace --name grafana \
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
