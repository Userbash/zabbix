#!/bin/bash
# Fail if obvious secret files are tracked or if unsafe vars exist in .env_grafana.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if git -C "${ROOT}" ls-files -z | grep -qzE "(^|/)\\.env$|\\.POSTGRES_.*|\\.GF_.*"; then
  echo "Secret files are tracked by git. Remove them before publishing." >&2
  exit 1
fi

if [ -f "${ROOT}/.env_grafana" ]; then
  if grep -qE '^GF_DATABASE_(USER|PASSWORD)=' "${ROOT}/.env_grafana"; then
    echo "Remove GF_DATABASE_USER/PASSWORD from .env_grafana and use *_FILE secrets." >&2
    exit 1
  fi
fi

echo "Secret preflight OK."
