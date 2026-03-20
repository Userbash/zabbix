#!/bin/bash
# Ensure Grafana role and database exist in the main Postgres container.

set -euo pipefail

RUNTIME="${1:-podman}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

POSTGRES_USER_FILE="${PROJECT_ROOT}/.POSTGRES_USER"
POSTGRES_PASSWORD_FILE="${PROJECT_ROOT}/.POSTGRES_PASSWORD"
GF_DB_USER_FILE="${PROJECT_ROOT}/.GF_DATABASE_USER"
GF_DB_PASSWORD_FILE="${PROJECT_ROOT}/.GF_DATABASE_PASSWORD"

POSTGRES_USER="$(cat "${POSTGRES_USER_FILE}" 2>/dev/null || echo "postgres")"
POSTGRES_PASSWORD="$(cat "${POSTGRES_PASSWORD_FILE}" 2>/dev/null || echo "postgres")"
GF_DB_USER="$(cat "${GF_DB_USER_FILE}" 2>/dev/null || echo "grafana")"
GF_DB_PASSWORD="$(cat "${GF_DB_PASSWORD_FILE}" 2>/dev/null || echo "grafana")"
GF_DB_NAME="grafana"

if [ -f "${PROJECT_ROOT}/.env_grafana" ]; then
  GF_DB_NAME="$(grep -E '^GF_DATABASE_NAME=' "${PROJECT_ROOT}/.env_grafana" | tail -n 1 | cut -d= -f2)"
  if [ -z "${GF_DB_NAME}" ]; then
    GF_DB_NAME="grafana"
  fi
fi

wait_seconds="${GF_DATABASE_WAIT_TIMEOUT:-60}"
start_time="$(date +%s)"

while true; do
  if "${RUNTIME}" exec postgres pg_isready -U "${POSTGRES_USER}" >/dev/null 2>&1; then
    break
  fi
  if [ $(( $(date +%s) - start_time )) -ge "${wait_seconds}" ]; then
    echo "Postgres not ready after ${wait_seconds}s." >&2
    exit 1
  fi
  sleep 2
done

exec_psql() {
  "${RUNTIME}" exec -e PGPASSWORD="${POSTGRES_PASSWORD}" postgres \
    psql -U "${POSTGRES_USER}" -tAc "$1"
}

role_exists="$(exec_psql "SELECT 1 FROM pg_roles WHERE rolname='${GF_DB_USER}'")"
if [ "${role_exists}" != "1" ]; then
  "${RUNTIME}" exec -e PGPASSWORD="${POSTGRES_PASSWORD}" postgres \
    psql -U "${POSTGRES_USER}" -d postgres \
    -c "CREATE ROLE \"${GF_DB_USER}\" LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT PASSWORD '${GF_DB_PASSWORD}';"
else
  "${RUNTIME}" exec -e PGPASSWORD="${POSTGRES_PASSWORD}" postgres \
    psql -U "${POSTGRES_USER}" -d postgres \
    -c "ALTER ROLE \"${GF_DB_USER}\" PASSWORD '${GF_DB_PASSWORD}';"
fi

db_exists="$(exec_psql "SELECT 1 FROM pg_database WHERE datname='${GF_DB_NAME}'")"
if [ "${db_exists}" != "1" ]; then
  "${RUNTIME}" exec -e PGPASSWORD="${POSTGRES_PASSWORD}" postgres \
    psql -U "${POSTGRES_USER}" -d postgres \
    -c "CREATE DATABASE \"${GF_DB_NAME}\" OWNER \"${GF_DB_USER}\";"
fi

"${RUNTIME}" exec -e PGPASSWORD="${POSTGRES_PASSWORD}" postgres \
  psql -U "${POSTGRES_USER}" -d "${GF_DB_NAME}" \
  -c "REVOKE ALL ON SCHEMA public FROM PUBLIC; GRANT USAGE, CREATE ON SCHEMA public TO \"${GF_DB_USER}\";"

printf "Grafana DB ensured: role=%s db=%s\n" "${GF_DB_USER}" "${GF_DB_NAME}"
