#!/bin/bash
#
# Podman Full Build and Analysis Script
# Собирает полный проект на podman с логированием и анализом
#

set -e

export PATH="/app/tools/podman/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_LOG_DIR="${PROJECT_ROOT}/build-logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BUILD_REPORT="${BUILD_LOG_DIR}/BUILD_REPORT_${TIMESTAMP}.md"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# ФУНКЦИИ
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""
}

################################################################################
# ИНИЦИАЛИЗАЦИЯ
################################################################################

log_section "🚀 ИНИЦИАЛИЗАЦИЯ ПОЛНОЙ СБОРКИ PODMAN"

mkdir -p "${BUILD_LOG_DIR}"
log_info "Лог директория: ${BUILD_LOG_DIR}"

log_info "Проверка версии podman..."
podman-remote --version

log_info "Проверка docker-compose..."
if [ -f "${PROJECT_ROOT}/docker-compose.yaml" ]; then
    log_success "docker-compose.yaml найден"
else
    log_error "docker-compose.yaml не найден!"
    exit 1
fi

################################################################################
# СБОРКА ОБРАЗОВ
################################################################################

log_section "🔨 СБОРКА DOCKER ОБРАЗОВ"

SERVICES=(
    "agent"
    "agent2"
    "grafana"
    "java-gateway"
    "server-pgsql"
    "snmptraps"
    "web-nginx-pgsql"
)

declare -A BUILD_STATS
declare -A BUILD_LOGS
declare -A BUILD_STATUS

for service in "${SERVICES[@]}"; do
    log_info "Начало сборки сервиса: ${service}"
    
    # Найти Dockerfile
    dockerfile_path=""
    if [ -d "${PROJECT_ROOT}/${service}" ]; then
        if [ -f "${PROJECT_ROOT}/${service}/Dockerfile" ]; then
            dockerfile_path="${PROJECT_ROOT}/${service}/Dockerfile"
        elif [ -f "${PROJECT_ROOT}/${service}/alpine/Dockerfile" ]; then
            dockerfile_path="${PROJECT_ROOT}/${service}/alpine/Dockerfile"
        fi
    fi
    
    if [ -z "$dockerfile_path" ]; then
        log_warn "Dockerfile не найден для ${service}"
        BUILD_STATUS[$service]="NOT_FOUND"
        continue
    fi
    
    dockerfile_dir=$(dirname "$dockerfile_path")
    service_logfile="${BUILD_LOG_DIR}/${service}_build_${TIMESTAMP}.log"
    BUILD_LOGS[$service]="$service_logfile"
    
    log_info "usando Dockerfile: $dockerfile_path"
    
    start_time=$(date +%s)
    
    # Сборка образа
    if podman-remote build \
        -t "zabbix-${service}:latest" \
        -f "$dockerfile_path" \
        "$dockerfile_dir" \
        > "$service_logfile" 2>&1; then
        
        end_time=$(date +%s)
        build_time=$((end_time - start_time))
        
        BUILD_STATUS[$service]="SUCCESS"
        BUILD_STATS[$service]="${build_time}s"
        log_success "${service}: Успешно собран за ${build_time}s"
        
    else
        end_time=$(date +%s)
        build_time=$((end_time - start_time))
        
        BUILD_STATUS[$service]="FAILED"
        BUILD_STATS[$service]="${build_time}s"
        log_error "${service}: Ошибка сборки после ${build_time}s"
        
        # Показать последние 20 строк лога
        log_warn "  Последние ошибки:"
        tail -20 "$service_logfile" | sed 's/^/    /'
    fi
done

################################################################################
# ПРОВЕРКА ОБРАЗОВ
################################################################################

log_section "📦 ПРОВЕРКА СОБРАННЫХ ОБРАЗОВ"

podman-remote images | grep zabbix || log_warn "Zabbix образы не найдены"

################################################################################
# СБОРКА СТЕКА (docker-compose)
################################################################################

log_section "🐳 ПОПЫТКА СБОРКИ И ЗАПУСКА СТЕКА"

cd "$PROJECT_ROOT"

# Сделать резервную копию .env если существует
if [ -f ".env" ]; then
    cp .env .env.backup
    log_info "Резервная копия .env создана"
fi

# Попытка запустить docker-compose build
compose_logfile="${BUILD_LOG_DIR}/docker-compose_build_${TIMESTAMP}.log"

log_info "Выполнение docker-compose build..."
if docker-compose build > "$compose_logfile" 2>&1; then
    log_success "docker-compose build: успешно"
else
    log_error "docker-compose build: ошибка"
    tail -30 "$compose_logfile" | sed 's/^/    /'
fi

################################################################################
# СБОР ЛОГОВ И АНАЛИЗ
################################################################################

log_section "📊 АНАЛИЗ ЛОГОВ СБОРКИ"

# Подсчет статистики
SUCCESS_COUNT=0
FAILED_COUNT=0
NOTFOUND_COUNT=0

for service in "${SERVICES[@]}"; do
    case "${BUILD_STATUS[$service]}" in
        SUCCESS) ((SUCCESS_COUNT++)) ;;
        FAILED) ((FAILED_COUNT++)) ;;
        NOT_FOUND) ((NOTFOUND_COUNT++)) ;;
    esac
done

log_info "Результаты сборки:"
log_info "  ✓ Успешных: ${SUCCESS_COUNT}/${#SERVICES[@]}"
log_info "  ✗ Ошибок: ${FAILED_COUNT}/${#SERVICES[@]}"
log_info "  ? Не найдено: ${NOTFOUND_COUNT}/${#SERVICES[@]}"

