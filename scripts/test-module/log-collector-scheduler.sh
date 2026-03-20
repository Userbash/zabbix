#!/bin/bash
# Periodic log snapshot collector (run from cron or systemd timer).

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_ROOT="${PROJECT_ROOT}/logs"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
OUT_DIR="${LOG_ROOT}/scheduled_${TIMESTAMP}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

RUNTIME="$(get_runtime "")"

if [ -z "${RUNTIME}" ]; then
  echo "No container runtime found (podman/docker)." >&2
  exit 1
fi

"${PROJECT_ROOT}/scripts/test-module/log-collector.sh" "${RUNTIME}" "${OUT_DIR}"
"${PROJECT_ROOT}/scripts/test-module/log-analyzer.sh" "${OUT_DIR}"
