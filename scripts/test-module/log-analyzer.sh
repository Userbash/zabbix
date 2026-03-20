#!/bin/bash
# Wrapper for Python log analyzer with optional extra dependencies.

set -euo pipefail

RUN_DIR="${1:-}"
if [ -z "${RUN_DIR}" ]; then
  echo "Usage: log-analyzer.sh <run-dir>" >&2
  exit 1
fi

if command -v python3 >/dev/null 2>&1; then
  python3 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/log-analyzer.py" "${RUN_DIR}"
else
  echo "python3 not found; skipping analysis." >&2
fi
