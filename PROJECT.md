# Project Overview

This is a complete, production-ready Zabbix monitoring stack that works out of the box on Linux, macOS, WSL2, and other platforms. Everything runs in containers - PostgreSQL, Zabbix server, web UI, Java monitoring, SNMP support, and Grafana for extra dashboards.

## What You Get

- Full Zabbix monitoring stack all configured and ready
- Containers run as your regular user, not root - it's secure by default
- Automatic setup - install script detects your OS and picks the right runtime
- Works on Fedora, Ubuntu, Debian, CentOS, macOS, WSL2, and Flatpak
- MIT Licensed - use it however you want

## Quick Start

```bash
bash scripts/install-runtime.sh
bash scripts/rebuild-from-scratch.sh
```

Then go to http://localhost and you're monitoring things.

## What's Inside

**The six main services:**

- PostgreSQL 16 for storing all your data
- Zabbix Server that does the actual monitoring
- Web UI using Nginx and PHP so you can see what's happening
- Java Gateway for monitoring JMX applications
- SNMP Traps for receiving SNMP alerts
- Grafana for making fancy dashboards

**Project structure:**

```
zabbix/
├── README.md                     # How to use it
├── SECURITY.md                   # Security and best practices
├── CONTRIBUTING.md               # How to help out
├── docker-compose.yaml           # All services defined
├── LICENSE                       # MIT
├── scripts/                      # Automation scripts
├── server-pgsql/                 # Server configuration
├── web-nginx-pgsql/              # Web UI setup
├── java-gateway/                 # JMX monitoring
├── snmptraps/                    # SNMP receiver
└── grafana/                      # Grafana setup
```

## Security by Default

Every deployment automatically gets:

- Rootless containers (no root needed)
- User namespace isolation - containers can't see your files
- Minimal Linux capabilities - only what services actually need
- Network isolation - database stays internal, web UI is public
- Health checks that tell you when something dies
- Resource limits so one container can't crash the whole system

Passwords go in .env which never gets committed. You can change them whenever you want.

## What You Need

**Bare minimum:**
- 2GB RAM
- 5GB disk
- 2 CPU cores
- Linux, macOS, or WSL2

**Better experience:**
- 4GB+ RAM
- 20GB+ disk
- 4+ cores
- Native Linux (Fedora, Ubuntu, or Debian)

## How It Works

The web UI runs on your actual network so you can access it. Everything else (database, monitoring engine) stays internal and can't be reached from outside. Services talk to each other automatically through Docker/Podman's DNS system.

## Technology

- Podman 3.0+ for containers (or Docker 20.10+ as fallback)
- Docker Compose 3.8+ to orchestrate everything
- PostgreSQL 16 database
- Zabbix 6.0+ monitoring engine
- Nginx latest for the web server
- PHP 7.4+ for the web interface

## Typical Uses

**Development:**
```bash
bash scripts/rebuild-from-scratch.sh
podman logs -f zabbix-server
```

**Testing:**
```bash
podman-compose up -d
# run your tests
```

**Production:**
```bash
podman exec postgres pg_dump zabbix > backup.sql
git pull
bash scripts/rebuild-from-scratch.sh
```

## Help Out

This is completely open source. We'd love contributions:

- Found a bug? Open an issue
- Have an idea? Suggest it
- Want to write docs? Go for it
- Want to test on your platform? Perfect

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to do it.

## Resources

- [Podman Docs](https://podman.io/docs/)
- [Zabbix Docs](https://www.zabbix.com/documentation/)
- [Docker Compose](https://docs.docker.com/compose/)
- [PostgreSQL Manual](https://www.postgresql.org/docs/)

## License

MIT License - use it however you want. See [LICENSE](LICENSE)for details.

## What's Next

We've got some ideas:
- Kubernetes support (working on it)
- High availability setups
- Better monitoring templates
- More platform support

## ⭐ Why Choose This Project?

1. **✅ Secure** - Enterprise-grade security by default
2. **✅ Simple** - One-command installation
3. **✅ Flexible** - Works anywhere (Linux, Mac, WSL2, Flatpak)
4. **✅ Professional** - Production-ready
5. **✅ Open** - MIT Licensed, fully open-source
6. **✅ Supported** - Active community and maintenance

---

**Version:** 3.0 | **Updated:** March 2026 | **Status:** Production Ready

🚀 **Ready to start? See [README.md](README.md)**
