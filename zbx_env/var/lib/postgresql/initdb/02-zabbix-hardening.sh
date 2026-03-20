#!/bin/sh
set -e

: "${POSTGRES_DB:=zabbix_db}"
: "${POSTGRES_USER:=zabbix}"

# Lock down public access and grant only what Zabbix needs.
psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${POSTGRES_DB}" \
  -c "REVOKE ALL ON DATABASE \"${POSTGRES_DB}\" FROM PUBLIC;"
psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${POSTGRES_DB}" \
  -c "REVOKE ALL ON SCHEMA public FROM PUBLIC;"
psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${POSTGRES_DB}" \
  -c "GRANT CONNECT, TEMPORARY ON DATABASE \"${POSTGRES_DB}\" TO \"${POSTGRES_USER}\";"
psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${POSTGRES_DB}" \
  -c "GRANT USAGE, CREATE ON SCHEMA public TO \"${POSTGRES_USER}\";"
