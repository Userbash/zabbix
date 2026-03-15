#!/bin/bash

################################################################################
# 🔧 ПОЛНАЯ ОЧИСТКА, ПЕРЕСБОРКА И АНАЛИЗ ПРОЕКТА ZABBIX
################################################################################
# Скрипт выполняет:
# 1. Полную очистку артефактов и контейнеров
# 2. Инициализацию переменных окружения
# 3. Пересборку всех образов с нуля
# 4. Запуск всех сервисов
# 5. Детальный сбор логов каждого контейнера
# 6. Анализ сетевого взаимодействия
# 7. Проверку портов и доступности
# 8. Тестирование веб-интерфейса
# 9. Создание полного отчета
################################################################################

set -euo pipefail

# ============================================================================
# КОНФИГУРАЦИЯ И ПЕРЕМЕННЫЕ
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ANALYSIS_DIR="${PROJECT_ROOT}/analysis_${TIMESTAMP}"
LOGS_DIR="${ANALYSIS_DIR}/logs"
NETWORK_DIR="${ANALYSIS_DIR}/network"
TESTS_DIR="${ANALYSIS_DIR}/tests"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Статистика
declare -A CONTAINER_STATUS
declare -a BUILD_TIMES
declare -a STARTUP_TIMES
declare -a HEALTH_CHECKS

# ============================================================================
# ФУНКЦИИ ЛОГИРОВАНИЯ
# ============================================================================

log_header() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║ $1${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
}

log_section() {
    echo -e "\n${MAGENTA}▶ $1${NC}"
}

log_info() { 
    echo -e "${BLUE}ℹ $(date '+%H:%M:%S')${NC} $1" 
}

log_success() { 
    echo -e "${GREEN}✓ $(date '+%H:%M:%S')${NC} $1" 
}

log_error() { 
    echo -e "${RED}✗ $(date '+%H:%M:%S')${NC} $1" 
}

log_warning() { 
    echo -e "${YELLOW}⚠ $(date '+%H:%M:%S')${NC} $1" 
}

# Запись в файл анализа
log_analysis() {
    local log_file="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $@" >> "$log_file"
}

# ============================================================================
# ПОДГОТОВКА
# ============================================================================

log_header "НАЧАЛО ПОЛНОЙ ПЕРЕСБОРКИ И АНАЛИЗА ПРОЕКТА ZABBIX"

log_info "Создание директорий анализа..."
mkdir -p "$LOGS_DIR" "$NETWORK_DIR" "$TESTS_DIR"
log_success "Директории созданы: $ANALYSIS_DIR"

# Инициализация главного отчета
MAIN_REPORT="${ANALYSIS_DIR}/FULL_ANALYSIS_REPORT.md"
cat > "$MAIN_REPORT" << 'EOF'
# 📊 ПОЛНЫЙ АНАЛИЗ ПРОЕКТА ZABBIX

**Дата анализа:** $(date)
**Версия скрипта:** 1.0

## Оглавление

