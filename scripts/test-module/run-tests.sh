#!/bin/bash
# Test module: deploy, validate, and collect logs for Zabbix containers.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MODULE_DIR="${PROJECT_ROOT}/scripts/test-module"
LOG_ROOT="${PROJECT_ROOT}/logs"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
RUN_DIR="${LOG_ROOT}/test_run_${TIMESTAMP}"

# shellcheck source=common.sh
source "${MODULE_DIR}/common.sh"

RUNTIME="$(get_runtime "")"
if [ -z "${RUNTIME}" ]; then
  echo "No container runtime found (podman/docker)." >&2
  exit 1
fi

mkdir -p "${RUN_DIR}"

# Optional: allow forcing runtime via env (handled by get_runtime)

# Build images if requested
if [ "${1:-}" = "build" ]; then
  if [ -x "${PROJECT_ROOT}/scripts/podman-automation.sh" ]; then
    "${PROJECT_ROOT}/scripts/podman-automation.sh" build
  else
    "${MODULE_DIR}/build-images.sh" "${RUNTIME}"
  fi
  shift || true
fi

# Start containers if requested
if [ "${1:-}" = "up" ]; then
  if [ -x "${PROJECT_ROOT}/scripts/podman-automation.sh" ]; then
    "${PROJECT_ROOT}/scripts/podman-automation.sh" up
  else
    "${MODULE_DIR}/start-containers.sh" "${RUNTIME}"
  fi
  shift || true
fi

# Collect logs and analyze
"${MODULE_DIR}/log-collector.sh" "${RUNTIME}" "${RUN_DIR}"
"${MODULE_DIR}/log-analyzer.sh" "${RUN_DIR}"

echo "Run complete: ${RUN_DIR}"
