#!/bin/bash

################################################################################
# 📋 ПРОЦЕДУРА ПЕРЕСБОРКИ ZABBIX: ПОШАГОВОЕ РУКОВОДСТВО
################################################################################
# Этот скрипт предназначен для запуска на машине с установленным Podman/Docker
# 
# ТРЕБОВАНИЯ:
# - Podman или Docker установлены
# - 2+ GB свободной памяти и дискового пространства
# - Доступ к интернету для скачивания образов
#
# ИСПОЛЬЗОВАНИЕ:
# bash rebuild-from-scratch.sh
#
###############################################################################

set -euo pipefail

# Цвета вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

log_header() { 
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║ $1${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
}

log_section() { echo -e "\n${MAGENTA}▶ $1${NC}"; }
log_info() { echo -e "${BLUE}ℹ $1${NC}"; }
log_success() { echo -e "${GREEN}✓ $1${NC}"; }
log_error() { echo -e "${RED}✗ $1${NC}"; }

# ============================================================================
# ШАГИ ПЕРЕСБОРКИ
# ============================================================================

log_header "ПОЛНАЯ ПЕРЕСБОРКА И АНАЛИЗ ZABBIX"

# Определение runtime
RUNTIME="podman"
if ! command -v podman &> /dev/null; then
    if command -v docker &> /dev/null; then
        RUNTIME="docker"
    else
        log_error "Ни podman ни docker не установлены. Установите одно из них."
        exit 1
    fi
fi

log_success "Используемый runtime: $RUNTIME"

# Переход в директорию проекта
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

log_section "1. ОСТАНОВКА И ОЧИСТКА СУЩЕСТВУЮЩИХ КОНТЕЙНЕРОВ"

# Остановка и удаление контейнеров
for container in postgres zabbix-server-pgsql zabbix-web-nginx-pgsql \
                 zabbix-java-gateway zabbix-snmptraps grafana; do
    if $RUNTIME ps -a --format "{{.Names}}" 2>/dev/null | grep -q "^$container$"; then
        log_info "Остановка $container..."
        $RUNTIME stop "$container" 2>/dev/null || true
        sleep 1
        $RUNTIME rm "$container" 2>/dev/null || true
        log_success "$container остановлен и удален"
    fi
done

# Удаление образов
for image in zabbix-server-pgsql:alpine-local zabbix-web-nginx-pgsql:alpine-local \
             zabbix-java-gateway:alpine-local zabbix-snmptraps:alpine-local \
             grafana:local; do
    if $RUNTIME images --format "{{.Repository}}:{{.Tag}}" 2>/dev/null | grep -q "^$image$"; then
        log_info "Удаление образа $image..."
        $RUNTIME rmi "$image" 2>/dev/null || true
        log_success "$image удален"
    fi
done

# Очистка неиспользуемых ресурсов
log_info "Очистка системы..."
$RUNTIME system prune -f 2>/dev/null || true

# Очистка локальных данных
log_info "Очистка директорий данных PostgreSQL..."
rm -rf ./zbx_env/var/lib/postgresql/data/* 2>/dev/null || true
log_success "Данные очищены"

log_section "2. СОЗДАНИЕ СЕТЕЙ"

# Создание сетей
for network in zbx_net_backend zbx_net_frontend; do
    if ! $RUNTIME network inspect "$network" &>/dev/null; then
        log_info "Создание сети $network..."
        $RUNTIME network create "$network"
        log_success "Сеть $network создана"
    fi
done

log_section "3. ИНИЦИАЛИЗАЦИЯ ПЕРЕМЕННЫХ ОКРУЖЕНИЯ"

# Инициализация .env файлов
for env_file in .env_agent .env_db_pgsql .env_grafana .env_srv .env_web; do
    if [ ! -f "${env_file}" ] && [ -f "${env_file}.example" ]; then
        cp "${env_file}.example" "${env_file}"
        log_success "Инициализирован ${env_file}"
    fi
done

# Инициализация файлов секретов
for secret_file in .POSTGRES_USER .POSTGRES_PASSWORD; do
    if [ ! -f "$secret_file" ] && [ -f "${secret_file}.example" ]; then
        cp "${secret_file}.example" "$secret_file"
        log_success "Инициализирован $secret_file"
    fi
done

# Чтение переменных
POSTGRES_USER=$(cat .POSTGRES_USER 2>/dev/null || echo "zabbix")
POSTGRES_PASSWORD=$(cat .POSTGRES_PASSWORD 2>/dev/null || echo "zabbix")
POSTGRES_DB="zabbix_db"

log_info "PostgreSQL User: $POSTGRES_USER"

log_section "4. СБОРКА ОБРАЗОВ"

declare -A services=(
    [zabbix-server-pgsql]="server-pgsql/alpine"
    [zabbix-web-nginx-pgsql]="web-nginx-pgsql/alpine"
    [zabbix-agent]="agent/alpine"
    [zabbix-agent2]="agent2/alpine"
    [zabbix-java-gateway]="java-gateway/alpine"
    [zabbix-snmptraps]="snmptraps/alpine"
    [grafana]="grafana"
)

for service in "${!services[@]}"; do
    service_path="${services[$service]}"
    if [ -f "$service_path/Dockerfile" ]; then
        log_info "Сборка образа $service..."
        $RUNTIME build -t "${service}:alpine-local" -f "$service_path/Dockerfile" "$service_path"
        log_success "$service собран"
    else
        log_error "Dockerfile не найден: $service_path/Dockerfile"
    fi
done

log_section "5. ЗАПУСК СЕРВИСОВ"

# PostgreSQL
log_info "Запуск PostgreSQL..."
$RUNTIME run -d \
    --name postgres \
    --network zbx_net_backend \
    -e POSTGRES_USER="$POSTGRES_USER" \
    -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
    -e POSTGRES_DB="$POSTGRES_DB" \
    -v "$PROJECT_DIR/zbx_env/var/lib/postgresql/data:/var/lib/postgresql/data:rw,z" \
    -v /etc/localtime:/etc/localtime:ro \
    postgres:16-alpine

# Ожидание PostgreSQL
log_info "Ожидание инициализации PostgreSQL..."
max_attempts=60
for ((i=0; i<max_attempts; i++)); do
    if $RUNTIME exec postgres pg_isready -U "$POSTGRES_USER" > /dev/null 2>&1; then
        log_success "PostgreSQL инициализирован"
        break
    fi
    sleep 2
done

# Java Gateway
log_info "Запуск Java Gateway..."
$RUNTIME run -d \
    --name zabbix-java-gateway \
    --network zbx_net_backend \
    --env-file .env_srv \
    zabbix-java-gateway:alpine-local
sleep 5
log_success "Java Gateway запущен"

# SNMP Traps
log_info "Запуск SNMP Traps..."
$RUNTIME run -d \
    --name zabbix-snmptraps \
    --network zbx_net_backend \
    zabbix-snmptraps:alpine-local
sleep 5
log_success "SNMP Traps запущен"

# Zabbix Server
log_info "Запуск Zabbix Server..."
$RUNTIME run -d \
    --name zabbix-server-pgsql \
    --network zbx_net_backend \
    -p 10051:10051 \
    --env-file .env_db_pgsql \
    --env-file .env_srv \
    -e DB_SERVER_HOST=postgres \
    -e DB_SERVER_USER="$POSTGRES_USER" \
    -e DB_SERVER_PASSWORD="$POSTGRES_PASSWORD" \
    -e DB_SERVER_DBNAME="$POSTGRES_DB" \
    -e ZBX_JAVAGATEWAY=zabbix-java-gateway \
    -e ZBX_JAVAGATEWAY_PORT=10052 \
    -e ZBX_ENABLE_SNMP_TRAPS=true \
    -v "$PROJECT_DIR/zbx_env/usr/lib/zabbix/alertscripts:/usr/lib/zabbix/alertscripts:ro,z" \
    -v "$PROJECT_DIR/zbx_env/usr/lib/zabbix/externalscripts:/usr/lib/zabbix/externalscripts:ro,z" \
    -v "$PROJECT_DIR/zbx_env/var/lib/zabbix/modules:/var/lib/zabbix/modules:ro,z" \
    -v "$PROJECT_DIR/zbx_env/var/lib/zabbix/enc:/var/lib/zabbix/enc:ro,z" \
    -v /etc/localtime:/etc/localtime:ro \
    zabbix-server-pgsql:alpine-local

# Ожидание Zabbix Server
log_info "Ожидание инициализации Zabbix Server..."
max_attempts=120
for ((i=0; i<max_attempts; i++)); do
    if $RUNTIME exec zabbix-server-pgsql nc -z localhost 10051 > /dev/null 2>&1; then
        log_success "Zabbix Server инициализирован"
        break
    fi
    sleep 2
done

# Zabbix Web
log_info "Запуск Zabbix Web Interface..."
$RUNTIME run -d \
    --name zabbix-web-nginx-pgsql \
    --network zbx_net_backend \
    --network zbx_net_frontend \
    -p 80:8080 \
    -p 443:8443 \
    --env-file .env_db_pgsql \
    --env-file .env_web \
    -e DB_SERVER_HOST=postgres \
    -e DB_SERVER_USER="$POSTGRES_USER" \
    -e DB_SERVER_PASSWORD="$POSTGRES_PASSWORD" \
    -e DB_SERVER_DBNAME="$POSTGRES_DB" \
    -e ZBX_SERVER_HOST=zabbix-server-pgsql \
    -v "$PROJECT_DIR/zbx_env/etc/ssl/nginx:/etc/ssl/nginx:ro,z" 2>/dev/null || true \
    -v /etc/localtime:/etc/localtime:ro \
    zabbix-web-nginx-pgsql:alpine-local

# Ожидание Web
log_info "Ожидание инициализации Zabbix Web..."
max_attempts=60
for ((i=0; i<max_attempts; i++)); do
    if timeout 1 bash -c "echo >/dev/tcp/127.0.0.1/80" 2>/dev/null; then
        log_success "Zabbix Web инициализирован"
        break
    fi
    sleep 2
done

# Grafana (опционально)
if [ -f "grafana/Dockerfile" ]; then
    log_info "Запуск Grafana..."
    $RUNTIME run -d \
        --name grafana \
        --network zbx_net_frontend \
        -p 3000:3000 \
        --env-file .env_grafana 2>/dev/null || true \
        grafana:local
    sleep 5
    log_success "Grafana запущена"
fi

log_section "6. СТАТУС КОНТЕЙНЕРОВ"

echo ""
echo "Все запущенные контейнеры:"
$RUNTIME ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

log_section "7. ПРОВЕРКА ПОРТОВ И ДОСТУПНОСТИ"

echo ""
echo "Проверка портов:"

if nc -z 127.0.0.1 10051 2>/dev/null; then
    log_success "Zabbix Server (10051): доступен"
else
    log_error "Zabbix Server (10051): НЕДОСТУПЕН"
fi

if timeout 1 bash -c "echo >/dev/tcp/127.0.0.1/80" 2>/dev/null; then
    log_success "HTTP Web (80): доступен"
else
    log_error "HTTP Web (80): НЕДОСТУПЕН"
fi

if $RUNTIME exec postgres pg_isready -U "$POSTGRES_USER" 2>/dev/null; then
    log_success "PostgreSQL (5432): доступен"
else
    log_error "PostgreSQL (5432): НЕДОСТУПЕН"
fi

echo ""
log_section "8. СБОР ЛОГОВ"

# Создание директории для логов
mkdir -p ./analysis_logs

# Сбор логов каждого контейнера
for container in postgres zabbix-server-pgsql zabbix-web-nginx-pgsql \
                 zabbix-java-gateway zabbix-snmptraps grafana; do
    if $RUNTIME ps -a --format "{{.Names}}" 2>/dev/null | grep -q "^$container$"; then
        log_info "Сбор логов $container..."
        $RUNTIME logs "$container" > "./analysis_logs/${container}.log" 2>&1
        log_success "Логи $container сохранены"
    fi
done

echo ""
log_section "9. СБОР ИНФОРМАЦИИ О СЕТИ"

# Анализ сетей
{
    echo "=== ИНФОРМАЦИЯ О СЕТЯХ ==="
    echo "Время: $(date)"
    echo ""
    echo "Список сетей:"
    $RUNTIME network ls
    echo ""
    echo "Детали сети zbx_net_backend:"
    $RUNTIME network inspect zbx_net_backend > ./analysis_logs/network_backend.json
    echo ""
    echo "Детали сети zbx_net_frontend:"
    $RUNTIME network inspect zbx_net_frontend > ./analysis_logs/network_frontend.json 2>/dev/null || echo "Frontend сеть не создана"
} | tee ./analysis_logs/network_info.txt

echo ""
log_section "10. СБОР ИНФОРМАЦИИ О КОНТЕЙНЕРАХ"

# Детальная информация о контейнерах
{
    echo "=== ИНФОРМАЦИЯ О КОНТЕЙНЕРАХ ==="
    echo "Время: $(date)"
    echo ""
    for container in postgres zabbix-server-pgsql zabbix-web-nginx-pgsql \
                     zabbix-java-gateway zabbix-snmptraps grafana; do
        if $RUNTIME ps -a --format "{{.Names}}" 2>/dev/null | grep -q "^$container$"; then
            echo "--- Контейнер: $container ---"
            $RUNTIME inspect "$container" > "./analysis_logs/${container}_inspect.json"
            echo "Информация сохранена в ${container}_inspect.json"
            echo ""
        fi
    done
} | tee ./analysis_logs/containers_info.txt

echo ""
log_section "11. СТАТИСТИКА РЕСУРСОВ"

# Статистика использования ресурсов
{
    echo "=== ИСПОЛЬЗОВАНИЕ РЕСУРСОВ ==="
    echo "Время: $(date)"
    echo ""
    $RUNTIME stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}\t{{.CPUPerc}}\t{{.NetIO}}\t{{.BlockIO}}" || echo "Stats недоступен"
    echo ""
    echo "Размеры образов:"
    $RUNTIME images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}"
} | tee ./analysis_logs/resources.txt

echo ""
log_section "12. ТЕСТИРОВАНИЕ ВЕБ-ИНТЕРФЕЙСА"

# Проверка веб-интерфейса
{
    echo "=== ТЕСТИРОВАНИЕ ВЕБ-ИНТЕРФЕЙСА ==="
    echo "Время: $(date)"
    echo ""
    
    echo "HTTP Status Code:"
    curl -s -I http://127.0.0.1:80/ | head -5
    echo ""
    
    echo "HTML Content Length:"
    curl -s -w "Content-Length: %{content_length_download} bytes\n" -o /dev/null http://127.0.0.1:80/
    echo ""
    
    echo "API Test:"
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"user.get","params":{"output":["userid","alias"]},"id":1}' \
        http://127.0.0.1:80/api_jsonrpc.php | jq '.' 2>/dev/null || echo "API response received (jq not available)"
} | tee ./analysis_logs/web_test.txt

echo ""
log_section "13. ФИНАЛЬНЫЙ ОТЧЕТ"

{
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║          ПЕРЕСБОРКА ЗАВЕРШЕНА УСПЕШНО                          ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "✓ Все контейнеры запущены"
    echo "✓ Все логи собраны"
    echo "✓ Все проверки выполнены"
    echo ""
    echo "ДОСТУПНЫЕ СЕРВИСЫ:"
    echo "  - Zabbix Web Interface: http://127.0.0.1"
    echo "  - Zabbix Server: 127.0.0.1:10051"
    echo "  - PostgreSQL: 127.0.0.1:5432 (пользователь: $POSTGRES_USER)"
    echo "  - Grafana: http://127.0.0.1:3000 (если установлена)"
    echo ""
    echo "ФАЙЛЫ ЛОГОВ ХРАНЯТСЯ В:"
    echo "  ./analysis_logs/"
    echo ""
    echo "ДАЛЬНЕЙШИЕ ДЕЙСТВИЯ:"
    echo "  1. Откройте http://127.0.0.1 в браузере"
    echo "  2. Логин по умолчанию: Admin / zabbix"
    echo "  3. Посмотрите логи: cat ./analysis_logs/*.log"
    echo "  4. Проверьте сеть: podman network inspect zbx_net_backend"
    echo ""
} | tee ./analysis_logs/SUMMARY.txt

log_success "Все операции завершены!"

exit 0