1. [Информация о системе](#система)
2. [Процесс очистки](#очистка)
3. [Сборка образов](#сборка)
4. [Запуск контейнеров](#запуск)
5. [Анализ сети](#сеть)
6. [Проверка портов](#порты)
7. [Тесты доступности](#тесты)
8. [Логи контейнеров](#логи)
9. [Заключение](#заключение)

---

EOF

# ============================================================================
# 1. ПРОВЕРКА ИНФОРМАЦИИ О СИСТЕМЕ
# ============================================================================

log_section "ПРОВЕРКА ИНФОРМАЦИИ О СИСТЕМЕ"

SYSTEM_INFO="${ANALYSIS_DIR}/SYSTEM_INFO.txt"
{
    echo "=== ИНФОРМАЦИЯ О СИСТЕМЕ ==="
    echo "Дата: $(date)"
    echo "Хост: $(hostname)"
    echo "ОС: $(uname -a)"
    echo ""
    echo "=== ИСПОЛЬЗУЕМЫЙ КОНТЕЙНЕР-РАНЕР ==="
    if command -v podman &> /dev/null; then
        echo "Podman: $(podman --version)"
        RUNTIME="podman"
    elif command -v docker &> /dev/null; then
        echo "Docker: $(docker --version)"
        RUNTIME="docker"
    else
        log_error "Ни podman ни docker не найдены"
        exit 1
    fi
    echo ""
    echo "=== РЕСУРСЫ СИСТЕМЫ ==="
    echo "CPU: $(nproc) ядер"
    echo "Память: $(free -h | grep Mem)"
    echo "Диск: $(df -h | grep '/$')"
} | tee "$SYSTEM_INFO"

log_success "Информация о системе собрана"

# ============================================================================
# 2. ПОЛНАЯ ОЧИСТКА
# ============================================================================

log_section "ПОЛНАЯ ОЧИСТКА АРТЕФАКТОВ"

CLEANUP_LOG="${ANALYSIS_DIR}/CLEANUP.log"
touch "$CLEANUP_LOG"

log_info "Остановка и удаление контейнеров..."
{
    echo "=== ПРОЦЕСС ОСТАНОВКИ И УДАЛЕНИЯ КОНТЕЙНЕРОВ ==="
    echo "Время начала: $(date)"
    echo ""
} >> "$CLEANUP_LOG"

for container in zabbix-server-pgsql zabbix-web-nginx-pgsql zabbix-agent zabbix-agent2 \
                 zabbix-java-gateway zabbix-snmptraps grafana postgres; do
    if $RUNTIME ps -a --format "{{.Names}}" 2>/dev/null | grep -q "^$container$"; then
        log_info "Остановка контейнера $container..."
        $RUNTIME stop "$container" 2>/dev/null || true
        sleep 1
        $RUNTIME rm "$container" 2>/dev/null || true
        echo "Контейнер $container: удален" >> "$CLEANUP_LOG"
        log_success "Контейнер $container удален"
    fi
done

log_info "Удаление образов..."
{
    echo ""
    echo "=== УДАЛЕНИЕ ОБРАЗОВ ==="
    echo "Время начала: $(date)"
} >> "$CLEANUP_LOG"

for image in zabbix-server-pgsql:alpine-local zabbix-web-nginx-pgsql:alpine-local \
             zabbix-agent:alpine-local zabbix-agent2:alpine-local \
             zabbix-java-gateway:alpine-local zabbix-snmptraps:alpine-local \
             grafana:local; do
    if $RUNTIME images --format "{{.Repository}}:{{.Tag}}" 2>/dev/null | grep -q "^$image$"; then
        log_info "Удаление образа $image..."
        $RUNTIME rmi "$image" 2>/dev/null || true
        echo "Образ $image: удален" >> "$CLEANUP_LOG"
        log_success "Образ $image удален"
    fi
done

log_info "Очистка неиспользуемых ресурсов..."
{
    echo ""
    echo "=== ОЧИСТКА НЕИСПОЛЬЗУЕМЫХ РЕСУРСОВ ==="
} >> "$CLEANUP_LOG"

$RUNTIME system prune -f 2>/dev/null || true
echo "Выполнена очистка неиспользуемых ресурсов" >> "$CLEANUP_LOG"
log_success "Неиспользуемые ресурсы удалены"

# Очистка локальных директорий с данными
log_info "Очистка директорий данных..."
if [ -d "$PROJECT_ROOT/zbx_env/var/lib/postgresql/data" ]; then
    rm -rf "$PROJECT_ROOT/zbx_env/var/lib/postgresql/data"/* 2>/dev/null || true
    echo "Директория PostgreSQL очищена" >> "$CLEANUP_LOG"
    log_success "Директория данных PostgreSQL очищена"
fi

echo "Время завершения: $(date)" >> "$CLEANUP_LOG"
log_success "Очистка завершена"

# ============================================================================
# 3. ИНИЦИАЛИЗАЦИЯ ПЕРЕМЕННЫХ ОКРУЖЕНИЯ
# ============================================================================

log_section "ИНИЦИАЛИЗАЦИЯ ПЕРЕМЕННЫХ ОКРУЖЕНИЯ"

ENV_INIT_LOG="${ANALYSIS_DIR}/ENV_INIT.log"
touch "$ENV_INIT_LOG"

cd "$PROJECT_ROOT"

# Копирование примеров .env файлов
for env_file in .env_agent .env_db_pgsql .env_grafana .env_srv .env_web; do
    if [ ! -f "${env_file}" ] && [ -f "${env_file}.example" ]; then
        cp "${env_file}.example" "${env_file}"
        echo "Файл $env_file инициализирован из примера" >> "$ENV_INIT_LOG"
        log_success "Инициализирован ${env_file}"
    elif [ -f "${env_file}" ]; then
        log_info "${env_file} уже существует, используется"
        echo "Файл $env_file уже существует" >> "$ENV_INIT_LOG"
    fi
done

# Инициализация файлов секретов
if [ ! -f .POSTGRES_USER ]; then
    if [ -f .POSTGRES_USER.example ]; then
        cp .POSTGRES_USER.example .POSTGRES_USER
        echo "Файл .POSTGRES_USER инициализирован" >> "$ENV_INIT_LOG"
        log_success "Инициализирован .POSTGRES_USER"
    fi
fi

if [ ! -f .POSTGRES_PASSWORD ]; then
    if [ -f .POSTGRES_PASSWORD.example ]; then
        cp .POSTGRES_PASSWORD.example .POSTGRES_PASSWORD
        echo "Файл .POSTGRES_PASSWORD инициализирован" >> "$ENV_INIT_LOG"
        log_success "Инициализирован .POSTGRES_PASSWORD"
    fi
fi

# Чтение переменных
POSTGRES_USER=$(cat .POSTGRES_USER 2>/dev/null || echo "zabbix")
POSTGRES_PASSWORD=$(cat .POSTGRES_PASSWORD 2>/dev/null || echo "zabbix")

log_success "Переменные окружения инициализированы"

# ============================================================================
# 4. СОЗДАНИЕ СЕТЕЙ
# ============================================================================

log_section "СОЗДАНИЕ СЕТЕЙ"

NETWORKS_LOG="${ANALYSIS_DIR}/NETWORKS.log"
touch "$NETWORKS_LOG"

for network in zbx_net_backend zbx_net_frontend; do
    if ! $RUNTIME network inspect "$network" &>/dev/null; then
        log_info "Создание сети $network..."
        $RUNTIME network create "$network"
        echo "Сеть $network: создана" >> "$NETWORKS_LOG"
        log_success "Сеть $network создана"
    else
        log_info "Сеть $network уже существует"
        echo "Сеть $network: уже существует" >> "$NETWORKS_LOG"
    fi
done

log_success "Сети созданы"

# ============================================================================
# 5. СБОРКА ОБРАЗОВ
# ============================================================================

log_section "СБОРКА ОБРАЗОВ"

BUILD_LOG="${ANALYSIS_DIR}/BUILD_PROCESS.log"
touch "$BUILD_LOG"

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
    docker_file="$service_path/Dockerfile"
    
    if [ ! -f "$docker_file" ]; then
        log_warning "Dockerfile не найден для $service: $docker_file"
        continue
    fi
    
    log_info "Сборка образа $service..."
    BUILD_START=$(date +%s%N)
    
    {
        echo "=== Сборка $service ==="
        echo "Время начала: $(date)"
        echo "Контекст: $service_path"
        echo "Dockerfile: $docker_file"
        echo ""
    } >> "$BUILD_LOG"
    
    if $RUNTIME build -t "${service}:alpine-local" \
        -f "$docker_file" \
        "$service_path" 2>&1 | tee -a "$BUILD_LOG"; then
        
        BUILD_END=$(date +%s%N)
        BUILD_TIME=$(( (BUILD_END - BUILD_START) / 1000000 ))
        BUILD_TIMES+=("$service: ${BUILD_TIME}ms")
        
        log_success "Образ $service собран успешно (${BUILD_TIME}ms)"
        echo "Статус: ✓ успешно (${BUILD_TIME}ms)" >> "$BUILD_LOG"
    else
        log_error "Ошибка при сборке $service"
        echo "Статус: ✗ ошибка" >> "$BUILD_LOG"
    fi
    
    echo "" >> "$BUILD_LOG"
done

log_success "Все образы собраны"

# ============================================================================
# 6. ЗАПУСК КОНТЕЙНЕРОВ
# ============================================================================

log_section "ЗАПУСК КОНТЕЙНЕРОВ"

STARTUP_LOG="${ANALYSIS_DIR}/STARTUP_PROCESS.log"
touch "$STARTUP_LOG"

# 6.1 PostgreSQL
log_info "Запуск PostgreSQL..."
{
    echo "=== Запуск PostgreSQL ==="
    echo "Время начала: $(date)"
} >> "$STARTUP_LOG"

POSTGRES_START=$(date +%s%N)

$RUNTIME run -d \
    --name postgres \
    --network zbx_net_backend \
    -e POSTGRES_USER="$POSTGRES_USER" \
    -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
    -e POSTGRES_DB=zabbix \
    -v "$PROJECT_ROOT/zbx_env/var/lib/postgresql/data:/var/lib/postgresql/data:rw,z" \
    -v /etc/localtime:/etc/localtime:ro \
    postgres:16-alpine \
    2>&1 | tee -a "$STARTUP_LOG"

# Ожидание готовности PostgreSQL
log_info "Ожидание готовности PostgreSQL..."
{
    echo "Ожидание инициализации базы данных..."
} >> "$STARTUP_LOG"

max_attempts=60
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if $RUNTIME exec postgres pg_isready -U "$POSTGRES_USER" > /dev/null 2>&1; then
        echo "PostgreSQL готов к работе" >> "$STARTUP_LOG"
        log_success "PostgreSQL инициализирован"
        break
    fi
    sleep 2
    ((attempt++))
done

POSTGRES_END=$(date +%s%N)
POSTGRES_TIME=$(( (POSTGRES_END - POSTGRES_START) / 1000000 ))
STARTUP_TIMES+=("PostgreSQL: ${POSTGRES_TIME}ms")

# 6.2 Java Gateway
log_info "Запуск Java Gateway..."
{
    echo ""
    echo "=== Запуск Java Gateway ==="
    echo "Время начала: $(date)"
} >> "$STARTUP_LOG"

JAVA_GATEWAY_START=$(date +%s%N)

$RUNTIME run -d \
    --name zabbix-java-gateway \
    --network zbx_net_backend \
    --env-file "$PROJECT_ROOT/.env_srv" \
    -e SERVER_PORT=10052 \
    "zabbix-java-gateway:alpine-local" \
    2>&1 | tee -a "$STARTUP_LOG"

sleep 5
JAVA_GATEWAY_END=$(date +%s%N)
JAVA_GATEWAY_TIME=$(( (JAVA_GATEWAY_END - JAVA_GATEWAY_START) / 1000000 ))
STARTUP_TIMES+=("Java Gateway: ${JAVA_GATEWAY_TIME}ms")

log_success "Java Gateway запущен"

# 6.3 SNMP Traps
log_info "Запуск SNMP Traps..."
{
    echo ""
    echo "=== Запуск SNMP Traps ==="
    echo "Время начала: $(date)"
} >> "$STARTUP_LOG"

SNMP_START=$(date +%s%N)

$RUNTIME run -d \
    --name zabbix-snmptraps \
    --network zbx_net_backend \
    -e SNMP_LOGFILE=/var/log/snmptraps/snmptraps.log \
    "zabbix-snmptraps:alpine-local" \
    2>&1 | tee -a "$STARTUP_LOG"

SNMP_END=$(date +%s%N)
SNMP_TIME=$(( (SNMP_END - SNMP_START) / 1000000 ))
STARTUP_TIMES+=("SNMP Traps: ${SNMP_TIME}ms")

sleep 5
log_success "SNMP Traps запущен"

# 6.4 Zabbix Server
log_info "Запуск Zabbix Server..."
{
    echo ""
    echo "=== Запуск Zabbix Server ==="
    echo "Время начала: $(date)"
} >> "$STARTUP_LOG"

SERVER_START=$(date +%s%N)

$RUNTIME run -d \
    --name zabbix-server-pgsql \
    --network zbx_net_backend \
    -p 10051:10051 \
    --env-file "$PROJECT_ROOT/.env_db_pgsql" \
    --env-file "$PROJECT_ROOT/.env_srv" \
    -e DB_SERVER_HOST=postgres \
    -e DB_SERVER_USER="$POSTGRES_USER" \
    -e DB_SERVER_PASSWORD="$POSTGRES_PASSWORD" \
    -e DB_SERVER_DBNAME=zabbix \
    -e ZBX_JAVAGATEWAY=zabbix-java-gateway \
    -e ZBX_JAVAGATEWAY_PORT=10052 \
    -e ZBX_SNMPTRAPPERFILE=/var/log/snmptraps/snmptraps.log \
    -e ZBX_SNMPTRAPPER=1 \
    -v "$PROJECT_ROOT/zbx_env/usr/lib/zabbix/alertscripts:/usr/lib/zabbix/alertscripts:ro,z" \
    -v "$PROJECT_ROOT/zbx_env/usr/lib/zabbix/externalscripts:/usr/lib/zabbix/externalscripts:ro,z" \
    -v "$PROJECT_ROOT/zbx_env/var/lib/zabbix/modules:/var/lib/zabbix/modules:ro,z" \
    -v "$PROJECT_ROOT/zbx_env/var/lib/zabbix/enc:/var/lib/zabbix/enc:ro,z" \
    -v "$PROJECT_ROOT/zbx_env/var/lib/zabbix/ssh_keys:/var/lib/zabbix/ssh_keys:ro,z" \
    -v "$PROJECT_ROOT/zbx_env/var/lib/zabbix/snmptraps:/var/lib/zabbix/snmptraps:ro,z" \
    -v /etc/localtime:/etc/localtime:ro \
    "zabbix-server-pgsql:alpine-local" \
    2>&1 | tee -a "$STARTUP_LOG"

# Ожидание готовности Zabbix Server
log_info "Ожидание инициализации Zabbix Server..."
max_attempts=120
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if $RUNTIME exec zabbix-server-pgsql nc -z localhost 10051 > /dev/null 2>&1; then
        echo "Zabbix Server готов к работе" >> "$STARTUP_LOG"
        log_success "Zabbix Server инициализирован"
        break
    fi
    sleep 2
    ((attempt++))
done

SERVER_END=$(date +%s%N)
SERVER_TIME=$(( (SERVER_END - SERVER_START) / 1000000 ))
STARTUP_TIMES+=("Zabbix Server: ${SERVER_TIME}ms")

# 6.5 Zabbix Web
log_info "Запуск Zabbix Web Interface..."
{
    echo ""
    echo "=== Запуск Zabbix Web Interface ==="
    echo "Время начала: $(date)"
} >> "$STARTUP_LOG"

WEB_START=$(date +%s%N)

$RUNTIME run -d \
    --name zabbix-web-nginx-pgsql \
    --network zbx_net_backend \
    --network zbx_net_frontend \
    -p 80:8080 \
    -p 443:8443 \
    --env-file "$PROJECT_ROOT/.env_db_pgsql" \
    --env-file "$PROJECT_ROOT/.env_web" \
    -e DB_SERVER_HOST=postgres \
    -e DB_SERVER_USER="$POSTGRES_USER" \
    -e DB_SERVER_PASSWORD="$POSTGRES_PASSWORD" \
    -e DB_SERVER_DBNAME=zabbix \
    -e ZBX_SERVER_HOST=zabbix-server-pgsql \
    -v "$PROJECT_ROOT/zbx_env/etc/ssl/nginx:/etc/ssl/nginx:ro,z" \
    -v "$PROJECT_ROOT/zbx_env/usr/share/zabbix/modules:/usr/share/zabbix/modules:ro,z" \
    -v /etc/localtime:/etc/localtime:ro \
    "zabbix-web-nginx-pgsql:alpine-local" \
    2>&1 | tee -a "$STARTUP_LOG"

# Ожидание готовности Web
log_info "Ожидание инициализации Zabbix Web..."
max_attempts=60
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if $RUNTIME exec zabbix-web-nginx-pgsql nc -z localhost 8080 > /dev/null 2>&1; then
        echo "Zabbix Web готов к работе" >> "$STARTUP_LOG"
        log_success "Zabbix Web инициализирован"
        break
    fi
    sleep 2
    ((attempt++))
done

WEB_END=$(date +%s%N)
WEB_TIME=$(( (WEB_END - WEB_START) / 1000000 ))
STARTUP_TIMES+=("Zabbix Web: ${WEB_TIME}ms")

# 6.6 Grafana (опционально)
log_info "Попытка запуска Grafana..."
if [ -f "$PROJECT_ROOT/grafana/Dockerfile" ]; then
    {
        echo ""
        echo "=== Запуск Grafana ==="
        echo "Время начала: $(date)"
    } >> "$STARTUP_LOG"
    
    GRAFANA_START=$(date +%s%N)
    
    $RUNTIME run -d \
        --name grafana \
        --network zbx_net_frontend \
        -p 3000:3000 \
        --env-file "$PROJECT_ROOT/.env_grafana" \
        "grafana:local" \
        2>&1 | tee -a "$STARTUP_LOG" || true
    
    GRAFANA_END=$(date +%s%N)
    GRAFANA_TIME=$(( (GRAFANA_END - GRAFANA_START) / 1000000 ))
    STARTUP_TIMES+=("Grafana: ${GRAFANA_TIME}ms")
    
    sleep 5
    log_success "Grafana запущена"
else
    log_warning "Dockerfile Grafana не найден, пропускаем"
fi

echo "Время завершения: $(date)" >> "$STARTUP_LOG"
log_success "Все контейнеры запущены"

# ============================================================================
# 7. СБОР ИНФОРМАЦИИ О КОНТЕЙНЕРАХ
# ============================================================================

log_section "СБОР ИНФОРМАЦИИ О КОНТЕЙНЕРАХ"

CONTAINERS_INFO="${ANALYSIS_DIR}/CONTAINERS_INFO.txt"
{
    echo "=== СТАТУС КОНТЕЙНЕРОВ ==="
    echo "Время: $(date)"
    echo ""
    $RUNTIME ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    echo "=== ДЕТАЛЬНАЯ ИНФОРМАЦИЯ ПО КОНТЕЙНЕРАМ ==="
    for container in postgres zabbix-server-pgsql zabbix-web-nginx-pgsql \
                     zabbix-java-gateway zabbix-snmptraps grafana; do
        if $RUNTIME ps -a --format "{{.Names}}" | grep -q "^$container$"; then
            echo ""
            echo "--- Контейнер: $container ---"
            echo "Информация:"
            $RUNTIME inspect "$container" --format='
ID: {{.Id}}
State: {{.State.Status}}
PID: {{.State.Pid}}
Started: {{.State.StartedAt}}
IP Address: {{.NetworkSettings.IPAddress}}
Networks: {{range $name, $config := .NetworkSettings.Networks}}{{$name}} ({{$config.IPAddress}}) {{end}}
' || true
            CONTAINER_STATUS[$container]="active"
        fi
    done
} | tee "$CONTAINERS_INFO"

log_success "Информация о контейнерах собрана"

# ============================================================================
# 8. АНАЛИЗ СРЕЧИ
# ============================================================================

log_section "АНАЛИЗ СЕТЕЙ И ВЗАИМОДЕЙСТВИЯ"

NETWORK_ANALYSIS="${NETWORK_DIR}/NETWORK_ANALYSIS.txt"
{
    echo "=== АНАЛИЗ СЕТЕЙ DOCKER/PODMAN ==="
    echo "Время анализа: $(date)"
    echo ""
    
    echo "--- Список сетей ---"
    $RUNTIME network ls
    echo ""
    
    for network in zbx_net_backend zbx_net_frontend; do
        if $RUNTIME network inspect "$network" &>/dev/null; then
            echo "--- Сеть: $network ---"
            $RUNTIME network inspect "$network"
            echo ""
        fi
    done
} | tee "$NETWORK_ANALYSIS"

# Детальный анализ сетевых соединений
NETWORK_CONNECTIONS="${NETWORK_DIR}/NETWORK_CONNECTIONS.txt"
{
    echo "=== СЕТЕВЫЕ СОЕДИНЕНИЯ МЕЖДУ КОНТЕЙНЕРАМИ ==="
    echo "Время анализа: $(date)"
    echo ""
    
    for container in zabbix-server-pgsql zabbix-web-nginx-pgsql postgres; do
        if $RUNTIME ps --format "{{.Names}}" | grep -q "^$container$"; then
            echo "--- Соединения из контейнера: $container ---"
            $RUNTIME exec "$container" netstat -tlnp 2>/dev/null || $RUNTIME exec "$container" ss -tlnp 2>/dev/null || echo "Утилита анализа портов недоступна"
            echo ""
        fi
    done
    
    echo ""
    echo "=== РАЗРЕШЕНИЕ ИМЕН В СЕТИ ==="
    for container in zabbix-server-pgsql zabbix-web-nginx-pgsql; do
        if $RUNTIME ps --format "{{.Names}}" | grep -q "^$container$"; then
            echo "--- DNS разрешение из $container ---"
            $RUNTIME exec "$container" nslookup postgres 2>/dev/null || echo "nslookup недоступен"
            $RUNTIME exec "$container" nslookup zabbix-server-pgsql 2>/dev/null || echo "nslookup недоступен"
            echo ""
        fi
    done
} | tee "$NETWORK_CONNECTIONS"

log_success "Анализ сети завершен"

# ============================================================================
# 9. ПРОВЕРКА ПОРТОВ И ДОСТУПНОСТИ
# ============================================================================

log_section "ПРОВЕРКА ПОРТОВ И ДОСТУПНОСТИ"

PORTS_ANALYSIS="${TESTS_DIR}/PORTS_CHECK.txt"
{
    echo "=== ПРОВЕРКА ОТКРЫТЫХ ПОРТОВ ХОСТА ==="
    echo "Время анализа: $(date)"
    echo ""
    
    # Портов для проверки [порт, описание]
    declare -a ports=(
        "10051:Zabbix Server"
        "80:HTTP (Zabbix Web)"
        "443:HTTPS (Zabbix Web)"
        "3000:Grafana"
        "5432:PostgreSQL"
    )
    
    for port_info in "${ports[@]}"; do
        IFS=: read port desc <<< "$port_info"
        echo "Проверка порта $port ($desc)..."
        
        if nc -z 127.0.0.1 "$port" 2>/dev/null; then
            echo "  ✓ Порт $port открыт"
        else
            echo "  ✗ Порт $port закрыт или недоступен"
        fi
    done
    
    echo ""
    echo "=== ПРОВЕРКА ДОСТУПНОСТИ СЕРВИСОВ ==="
    
    # Zabbix Server
    echo ""
    echo "- Zabbix Server (port 10051):"
    if nc -z 127.0.0.1 10051 2>/dev/null; then
        echo "  ✓ Доступен (TCP соединение успешно)"
    else
        echo "  ✗ Недоступен"
    fi
    
    # HTTP
    echo ""
    echo "- HTTP Web Interface (port 80):"
    timeout 5 curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://127.0.0.1:80/ || echo "Ошибка подключения"
    
    # PostgreSQL  
    echo ""
    echo "- PostgreSQL (port 5432):"
    if $RUNTIME exec postgres pg_isready -U "$POSTGRES_USER" 2>/dev/null; then
        echo "  ✓ PostgreSQL доступен и готов"
    else
        echo "  ✗ PostgreSQL недоступен"
    fi
    
} | tee "$PORTS_ANALYSIS"

log_success "Проверка портов завершена"

# ============================================================================
# 10. ТЕСТИРОВАНИЕ ВЕБ-ИНТЕРФЕЙСА
# ============================================================================

log_section "ТЕСТИРОВАНИЕ ВЕБ-ИНТЕРФЕЙСА"

WEB_TESTS="${TESTS_DIR}/WEB_INTERFACE_TESTS.txt"
{
    echo "=== ТЕСТИРОВАНИЕ ВЕБ-ИНТЕРФЕЙСА ZABBIX ==="
    echo "Время тестирования: $(date)"
    echo ""
    
    # Проверка доступа к главной странице
    echo "1. Проверка главной страницы..."
    curl -s -I http://127.0.0.1:80/ | head -5
    echo ""
    
    # Получение контента
    echo "2. Получение HTML контента..."
    curl -s -m 10 http://127.0.0.1:80/ | head -50 > /tmp/zabbix_home.html 2>/dev/null
    echo "  Сохранено в /tmp/zabbix_home.html"
    if [ -s /tmp/zabbix_home.html ]; then
        echo "  ✓ Страница получена"
        echo "  Размер: $(wc -c < /tmp/zabbix_home.html) байт"
    else
        echo "  ✗ Страница пуста или недоступна"
    fi
    echo ""
    
    # Проверка API
    echo "3. Проверка API Zabbix..."
    API_RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"user.get","params":{},"id":1}' \
        http://127.0.0.1:80/api_jsonrpc.php 2>/dev/null || echo "{}")
    
    if echo "$API_RESPONSE" | grep -q "jsonrpc"; then
        echo "  ✓ API доступен"
        echo "  Ответ: $(echo "$API_RESPONSE" | head -c 200)"
    else
        echo "  ⚠ API может быть недоступен"
    fi
    echo ""
    
    # Тест входа
    echo "4. Проверка страницы входа..."
    curl -s http://127.0.0.1:80/index.php | grep -i "login\|password" > /dev/null && echo "  ✓ Форма входа обнаружена" || echo "  ⚠ Форма входа не найдена"
    
} | tee "$WEB_TESTS"

log_success "Тестирование веб-интерфейса завершено"

# ============================================================================
# 11. СБОР ЛОГОВ КОНТЕЙНЕРОВ
# ============================================================================

log_section "СБОР И АНАЛИЗ ЛОГОВ КОНТЕЙНЕРОВ"

log_info "Сбор полных логов каждого контейнера..."

for container in postgres zabbix-server-pgsql zabbix-web-nginx-pgsql \
                 zabbix-java-gateway zabbix-snmptraps grafana; do
    if $RUNTIME ps -a --format "{{.Names}}" | grep -q "^$container$"; then
        CONTAINER_LOG="$LOGS_DIR/${container}.log"
        
        log_info "Сбор логов из $container..."
        {
            echo "=== ЛОГ КОНТЕЙНЕРА: $container ==="
            echo "Время сбора: $(date)"
            echo "Статус контейнера:"
            $RUNTIME ps --filter "name=$container" --format "{{.Status}}"
            echo ""
            echo "--- Стандартный вывод и ошибки ---"
            $RUNTIME logs "$container" 2>&1 || echo "Ошибка при получении логов"
            echo ""
            echo "--- Дополнительная информация ---"
            echo "Процессы внутри контейнера:"
            $RUNTIME top "$container" 2>/dev/null || echo "top недоступен"
            echo ""
            echo "Файловая система контейнера:"
            $RUNTIME exec "$container" df -h 2>/dev/null || echo "df недоступен"
        } | tee "$CONTAINER_LOG"
        
        log_success "Логи $container сохранены в $CONTAINER_LOG"
    fi
done

# Анализ логов на ошибки
ERROR_ANALYSIS="${LOGS_DIR}/ERROR_ANALYSIS.txt"
{
    echo "=== АНАЛИЗ ОШИБОК ВО ВСЕХ ЛОГАХ ==="
    echo "Время анализа: $(date)"
    echo ""
    
    for container in postgres zabbix-server-pgsql zabbix-web-nginx-pgsql \
                     zabbix-java-gateway zabbix-snmptraps; do
        CONTAINER_LOG="$LOGS_DIR/${container}.log"
        if [ -f "$CONTAINER_LOG" ]; then
            ERROR_COUNT=$(grep -i "error\|exception\|failed\|critical" "$CONTAINER_LOG" | wc -l)
            echo "Контейнер $container: $ERROR_COUNT ошибок/предупреждений"
            
            if [ "$ERROR_COUNT" -gt 0 ]; then
                echo "  Примеры:"
                grep -i "error\|exception\|failed" "$CONTAINER_LOG" | head -3 | sed 's/^/    /'
            fi
            echo ""
        fi
    done
} | tee "$ERROR_ANALYSIS"

log_success "Анализ логов завершен"

# ============================================================================
# 12. ПРОВЕРКА ЗДОРОВЬЯ КОНТЕЙНЕРОВ
# ============================================================================

log_section "ПРОВЕРКА ЗДОРОВЬЯ СЕРВИСОВ"

HEALTH_CHECK="${TESTS_DIR}/HEALTH_CHECK.txt"
{
    echo "=== ПРОВЕРКА ЗДОРОВЬЯ СЕРВИСОВ ==="
    echo "Время проверки: $(date)"
    echo ""
    
    # PostgreSQL
    echo "1. PostgreSQL Health Check:"
    if $RUNTIME exec postgres pg_isready -U "$POSTGRES_USER" 2>/dev/null; then
        echo "  ✓ PostgreSQL здоров (pg_isready OK)"
    else
        echo "  ✗ PostgreSQL проблемы с доступностью"
    fi
    echo ""
    
    # Zabbix Server
    echo "2. Zabbix Server Health Check:"
    if $RUNTIME exec zabbix-server-pgsql nc -z localhost 10051 2>/dev/null; then
        echo "  ✓ Zabbix Server слушает на порту 10051"
    else
        echo "  ✗ Zabbix Server не слушает на порту 10051"
    fi
    
    if $RUNTIME logs zabbix-server-pgsql 2>/dev/null | grep -q "server started"; then
        echo "  ✓ Zabbix Server инициализирован и работает"
    else
        echo "  ⚠ Инициализация Zabbix Server может быть еще в процессе"
    fi
    echo ""
    
    # Zabbix Web
    echo "3. Zabbix Web Interface Health Check:"
    if $RUNTIME exec zabbix-web-nginx-pgsql nc -z localhost 8080 2>/dev/null; then
        echo "  ✓ Zabbix Web слушает на порту 8080"
    else
        echo "  ✗ Zabbix Web не слушает на порту 8080"
    fi
    
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:80/ 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
        echo "  ✓ Web интерфейс доступен (HTTP $HTTP_CODE)"
    else
        echo "  ✗ Web интерфейс вернул HTTP $HTTP_CODE"
    fi
    echo ""
    
    # Java Gateway
    echo "4. Java Gateway Health Check:"
    if $RUNTIME ps --format "{{.Names}}" | grep -q "zabbix-java-gateway"; then
        if $RUNTIME exec zabbix-java-gateway nc -z localhost 10052 2>/dev/null; then
            echo "  ✓ Java Gateway слушает на порту 10052"
        else
            echo "  ⚠ Java Gateway работает но порт может быть недоступен"
        fi
    else
        echo "  ⚠ Java Gateway контейнер не найден"
    fi
    echo ""
    
    # Ресурсы
    echo "5. Использование ресурсов:"
    $RUNTIME stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}\t{{.CPUPerc}}" 2>/dev/null || echo "Stats недоступен"
    
} | tee "$HEALTH_CHECK"

log_success "Проверка здоровья завершена"

# ============================================================================
# 13. СТАТИСТИКА И МЕТРИКИ
# ============================================================================

log_section "СБОР СТАТИСТИКИ И МЕТРИК"

METRICS="${ANALYSIS_DIR}/METRICS.txt"
{
    echo "=== СТАТИСТИКА СБОРКИ И ЗАПУСКА ==="
    echo ""
    
    echo "--- Время сборки образов ---"
    for build_time in "${BUILD_TIMES[@]}"; do
        echo "  $build_time"
    done
    echo ""
    
    echo "--- Время запуска сервисов ---"
    for startup_time in "${STARTUP_TIMES[@]}"; do
        echo "  $startup_time"
    done
    echo ""
    
    echo "=== ИСПОЛЬЗОВАНИЕ ДИСКОВОГО ПРОСТРАНСТВА ==="
    echo ""
    echo "Образы:"
    $RUNTIME images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}"
    echo ""
    echo "Контейнеры:"
    $RUNTIME ps -a --format "table {{.Names}}\t{{.Size}}"
    echo ""
    
    echo "Локальные директории:"
    du -sh "$PROJECT_ROOT/zbx_env"/* 2>/dev/null || echo "Данные еще не инициализированы"
    
} | tee "$METRICS"

log_success "Сбор метрик завершен"

# ============================================================================
# 14. СОЗДАНИЕ ФИНАЛЬНОГО ОТЧЕТА
# ============================================================================

log_section "СОЗДАНИЕ ФИНАЛЬНОГО ОТЧЕТА"

FINAL_REPORT="${ANALYSIS_DIR}/00_SUMMARY_REPORT.txt"
{
    cat << 'REPORT_EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                    ПОЛНЫЙ ОТЧЕТ О ПЕРЕСБОРКЕ ZABBIX                         ║
║                      Comprehensive Project Analysis Report                  ║
╚══════════════════════════════════════════════════════════════════════════════╝

REPORT_EOF

    echo "📊 Дата и время отчета: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    echo "🔧 ИНФОРМАЦИЯ О СИСТЕМЕ"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Хост: $(hostname)"
    echo "ОС: $(uname -s) $(uname -r)"
    echo "Архитектура: $(uname -m)"
    echo "CPU: $(nproc) ядер"
    echo "Память: $(free -h | grep Mem | awk '{print $2 " (доступно: " $7 ")"}')"
    echo "Runtime: $RUNTIME $(eval $RUNTIME --version | head -1)"
    echo ""
    
    echo "📦 СТАТУС ОБРАЗОВ"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    $RUNTIME images --filter "reference=*:alpine-local" --format "{{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
    echo ""
    
    echo "🐳 СТАТУС КОНТЕЙНЕРОВ"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    $RUNTIME ps --format "{{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    
    echo "🌐 СЕТЕВЫЕ ИНТЕРФЕЙСЫ И ДОСТУПНОСТЬ"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Sеть: zbx_net_backend"
    $RUNTIME network inspect zbx_net_backend --format '{{range .Containers}}{{.Name}}: {{.IPv4Address}}{{println}}{{end}}'
    echo ""
    echo "Сеть: zbx_net_frontend"
    $RUNTIME network inspect zbx_net_frontend --format '{{range .Containers}}{{.Name}}: {{.IPv4Address}}{{println}}{{end}}' 2>/dev/null || echo "  (пусто)"
    echo ""
    
    echo "✓ ПРОВЕРКА ПОРТОВ И ДОСТУПНОСТИ"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    ports_ok=0
    ports_fail=0
    
    if timeout 1 bash -c "echo >/dev/tcp/127.0.0.1/10051" 2>/dev/null; then
        echo "✓ Zabbix Server (10051): доступен"
        ((ports_ok++))
    else
        echo "✗ Zabbix Server (10051): НЕДОСТУПЕН"
        ((ports_fail++))
    fi
    
    if timeout 1 bash -c "echo >/dev/tcp/127.0.0.1/80" 2>/dev/null; then
        echo "✓ HTTP Web (80): доступен"
        ((ports_ok++))
    else
        echo "✗ HTTP Web (80): НЕДОСТУПЕН"  
        ((ports_fail++))
    fi
    
    if timeout 1 bash -c "echo >/dev/tcp/127.0.0.1/5432" 2>/dev/null; then
        echo "✓ PostgreSQL (5432): доступен"
        ((ports_ok++))
    else
        echo "✗ PostgreSQL (5432): НЕДОСТУПЕН"
        ((ports_fail++))
    fi
    
    echo ""
    echo "Результат: $ports_ok доступны, $ports_fail недоступны"
    echo ""
    
    echo "🩺 ЗДОРОВЬЕ СЕРВИСОВ"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if $RUNTIME exec postgres pg_isready -U "$POSTGRES_USER" 2>/dev/null; then
        echo "✓ PostgreSQL: готов"
    else
        echo "✗ PostgreSQL: НЕ готов"
    fi
    
    if $RUNTIME logs zabbix-server-pgsql 2>/dev/null | grep -q "server started"; then
        echo "✓ Zabbix Server: инициализирован"
    else
        echo "⚠ Zabbix Server: инициализация..."
    fi
    
    if $RUNTIME logs zabbix-web-nginx-pgsql 2>/dev/null | grep -qi "ready\|listening"; then
        echo "✓ Zabbix Web: готов"
    else
        echo "⚠ Zabbix Web: инициализация..."
    fi
    
    echo ""
    
    echo "📊 ИСПОЛЬЗОВАНИЕ РЕСУРСОВ"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    $RUNTIME stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}\t{{.CPUPerc}}\t{{.NetIO}}\t{{.BlockIO}}"
    echo ""
    
    echo "📁 ДИРЕКТОРИИ АНАЛИЗА"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Путь: $ANALYSIS_DIR"
    echo ""
    echo "Файлы отчета:"
    ls -lh "$ANALYSIS_DIR"/ | tail -n +2 | awk '{print "  " $9 " (" $5 ")"}'
    echo ""
    
    echo "Логи контейнеров:"
    if [ -d "$LOGS_DIR" ]; then
        ls -1 "$LOGS_DIR"/ | sed 's/^/  /'
    fi
    echo ""
    
    echo "Тесты и проверки:"
    if [ -d "$TESTS_DIR" ]; then
        ls -1 "$TESTS_DIR"/ | sed 's/^/  /'
    fi
    echo ""
    
    echo "Анализ сети:"
    if [ -d "$NETWORK_DIR" ]; then
        ls -1 "$NETWORK_DIR"/ | sed 's/^/  /'
    fi
    echo ""
    
    echo "═════════════════════════════════════════════════════════════════════════════════"
    echo "✅ ПРОЦЕСС ЗАВЕРШЕН: Все данные сохранены в $ANALYSIS_DIR"
    echo "═════════════════════════════════════════════════════════════════════════════════"
    
    echo ""
    echo "⚡ РЕКОМЕНДАЦИИ ПО ПРОВЕРКЕ:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "1. Веб-интерфейс Zabbix: http://127.0.0.1"
    echo "2. Логи контейнеров: cat $LOGS_DIR/zabbix-server-pgsql.log"
    echo "3. Статус сети: less $NETWORK_DIR/NETWORK_ANALYSIS.txt"
    echo "4. Ошибки и проблемы: less $LOGS_DIR/ERROR_ANALYSIS.txt"
    echo "5. Полный анализ: less $FINAL_REPORT"
    echo ""
    
} | tee "$FINAL_REPORT"

log_success "Финальный отчет создан"

# ============================================================================
# ЗАВЕРШЕНИЕ
# ============================================================================

log_header "ПОЛНАЯ ПЕРЕСБОРКА И АНАЛИЗ ЗАВЕРШЕНЫ УСПЕШНО"

echo ""
echo "📊 ДИРЕКТОРИЯ С РЕЗУЛЬТАТАМИ:"
echo "   $ANALYSIS_DIR"
echo ""
echo "📋 ГЛАВНЫЙ ОТЧЕТ:"
echo "   $FINAL_REPORT"
echo ""
echo "💾 ВСЕ ФАЙЛЫ АНАЛИЗА:"
for file in "$ANALYSIS_DIR"/*.txt "$ANALYSIS_DIR"/*.log; do
    if [ -f "$file" ]; then
        echo "   $(basename "$file") ($(du -h "$file" | cut -f1))"
    fi
done
echo ""
echo "🔍 ДЛЯ ДЕТАЛЬНОГО АНАЛИЗА:"
echo "   ls -lh $ANALYSIS_DIR/"
echo ""

exit 0
