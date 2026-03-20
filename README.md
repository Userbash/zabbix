 # Zabbix Stack (Podman/Docker)

A production-ready Zabbix + Grafana stack with PostgreSQL, built for rootless Podman or Docker. This repository includes automation scripts, secret handling, and CI secret scans for safe publishing.

[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE) [![Podman 3.0+](https://img.shields.io/badge/Podman-3.0+-blue.svg)](https://podman.io) [![Docker 20.10+](https://img.shields.io/badge/Docker-20.10+-blue.svg)](https://docker.com)

---

## Quick Start

```bash
bash scripts/install-runtime.sh
bash scripts/rebuild-from-scratch.sh
```

Open:
- Zabbix web UI: http://localhost:8080
- Grafana: http://localhost:3000

Default credentials:
- Zabbix: `Admin` / `zabbix`
- Grafana: `admin` / `admin` (change on first login)

---

## What's Included

- PostgreSQL 16 for storage
- Zabbix Server 7.0.0
- Web UI (Nginx + PHP)
- Java Gateway (JMX)
- SNMP Traps receiver
- Grafana 11.5.x

Security by default:
- Rootless containers (no root daemon)
- Split backend/frontend networks
- Health checks
- Resource limits
- Secrets via files (no plaintext in git)

---

## Ports

- Zabbix web UI: 8080 (HTTP), 8443 (HTTPS)
- Grafana: 3000
- Zabbix Server: 10051
- Java Gateway: 10052

---

## Automation Highlights

- `scripts/podman-automation.sh` and `scripts/test-module/*` for build/run/log collection
- Automatic runtime directory bootstrap to avoid missing-path errors
- Grafana DB auto-init and preflight checks
- Secrets preflight for publishing
- CI secret scan (gitleaks)

---

## Upgrade Notes

### Zabbix 5.0.0 -> 7.0.0 (Project Upgrade)

- Updated images and build configs for Zabbix 7.0.x.
- PHP and web stack aligned with newer Zabbix frontend requirements.
- Updated health checks and container wiring.
- Expect updated templates and UI changes from upstream Zabbix.

### Grafana 9.x -> 11.5.x (Project Upgrade)

- Angular-based plugins are disabled by default in Grafana 11.
- Plugin set updated to avoid unsupported plugins.
- Secrets are provided via `*_FILE` to avoid plaintext env vars.

---

## Logging and Build Observability

- Build and runtime logs are collected into `logs/`.
- `scripts/test-module/log-collector.sh` exports JSON summaries.
- Health checks make container status visible immediately.

---

## Publishing and Secrets

- `.gitignore` excludes local secret files
- `gitleaks` pre-commit hook and CI scan
- Optional sops/age encryption
- See [docs/PUBLISHING.md](docs/PUBLISHING.md)

---

## Screenshots

Add screenshots under `docs/images/` and update this section with links:

- Zabbix dashboard
- Grafana home

---

## Project Layout

```
zabbix/
├── README.md
├── docker-compose.yaml
├── scripts/
├── server-pgsql/
├── web-nginx-pgsql/
├── java-gateway/
├── snmptraps/
├── grafana/
└── zbx_env/
```

---

## Troubleshooting

```bash
podman logs <container>
podman inspect <container> | grep ExitCode
```

DNS issues inside containers:
```bash
podman run --dns 8.8.8.8 --dns 1.1.1.1 alpine ping 8.8.8.8
```
- zabbix-web (port 80/443)
- grafana (port 3000)

So the database never gets exposed to the internet, only the web UI does.

---

## Contributing

If you find bugs or have ideas, open an issue or PR. See CONTRIBUTING.md for the details.

---

## License

MIT - do whatever you want with it.

---

## Help

Something broken? Check SECURITY.md for security stuff. Look at docker-compose.yaml for service details.

---

---

Version 3.0. Last updated March 2026.