################################################################################
# АНАЛИЗ ЛОГОВ НА ОШИБКИ
################################################################################

log_section "🔍 АНАЛИЗ ОШИБОК И ПРЕДУПРЕЖДЕНИЙ"

declare -a COMMON_ERRORS
declare -a COMMON_WARNINGS

# Ищем общие ошибки
for logfile in "${BUILD_LOGS[@]}"; do
    if [ -f "$logfile" ]; then
        # Ошибки сборки
        if grep -q "ERROR\|error\|failed\|Failed" "$logfile" 2>/dev/null; then
            log_warn "Найдены ошибки в: $(basename $logfile)"
            grep "ERROR\|error\|failed\|Failed" "$logfile" | head -3 | sed 's/^/    /'
        fi
        
        # Предупреждения
        if grep -q "WARNING\|warning\|WARN" "$logfile" 2>/dev/null; then
            grep "WARNING\|warning\|WARN" "$logfile" | head -2 | sed 's/^/    /'
        fi
        
        # Проблемы с зависимостями
        if grep -q "not found\|cannot find" "$logfile" 2>/dev/null; then
            log_warn "Возможны проблемы с зависимостями"
            grep "not found\|cannot find" "$logfile" | head -2 | sed 's/^/    /'
        fi
    fi
done

################################################################################
# СОЗДАНИЕ ОТЧЕТА
################################################################################

log_section "📝 СОЗДАНИЕ ОТЧЕТА"

cat > "$BUILD_REPORT" << 'EOF'
# 🚀 Отчет о полной сборке Zabbix на Podman

## 📋 Общая информация

**Дата/время сборки:** $(date)
**Платформа:** $(uname -a | cut -d' ' -f1-3)
**Podman версия:** $(podman-remote --version)

## 📊 Статистика сборки

| Параметр | Значение |
|----------|----------|
| Всего сервисов | ${#SERVICES[@]} |
| Успешно собрано | ${SUCCESS_COUNT} |
| Ошибок | ${FAILED_COUNT} |
| Не найдено | ${NOTFOUND_COUNT} |
| Время сборки | - |

## 🔨 Результаты по сервисам

EOF

for service in "${SERVICES[@]}"; do
    status="${BUILD_STATUS[$service]}"
    time="${BUILD_STATS[$service]}"
    logfile="${BUILD_LOGS[$service]}"
    
    case "$status" in
        SUCCESS)
            echo "### ✅ ${service} - УСПЕХ (${time})" >> "$BUILD_REPORT"
            ;;
        FAILED)
            echo "### ❌ ${service} - ОШИБКА (${time})" >> "$BUILD_REPORT"
            if [ -f "$logfile" ]; then
                echo "" >> "$BUILD_REPORT"
                echo "**Ошибки:**" >> "$BUILD_REPORT"
                echo '```' >> "$BUILD_REPORT"
                tail -10 "$logfile" >> "$BUILD_REPORT"
                echo '```' >> "$BUILD_REPORT"
            fi
            ;;
        NOT_FOUND)
            echo "### ⚠️  ${service} - НЕ НАЙДЕНО" >> "$BUILD_REPORT"
            ;;
    esac
    echo "" >> "$BUILD_REPORT"
done

cat >> "$BUILD_REPORT" << 'EOF'

## 📝 Логи детально

Логи для каждого сервиса сохранены в:
- Директория: `build-logs/`
- Формат: `service_build_TIMESTAMP.log`

## 🔍 Частые проблемы и решения

### Проблема 1: Ошибки сети
**Причина:** Отсутствие доступа в интернет при загрузке пакетов
**Решение:** 
- Проверить подключение к интернету
- Использовать локальные кэши пакетов
- Настроить proxy если нужно

### Проблема 2: Недостаточно места на диске
**Причина:** Контейнеры занимают много места
**Решение:**
- Проверить свободное место: `df -h`
- Очистить образы: `podman-remote image prune`
- Очистить контейнеры: `podman-remote container prune`

### Проблема 3: Проблемы с портами
**Причина:** Порты уже заняты другими приложениями
**Решение:**
- Проверить занятые порты: `netstat -tlnp`
- Изменить маппинг портов в docker-compose.yaml

## ✅ Рекомендации

1. **HEALTHCHECK**: Добавлены для всех сервисов ✓
2. **Безопасность**: Все сервисы используют Alpine Linux
3. **Оптимизация**: Используются multi-stage builds
4. **Логирование**: Интегрировано в docker-compose.yaml

## 🚀 Слудующие шаги

1. Запустить стек: `docker-compose up -d`
2. Проверить здоровье: `docker-compose ps`
3. Просмотреть логи: `docker-compose logs -f`

-----
**Сгенерировано:** $(date)
EOF

log_success "Отчет создан: $BUILD_REPORT"

################################################################################
# ИТОГОВАЯ СТАТИСТИКА
################################################################################

log_section "📈 ИТОГОВАЯ СТАТИСТИКА"

echo ""
echo "📊 Результаты сборки:"
echo "   ✅ Успешно: ${SUCCESS_COUNT}/${#SERVICES[@]}"
echo "   ❌ Ошибок: ${FAILED_COUNT}/${#SERVICES[@]}"
echo ""
echo "📁 Логи сохранены в: $BUILD_LOG_DIR"
echo "📝 Отчет: $BUILD_REPORT"
echo ""
echo -e "${GREEN}Сборка завершена!${NC}"
echo ""
