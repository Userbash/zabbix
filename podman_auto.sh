#!/bin/bash

# Создаем сеть, если её нет
podman network exists zbx_net_backend || podman network create zbx_net_backend

# Список сервисов и их пути к Dockerfile
declare -A services=(
  [zabbix-server-pgsql]="server-pgsql/alpine"
  [zabbix-web-nginx-pgsql]="web-nginx-pgsql/alpine"
  [zabbix-agent]="agent/alpine"
  [zabbix-agent2]="agent2/alpine"
  [zabbix-java-gateway]="java-gateway/alpine"
  [zabbix-snmptraps]="snmptraps/alpine"
  [grafana]="grafana"
)

# 1. Запуск базы данных (Postgres)
echo "Запуск postgres..."
podman run -d --name postgres \
  --network zbx_net_backend \
  --env-file .env_db_pgsql \
  -e POSTGRES_USER=$(cat .POSTGRES_USER) \
  -e POSTGRES_PASSWORD=$(cat .POSTGRES_PASSWORD) \
  -v ./zbx_env/var/lib/postgresql/data:/var/lib/postgresql/data:rw,z \
  postgres:16-alpine

# Ожидание готовности БД
echo "Ожидание готовности postgres..."
until podman exec postgres pg_isready -U $(cat .POSTGRES_USER) > /dev/null 2>&1; do
  sleep 1
done

# 2. Сборка и запуск остальных сервисов
for service in "${!services[@]}"; do
  echo "Сборка образа $service..."
  podman build -t "$service:alpine-local" "${services[$service]}"
  
  echo "Запуск контейнера $service..."
  
  # Определение env-файлов
  ENV_OPTS="--env-file .env_db_pgsql"
  case $service in
    zabbix-server-pgsql) ENV_OPTS="$ENV_OPTS --env-file .env_srv" ;;
    zabbix-web-nginx-pgsql) ENV_OPTS="$ENV_OPTS --env-file .env_web" ;;
    grafana) ENV_OPTS="$ENV_OPTS --env-file .env_grafana" ;;
  esac
  
  # Запуск
  podman run -d --name "$service" \
    --network zbx_net_backend \
    $ENV_OPTS \
    "$service:alpine-local"
done

# 3. Проверка состояния
podman ps

# 4. Сбор логов
mkdir -p logs
for service in "${!services[@]}" postgres; do
  podman logs "$service" > "logs/${service}.log" 2>&1
done
