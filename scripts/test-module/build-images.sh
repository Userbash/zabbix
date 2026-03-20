#!/bin/bash
# Build Zabbix images using the specified runtime.

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

SERVICES=(
  "zabbix-server-pgsql:server-pgsql/alpine:alpine-local"
  "zabbix-web-nginx-pgsql:web-nginx-pgsql/alpine:alpine-local"
  "zabbix-agent:agent/alpine:alpine-local"
  "zabbix-agent2:agent2/alpine:alpine-local"
  "zabbix-java-gateway:java-gateway/alpine:alpine-local"
  "zabbix-snmptraps:snmptraps/alpine:alpine-local"
  "grafana:grafana:local"
)

cd "${PROJECT_ROOT}"
for item in "${SERVICES[@]}"; do
  IFS=":" read -r name path tag <<< "${item}"
  if [ -f "${path}/Dockerfile" ]; then
    echo "Building ${name}..."
    "${RUNTIME}" build --format docker -t "${name}:${tag}" -f "${path}/Dockerfile" "${path}"
  else
    echo "Skipping ${name} (no Dockerfile at ${path}/Dockerfile)"
  fi
done
