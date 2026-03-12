# Zabbix Docker Setup

This repository contains a Docker/Podman Compose setup for Zabbix with PostgreSQL and Grafana.

## 🛡️ Security

This project is designed with security in mind. All passwords and sensitive data are stored in ignored files. See [SECURITY.md](SECURITY.md) for more details.

## 🚀 Setup Instructions

1.  **Initialize environment files:**
    Copy all `.example` files to their corresponding local files:
    ```bash
    cp .env_agent.example .env_agent
    cp .env_db_pgsql.example .env_db_pgsql
    cp .env_grafana.example .env_grafana
    cp .env_srv.example .env_srv
    cp .env_web.example .env_web
    cp .POSTGRES_USER.example .POSTGRES_USER
    cp .POSTGRES_PASSWORD.example .POSTGRES_PASSWORD
    ```

2.  **Configure secrets:**
    Edit the newly created files and replace placeholder values (e.g., `your_password`, `your_username`) with your actual configuration.

3.  **Run the stack:**
    ```bash
    docker compose up -d
    # OR if using Podman
    podman-compose up -d
    ```

