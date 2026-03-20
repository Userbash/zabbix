# Project Documentation (English)

## Overview
This repository provides a full Zabbix monitoring stack with Grafana dashboards, built for rootless Podman or Docker. It includes automation scripts, secret management, and CI secret scanning for safe publication.

## Stack Components
- PostgreSQL 16 (storage)
- Zabbix Server 7.0.0
- Zabbix Web UI (Nginx + PHP)
- Java Gateway (JMX)
- SNMP Traps receiver
- Grafana 11.5.x

## Networks
- Backend: internal-only services (Postgres, Zabbix server, Java gateway, SNMP traps)
- Frontend: user-facing services (Zabbix UI, Grafana)

## Ports
- Zabbix UI: 8080 / 8443
- Grafana: 3000
- Zabbix Server: 10051
- Java Gateway: 10052

## Secrets and Credentials
Secrets are stored in files that are ignored by git and passed via `*_FILE` variables.

Required local secret files:
- `.POSTGRES_USER`
- `.POSTGRES_PASSWORD`
- `.GF_DATABASE_USER`
- `.GF_DATABASE_PASSWORD`
- `.GF_SESSION_PROVIDER_CONFIG`

Example templates are provided with `.example` suffix.

## Automation Scripts
- `scripts/podman-automation.sh`: build, start, stop, logs
- `scripts/test-module/*`: build + run + log analysis
- `scripts/grafana/init-grafana-db.sh`: ensures Grafana role and DB
- `scripts/grafana/preflight.sh`: prevents bad config before start
- `scripts/security/preflight-secrets.sh`: checks secrets before publish

## Logging and Diagnostics
- Runtime logs and metadata stored in `logs/`
- `log-collector.sh` exports inspect JSON and summary
- Health checks indicate container readiness

## Upgrades
### Zabbix 5.0.0 -> 7.0.0
- Updated images and build configs for 7.0.x
- Newer frontend dependencies (PHP 8.x)
- Updated health checks and container wiring

### Grafana 9.x -> 11.5.x
- Angular plugins disabled by default
- Plugin list updated for compatibility
- Secrets handled via `*_FILE`

## Publishing
- `.gitignore` excludes secrets and runtime data
- gitleaks runs in CI and via pre-commit
- Optional sops/age encryption
- See `docs/PUBLISHING.md`

## Screenshots
Add screenshots to `docs/images/` and link them from README:
- Zabbix dashboard
- Grafana home
