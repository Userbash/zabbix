#!/bin/sh
set -e

if [ -n "${GF_DATABASE_NAME_FILE:-}" ]; then
  GF_DATABASE_NAME="$(cat "${GF_DATABASE_NAME_FILE}")"
fi
if [ -n "${GF_DATABASE_USER_FILE:-}" ]; then
  GF_DATABASE_USER="$(cat "${GF_DATABASE_USER_FILE}")"
fi
if [ -n "${GF_DATABASE_PASSWORD_FILE:-}" ]; then
  GF_DATABASE_PASSWORD="$(cat "${GF_DATABASE_PASSWORD_FILE}")"
fi

: "${GF_DATABASE_NAME:=grafana}"
: "${GF_DATABASE_USER:=grafana}"
: "${GF_DATABASE_PASSWORD:=grafana}"

psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${POSTGRES_DB}" <<-EOSQL
  SELECT 'Grafana init start' AS info;
EOSQL

if ! psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${GF_DATABASE_USER}'" | grep -q 1; then
  psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${POSTGRES_DB}" \
    -c "CREATE ROLE \"${GF_DATABASE_USER}\" LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT PASSWORD '${GF_DATABASE_PASSWORD}';"
fi

if ! psql -tAc "SELECT 1 FROM pg_database WHERE datname='${GF_DATABASE_NAME}'" | grep -q 1; then
  psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${POSTGRES_DB}" \
    -c "CREATE DATABASE \"${GF_DATABASE_NAME}\" OWNER \"${GF_DATABASE_USER}\";"
fi

psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${POSTGRES_DB}" \
  -c "REVOKE ALL ON DATABASE \"${GF_DATABASE_NAME}\" FROM PUBLIC;"
psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${POSTGRES_DB}" \
  -c "GRANT CONNECT, TEMPORARY ON DATABASE \"${GF_DATABASE_NAME}\" TO \"${GF_DATABASE_USER}\";"
psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${GF_DATABASE_NAME}" \
  -c "REVOKE ALL ON SCHEMA public FROM PUBLIC;"
psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${GF_DATABASE_NAME}" \
  -c "GRANT USAGE, CREATE ON SCHEMA public TO \"${GF_DATABASE_USER}\";"
