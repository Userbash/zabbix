#!/bin/bash
# Verify Grafana database, role, and privileges in Postgres.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# shellcheck source=../test-module/common.sh
source "${PROJECT_ROOT}/scripts/test-module/common.sh"

RUNTIME="$(get_runtime "${1:-}")"
if [ -z "${RUNTIME}" ]; then
  echo "No container runtime found (podman/docker)." >&2
  exit 1
fi

POSTGRES_USER_FILE="${PROJECT_ROOT}/.POSTGRES_USER"
POSTGRES_PASSWORD_FILE="${PROJECT_ROOT}/.POSTGRES_PASSWORD"
GF_DB_USER_FILE="${PROJECT_ROOT}/.GF_DATABASE_USER"
GF_DB_NAME="${GF_DATABASE_NAME:-grafana}"

POSTGRES_USER="$(cat "${POSTGRES_USER_FILE}" 2>/dev/null || echo "postgres")"
POSTGRES_PASSWORD="$(cat "${POSTGRES_PASSWORD_FILE}" 2>/dev/null || echo "postgres")"
GF_DB_USER="$(cat "${GF_DB_USER_FILE}" 2>/dev/null || echo "grafana")"

exec_psql() {
  ${RUNTIME} exec -e PGPASSWORD="${POSTGRES_PASSWORD}" postgres \
    psql -U "${POSTGRES_USER}" -tAc "$1"
}

role_exists="$(exec_psql "SELECT 1 FROM pg_roles WHERE rolname='${GF_DB_USER}'")"
if [ "${role_exists}" != "1" ]; then
  echo "Missing role: ${GF_DB_USER}" >&2
  exit 1
fi

db_exists="$(exec_psql "SELECT 1 FROM pg_database WHERE datname='${GF_DB_NAME}'")"
if [ "${db_exists}" != "1" ]; then
  echo "Missing database: ${GF_DB_NAME}" >&2
  exit 1
fi

owner="$(exec_psql "SELECT pg_catalog.pg_get_userbyid(datdba) FROM pg_database WHERE datname='${GF_DB_NAME}'")"
if [ "${owner}" != "${GF_DB_USER}" ]; then
  echo "Database ${GF_DB_NAME} owner is ${owner}, expected ${GF_DB_USER}" >&2
  exit 1
fi

echo "Grafana DB checks OK: role=${GF_DB_USER}, db=${GF_DB_NAME}"