# Project Overview

This repository provides a full Zabbix monitoring stack with Grafana dashboards. It is designed for rootless Podman (or Docker) and includes automation scripts, secret handling, and CI secret scanning.

## Quick Start

```bash
bash scripts/install-runtime.sh
bash scripts/rebuild-from-scratch.sh
```

Open http://localhost:8080.

## What's Included

- PostgreSQL 16
- Zabbix Server 7.0.0
- Web UI (Nginx + PHP)
- Java Gateway (JMX)
- SNMP Traps receiver
- Grafana 11.5.x

## Key Design Choices

- Rootless containers by default
- Backend and frontend networks separated
- Health checks for critical services
- Secrets provided via `*_FILE`

## Requirements

- Podman 3.0+ or Docker 20.10+
- Docker Compose 3.8+
- 2 GB RAM minimum (4 GB recommended)

## Project Layout

```
zabbix/
├── README.md
├── docs/
├── docker-compose.yaml
├── scripts/
├── server-pgsql/
├── web-nginx-pgsql/
├── java-gateway/
├── snmptraps/
├── grafana/
└── zbx_env/
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Resources

- [Podman Docs](https://podman.io/docs/)
- [Zabbix Docs](https://www.zabbix.com/documentation/)
- [Docker Compose](https://docs.docker.com/compose/)
- [PostgreSQL Manual](https://www.postgresql.org/docs/)

## License

MIT License. See [LICENSE](LICENSE).
