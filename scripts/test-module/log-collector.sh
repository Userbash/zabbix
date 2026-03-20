#!/bin/bash
# Collect container logs, metadata, and stats.

set -euo pipefail

RUNTIME="${1:-}"
OUT_DIR="${2:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

RUNTIME="$(get_runtime "${RUNTIME}")"

if [ -z "${OUT_DIR}" ]; then
  echo "Usage: log-collector.sh <runtime> <output-dir>" >&2
  exit 1
fi

mkdir -p "${OUT_DIR}/logs" "${OUT_DIR}/inspect" "${OUT_DIR}/stats"

if [ -z "${RUNTIME}" ]; then
  {
    echo "Runtime: not found"
    echo "Reason: podman/docker not in PATH"
  } > "${OUT_DIR}/runtime-info.txt"
  echo "No container runtime found (podman/docker)." >&2
  exit 1
fi

EXPECTED_CONTAINERS=(
  "postgres"
  "zabbix-java-gateway"
  "zabbix-snmptraps"
  "zabbix-server-pgsql"
  "zabbix-web-nginx-pgsql"
  "zabbix-agent"
  "zabbix-agent2"
  "grafana"
)

{
  echo "Runtime: ${RUNTIME}"
  "${RUNTIME}" --version 2>&1 || true
  echo "--- ps -a ---"
  "${RUNTIME}" ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>&1 || true
} > "${OUT_DIR}/runtime-info.txt"
"${RUNTIME}" ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" > "${OUT_DIR}/containers.txt" 2>&1 || true

mapfile -t RUNTIME_CONTAINERS < <("${RUNTIME}" ps -a --format "{{.Names}}" 2>/dev/null || true)
if [ ${#RUNTIME_CONTAINERS[@]} -eq 0 ]; then
  echo "No containers found in runtime" >> "${OUT_DIR}/runtime-info.txt"
fi

declare -A EXPECTED_SET=()
for name in "${EXPECTED_CONTAINERS[@]}"; do
  EXPECTED_SET["${name}"]=1
done

collect_container() {
  local name="$1"
  "${RUNTIME}" logs "${name}" > "${OUT_DIR}/logs/${name}.log" 2>&1 || true
  "${RUNTIME}" inspect "${name}" > "${OUT_DIR}/inspect/${name}.json" 2>&1 || true
}

for name in "${EXPECTED_CONTAINERS[@]}"; do
  if "${RUNTIME}" ps -a --format "{{.Names}}" | grep -q "^${name}$"; then
    collect_container "${name}"
  else
    echo "Container not found: ${name}" > "${OUT_DIR}/logs/${name}.log"
  fi
done

for name in "${RUNTIME_CONTAINERS[@]}"; do
  if [ -z "${EXPECTED_SET["${name}"]+x}" ]; then
    collect_container "${name}"
  fi
done

"${RUNTIME}" stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}\t{{.CPUPerc}}\t{{.NetIO}}\t{{.BlockIO}}" \
  > "${OUT_DIR}/stats/resources.txt" 2>&1 || true

if command -v jq >/dev/null 2>&1; then
  for f in "${OUT_DIR}/inspect/"*.json; do
    [ -f "${f}" ] || continue
    jq '.[0] | {id: .Id, name: .Name, state: .State, network: .NetworkSettings.Networks}' "${f}" \
      > "${OUT_DIR}/inspect/$(basename "${f}" .json).summary.json" || true
  done
fi
