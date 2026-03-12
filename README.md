# Zabbix Docker Setup

This repository contains a Docker Compose setup for Zabbix with PostgreSQL and Grafana.

## Security Notice

To prevent sensitive information (passwords, tokens, etc.) from being committed to the repository, all environment files (`.env*`) and secret files (`.POSTGRES*`) are ignored by Git.

## Setup Instructions

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

3.  **Run with Docker Compose:**
    ```bash
    docker-compose up -d
    ```

## GitHub Actions

The provided GitHub Actions workflow (`.github/workflows/docker-publish.yml`) is configured to build images. If you decide to use this for automated deployments, make sure to:
1.  Define sensitive values as **GitHub Secrets**.
2.  Update the workflow to inject these secrets into the build process if necessary.
