# Zabbix with Podman and Docker Compose

A complete, production-ready Zabbix setup that just works. It handles all the container stuff for you, works on basically any Linux system (macOS and WSL2 too), and doesn't require root privileges to run.

[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE) [![Podman 3.0+](https://img.shields.io/badge/Podman-3.0+-blue.svg)](https://podman.io) [![Docker 20.10+](https://img.shields.io/badge/Docker-20.10+-blue.svg)](https://docker.com)

---

## Getting Started

If you just want to get it running:

```bash
bash scripts/install-runtime.sh
bash scripts/rebuild-from-scratch.sh
open http://localhost:80
```

That's it. The script figures out what OS you're on and installs what you need.

If you want to run everything without sudo (which is nicer), do this once:

```bash
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $(whoami)
podman system migrate
podman-compose up -d
```

For Flatpak users:

```bash
bash scripts/install-runtime.sh --flatpak
./.flatpak-podman-wrapper.sh run alpine echo "ready"
```

---

## What You Get

The whole monitoring stack:
- PostgreSQL 16 for data storage
- Zabbix Server for the actual monitoring
- Web UI (Nginx + PHP) so you can see what's happening
- Java Gateway for JMX stuff
- SNMP Traps receiver
- Grafana if you want nicer dashboards

Security stuff is on by default:
- Containers run as your user, not root
- Each container gets its own user namespace (no UID conflicts)
- Services are split into backend (internal only) and frontend (public)
- Everything gets resource limits
- Health checks run automatically

---

## Installation

The easy way - just run this and let it figure it out:

```bash
bash scripts/install-runtime.sh
```

If you prefer doing it manually:

**Fedora/CentOS/RHEL:**
```bash
sudo dnf install podman podman-compose
```

**Ubuntu/Debian:**
```bash
sudo apt-get install podman podman-compose
```

**macOS:**
```bash
brew install podman podman-compose
podman machine init
podman machine start
```

**Windows (WSL2):**
Just use Docker Desktop. Or if you're in WSL2 already, run the install script.

---

## Running It

Start everything:
```bash
podman-compose up -d
```

Check if it's actually running:
```bash
podman-compose ps
podman logs -f zabbix-server
```

Then go to http://localhost - the default credentials are admin/zabbix (you should change these).

Stop it when you're done:
```bash
podman-compose down
```

If you want to start completely fresh (warning: removes data):
```bash
podman-compose down -v
bash scripts/rebuild-from-scratch.sh
```

---

## Common Stuff You'll Need

```bash
# See what's running
podman-compose ps

# Follow logs for a service
podman-compose logs -f zabbix-server

# Jump into a container
podman exec <container> /bin/bash

# See how much resources things are using
podman stats

# Full rebuild from nothing
bash scripts/rebuild-from-scratch.sh

# Clean up unused stuff
podman system prune -a --volumes
```

---

## Security & Rootless Mode

By default all containers run as a regular user, not root. Here's why that matters: if someone breaks into a container, they get your user permissions, not root. That's way better.

**Setting up rootless mode (one time):**

```bash
# Configure user namespaces (needs sudo once)
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $(whoami)

# Switch podman to rootless (no sudo needed)
podman system migrate

# Check it worked
podman info | grep rootless
```

Then you can use podman-compose without sudo.

**Why this is good:**
- If a container gets compromised, the attacker only gets your user
- Containers are isolated from each other
- They clean up automatically when you log out
- No long-running root daemon

**If you skip this:** Just remember to put `sudo` before podman-compose commands. It works fine, just runs as root.

---

## Platform Support

Should work on:
- Fedora, Ubuntu, Debian, CentOS - obvious winners
- macOS with Homebrew
- WSL2 on Windows (Docker Desktop recommended)
- Flatpak (with a wrapper script if needed)

The install script tries to detect what you're on and installs accordingly.

---

## Configuring Stuff

Copy the example env file and edit it:

```bash
cp .env.example .env
```

Then change whatever you need - passwords, timezone, server name, etc.

Key settings:
```
DB_SERVER_PASSWORD=your_db_password
ZBX_SERVER_NAME=My Monitoring
TIMEZONE=UTC
```

---

## When Things Break

Podman not installed?
```bash
bash scripts/install-runtime.sh
```

Permission errors on volumes?
```bash
chmod 777 /path/to/volume
# or just use named volumes instead
podman volume create mydata
```

Container won't start?
```bash
podman logs <container>
podman inspect <container> | grep ExitCode
```

DNS issues inside containers?
```bash
podman run --dns 8.8.8.8 --dns 1.1.1.1 alpine ping 8.8.8.8
```

---

## Project Layout

```
zabbix/
├── README.md                    (this file)
├── docker-compose.yaml          (everything defined here)
├── LICENSE                      (MIT)
├── scripts/                     (helper scripts)
│   ├── install-runtime.sh       (auto setup)
│   ├── rebuild-from-scratch.sh  (full rebuild)
│   └── others...
├── agent/
├── server-pgsql/
├── web-nginx-pgsql/
├── java-gateway/
├── snmptraps/
├── grafana/
└── zbx_env/                     (your data lives here)
```

---

## Services

This defines two networks to keep things sane:

**Internal (backend):**
- postgres (database)
- zabbix-server
- java-gateway
- snmp-traps

**Public (frontend):**
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

