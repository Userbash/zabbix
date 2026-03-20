#!/bin/bash
# Validate Grafana secrets and configuration before starting the container.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env_grafana"

fail() {
  echo "Grafana preflight failed: $1" >&2
  exit 1
}

if [ ! -f "${PROJECT_ROOT}/.GF_DATABASE_USER" ]; then
  fail "missing .GF_DATABASE_USER secret file"
fi
if [ ! -s "${PROJECT_ROOT}/.GF_DATABASE_USER" ]; then
  fail ".GF_DATABASE_USER is empty"
fi

if [ ! -f "${PROJECT_ROOT}/.GF_DATABASE_PASSWORD" ]; then
  fail "missing .GF_DATABASE_PASSWORD secret file"
fi
if [ ! -s "${PROJECT_ROOT}/.GF_DATABASE_PASSWORD" ]; then
  fail ".GF_DATABASE_PASSWORD is empty"
fi

if [ ! -f "${PROJECT_ROOT}/.GF_SESSION_PROVIDER_CONFIG" ]; then
  fail "missing .GF_SESSION_PROVIDER_CONFIG secret file"
fi
if [ ! -s "${PROJECT_ROOT}/.GF_SESSION_PROVIDER_CONFIG" ]; then
  fail ".GF_SESSION_PROVIDER_CONFIG is empty"
fi

if [ -f "${ENV_FILE}" ]; then
  if grep -qE '^GF_DATABASE_USER=' "${ENV_FILE}"; then
    fail "GF_DATABASE_USER must be removed from .env_grafana when using *_FILE secrets"
  fi
  if grep -qE '^GF_DATABASE_PASSWORD=' "${ENV_FILE}"; then
    fail "GF_DATABASE_PASSWORD must be removed from .env_grafana when using *_FILE secrets"
  fi
  if grep -qE '^GF_SESSION_PROVIDER_CONFIG=' "${ENV_FILE}"; then
    fail "GF_SESSION_PROVIDER_CONFIG must be removed from .env_grafana when using *_FILE secrets"
  fi
  if grep -qE '^GF_INSTALL_PLUGINS=.*grafana-simple-json-datasource' "${ENV_FILE}"; then
    fail "grafana-simple-json-datasource uses Angular and is blocked in Grafana 11"
  fi
fi

exit 0
