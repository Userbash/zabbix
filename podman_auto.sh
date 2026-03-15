#!/bin/bash

# Create network if it doesn't exist
podman network exists zbx_net_backend || podman network create zbx_net_backend

# Services and their Dockerfile paths
declare -A services=(
  [zabbix-server-pgsql]="server-pgsql/alpine"
  [zabbix-web-nginx-pgsql]="web-nginx-pgsql/alpine"
  [zabbix-agent]="agent/alpine"
  [zabbix-agent2]="agent2/alpine"
  [zabbix-java-gateway]="java-gateway/alpine"
  [zabbix-snmptraps]="snmptraps/alpine"
  [grafana]="grafana"
)

# 1. Starting database (Postgres)
echo "Starting postgres..."
podman run -d --name postgres \
  --network zbx_net_backend \
  --env-file .env_db_pgsql \
  -e POSTGRES_USER=$(cat .POSTGRES_USER) \
  -e POSTGRES_PASSWORD=$(cat .POSTGRES_PASSWORD) \
  -v ./zbx_env/var/lib/postgresql/data:/var/lib/postgresql/data:rw,z \
  postgres:16-alpine

# Waiting for database to be ready
echo "Waiting for postgres to be ready"
until podman exec postgres pg_isready -U $(cat .POSTGRES_USER) > /dev/null 2>&1; do
  sleep 1
done

# 2. Building and running other services
for service in "${!services[@]}"; do
  echo "Building image $service..."
  podman build -t "$service:alpine-local" "${services[$service]}"
  
  echo "Starting container $service..."
  
  # Determining env files
  ENV_OPTS="--env-file .env_db_pgsql"
  case $service in
    zabbix-server-pgsql) ENV_OPTS="$ENV_OPTS --env-file .env_srv" ;;
    zabbix-web-nginx-pgsql) ENV_OPTS="$ENV_OPTS --env-file .env_web" ;;
    grafana) ENV_OPTS="$ENV_OPTS --env-file .env_grafana" ;;
  esac
  
  # Running
  podman run -d --name "$service" \
    --network zbx_net_backend \
    $ENV_OPTS \
    "$service:alpine-local"
done

# 3. Checking status
podman ps

# 4. Collecting logs
mkdir -p logs
for service in "${!services[@]}" postgres; do
  podman logs "$service" > "logs/${service}.log" 2>&1
done
