#!/bin/bash
#
# 📦 COMPREHENSIVE CONTAINER LOGGING FRAMEWORK
# Полный фреймворк логирования для всех контейнеров с анализом
#
# Использование: ./container-logging-framework.sh

set -euo pipefail

# ============================================================================
# ЗАВИСИМОСТИ И КОНФИГУРАЦИЯ
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/container-logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="${LOG_DIR}/container_report_${TIMESTAMP}.json"
HUMAN_REPORT="${LOG_DIR}/container_issues_${TIMESTAMP}.md"
STDOUT_LOG="${LOG_DIR}/all_container_stdout_${TIMESTAMP}.log"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# JSON для хранения результатов
declare -a SERVICES
declare -a CONTAINERS
declare -a ISSUES
declare -a FIXES

# ============================================================================
# ФУНКЦИИ ЛОГИРОВАНИЯ
# ============================================================================

log_info() {
    local msg="$1"
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $msg" | tee -a "$STDOUT_LOG"
}

log_success() {
    local msg="$1"
    echo -e "${GREEN}[✓]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $msg" | tee -a "$STDOUT_LOG"
}

log_warning() {
    local msg="$1"
    echo -e "${YELLOW}[!]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $msg" | tee -a "$STDOUT_LOG"
}

log_error() {
    local msg="$1"
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $msg" | tee -a "$STDOUT_LOG"
}

log_section() {
    local title="$1"
    echo "" | tee -a "$STDOUT_LOG"
    echo -e "${CYAN}════════════════════════════════════════════${NC}" | tee -a "$STDOUT_LOG"
    echo -e "${CYAN}$title${NC}" | tee -a "$STDOUT_LOG"
    echo -e "${CYAN}════════════════════════════════════════════${NC}" | tee -a "$STDOUT_LOG"
    echo "" | tee -a "$STDOUT_LOG"
}

# ============================================================================
# JSON HELPERS
# ============================================================================

add_issue() {
    local service="$1"
    local container="$2"
    local severity="$3"  # critical, high, medium, low
    local issue="$4"
    local location="$5"
    local fix="$6"
    
    ISSUES+=("{
        \"service\": \"$service\",
        \"container\": \"$container\",
        \"severity\": \"$severity\",
        \"issue\": \"$issue\",
        \"location\": \"$location\",
        \"fix\": \"$fix\",
        \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
    }")
}

# ============================================================================
# ПРОВЕРКА DOCKER COMPOSE
# ============================================================================

check_docker_compose() {
    log_section "ПРОВЕРКА DOCKER COMPOSE КОНФИГУРАЦИИ"
    
    if [ ! -f "docker-compose.yaml" ]; then
        log_error "docker-compose.yaml не найден"
        return 1
    fi
    
    log_success "docker-compose.yaml найден"
    
    # Проверить синтаксис
    if docker-compose config &>/dev/null; then
        log_success "docker-compose.yaml синтаксис OK"
    else
        log_error "docker-compose.yaml имеет синтаксические ошибки"
        docker-compose config 2>&1 | head -20
        add_issue "docker-compose" "general" "high" \
            "Синтаксическая ошибка в docker-compose.yaml" \
            "docker-compose.yaml" \
            "Проверить YAML синтаксис и исправить ошибки"
    fi
    
    # Получить список сервисов
    mapfile -t SERVICES < <(docker-compose config --services)
    log_info "Найдено сервисов: ${#SERVICES[@]}"
    for service in "${SERVICES[@]}"; do
        log_info "  • $service"
    done
}

# ============================================================================
# ЗАПУСК И ЛОГИРОВАНИЕ КОНТЕЙНЕРОВ
# ============================================================================

start_docker_compose() {
    log_section "ЗАПУСК DOCKER COMPOSE СТЕКА"
    
    log_info "Запуск docker-compose..."
    
    if docker-compose up -d 2>&1 | tee -a "$STDOUT_LOG"; then
        log_success "docker-compose успешно запущен"
        
        # Дать контейнерам время на инициализацию
        log_info "Ожидание инициализации контейнеров (10 сек)..."
        sleep 10
        
        # Получить список запущенных контейнеров
        mapfile -t CONTAINERS < <(docker-compose ps -q)
        log_success "Контейнеры запущены: ${#CONTAINERS[@]}"
    else
        log_error "Ошибка при запуске docker-compose"
        return 1
    fi
}

# ============================================================================
# СБОР ЛОГОВ ИЗ КОНТЕЙНЕРОВ
# ============================================================================

collect_container_logs() {
    log_section "СБОР ЛОГОВ ИЗ ВСЕХ КОНТЕЙНЕРОВ"
    
    for service in "${SERVICES[@]}"; do
        log_info "Сбор логов для: $service"
        
        local container_log="${LOG_DIR}/${service}_full_${TIMESTAMP}.log"
        
        # Собрать все логи контейнера
        if docker-compose logs "$service" > "$container_log" 2>&1; then
            local log_size=$(du -h "$container_log" | awk '{print $1}')
            log_success "Логи $service сохранены ($log_size)"
            
            # Также добавить в общий stdout лог
            echo "" >> "$STDOUT_LOG"
            echo "=== CONTAINER: $service ===" >> "$STDOUT_LOG"
            cat "$container_log" >> "$STDOUT_LOG"
            
        else
            log_error "Ошибка при сборе логов $service"
            add_issue "$service" "$service" "high" \
                "Не удалось собрать логи контейнера" \
                "docker-compose logs $service" \
                "Проверить что контейнер запущен и в него доступно логирование"
        fi
    done
}

# ============================================================================
# АНАЛИЗ ЛОГОВ КОНТЕЙНЕРОВ
# ============================================================================

analyze_container_logs() {
    log_section "АНАЛИЗ ЛОГОВ КОНТЕЙНЕРОВ НА ОШИБКИ"
    
    for service in "${SERVICES[@]}"; do
        log_info "Анализ логов: $service"
        
        local container_log="${LOG_DIR}/${service}_full_${TIMESTAMP}.log"
        
        if [ ! -f "$container_log" ]; then
            continue
        fi
        
        # Проверить на различные типы ошибок
        
        # 1. ERROR messages
        if grep -qi "error\|failed\|exception" "$container_log"; then
            local error_count=$(grep -ci "error\|failed\|exception" "$container_log")
            log_error "$service: Найдено $error_count ошибок"
            
            echo "" >> "$STDOUT_LOG"
            echo "=== ERRORS in $service ===" >> "$STDOUT_LOG"
            grep -i "error\|failed\|exception" "$container_log" | head -10 >> "$STDOUT_LOG"
            
            add_issue "$service" "$service" "high" \
                "Обнаружены ошибки в логах: $error_count" \
                "Логи: $(tail -1 < <(grep -in 'error\|failed' "$container_log" | tail -1 | cut -d: -f1))" \
                "Проверить логи: docker-compose logs $service"
        fi
        
        # 2. WARNING messages
        if grep -qi "warning\|warn" "$container_log"; then
            local warn_count=$(grep -ci "warning\|warn" "$container_log")
            log_warning "$service: Найдено $warn_count предупреждений"
        fi
        
        # 3. OOM/Memory errors
        if grep -qi "out of memory\|cannot allocate" "$container_log"; then
            log_error "$service: Ошибка памяти!"
            add_issue "$service" "$service" "critical" \
                "Контейнер столкнулся с нехваткой памяти" \
                "Все логи контейнера" \
                "Увеличить лимит памяти в docker-compose.yaml (mem_limit)"
        fi
        
        # 4. Connection errors
        if grep -qi "connection refused\|connection reset\|no such host" "$container_log"; then
            log_error "$service: Ошибки соединения"
            add_issue "$service" "$service" "high" \
                "Ошибки соединения между контейнерами" \
                "Сетевая конфигурация docker-compose" \
                "Проверить сетевые зависимости и порты в docker-compose.yaml"
        fi
        
        # 5. Port already in use
        if grep -qi "address already in use\|port.*bound" "$container_log"; then
            log_error "$service: Порт уже используется"
            add_issue "$service" "$service" "high" \
                "Порт уже в использовании" \
                "Конфигурация портов в docker-compose.yaml" \
                "Проверить ports: секцию, убедиться что ports не повторяются"
        fi
        
        # 6. Startup failures
        if grep -qi "failed to start\|could not start\|startup.*failed" "$container_log"; then
            log_error "$service: Ошибка при запуске"
            add_issue "$service" "$service" "critical" \
                "Контейнер не смог стартовать" \
                "Инициализация сервиса" \
                "Проверить environment variables, volumes и зависимости"
        fi
        
        # 7. Build issues
        if grep -qi "build failed\|compilation failed\|exit code" "$container_log"; then
            log_error "$service: Ошибки при сборке"
            add_issue "$service" "$service" "critical" \
                "Ошибки при сборке контейнера" \
                "Dockerfile или build процесс" \
                "Пересобрать образ: docker-compose build --no-cache $service"
        fi
    done
}

# ============================================================================
# ПРОВЕРКА HEALTHCHECKS
# ============================================================================

check_container_health() {
    log_section "ПРОВЕРКА ЗДОРОВЬЯ КОНТЕЙНЕРОВ"
    
    for service in "${SERVICES[@]}"; do
        log_info "Проверка здоровья: $service"
        
        local container_id=$(docker-compose ps -q "$service")
        
        if [ -z "$container_id" ]; then
            log_error "$service: Контейнер не запущен"
            add_issue "$service" "$service" "critical" \
                "Контейнер не запущен" \
                "docker-compose ps" \
                "Запустить: docker-compose up -d $service"
            continue
        fi
        
        # Проверить health status
        local health=$(docker inspect --format='{{.State.Health.Status}}' "$container_id" 2>/dev/null || echo "N/A")
        
        if [ "$health" = "healthy" ]; then
            log_success "$service: Healthy ✓"
        elif [ "$health" = "unhealthy" ]; then
            log_error "$service: Unhealthy ✗"
            
            # Получить детали
            docker inspect --format='{{json .State.Health}}' "$container_id" | tee -a "$STDOUT_LOG"
            
            add_issue "$service" "$service" "critical" \
                "Контейнер unhealthy (healthcheck failed)" \
                "Healthcheck конфигурация docker-compose.yaml" \
                "Проверить healthcheck условия и логи контейнера"
        else
            log_warning "$service: Health status: $health"
        fi
        
        # Получить статус контейнера
        local status=$(docker-compose ps "$service" | tail -1 | awk '{print $(NF-1)}')
        log_info "  Статус: $status"
    done
}

# ============================================================================
# ПРОВЕРКА РЕСУРСОВ
# ============================================================================

check_resource_usage() {
    log_section "ПРОВЕРКА ИСПОЛЬЗОВАНИЯ РЕСУРСОВ"
    
    log_info "Использование памяти:"
    docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}\t{{.CPUPerc}}" 2>/dev/null | tee -a "$STDOUT_LOG"
    
    # Проверить на проблемы с ресурсами
    for service in "${SERVICES[@]}"; do
        local container_id=$(docker-compose ps -q "$service")
        
        if [ -z "$container_id" ]; then
            continue
        fi
        
        # Получить использование памяти
        local mem_usage=$(docker stats --no-stream --format "{{.MemUsage}}" "$container_id" 2>/dev/null | cut -d'/' -f1)
        
        if [ ! -z "$mem_usage" ]; then
            log_info "$service: Memory = $mem_usage"
        fi
    done
}

# ============================================================================
# ГЕНЕРИРОВАНИЕ JSON ОТЧЕТА
# ============================================================================

generate_json_report() {
    log_section "ГЕНЕРИРОВАНИЕ JSON ОТЧЕТА"
    
    {
        echo "{"
        echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
        echo "  \"total_services\": ${#SERVICES[@]},"
        echo "  \"services\": ["
        
        for i in "${!SERVICES[@]}"; do
            local service="${SERVICES[$i]}"
            echo "    {"
            echo "      \"name\": \"$service\","
            echo "      \"status\": \"$(docker-compose ps "$service" | tail -1 | awk '{print $(NF-1)}' || echo 'unknown')\""
            echo "    }$([ $((i + 1)) -lt ${#SERVICES[@]} ] && echo ',' || echo '')"
        done
        
        echo "  ],"
        echo "  \"issues\": ${#ISSUES[@]},"
        echo "  \"issues_list\": ["
        
        for i in "${!ISSUES[@]}"; do
            echo "    ${ISSUES[$i]}$([ $((i + 1)) -lt ${#ISSUES[@]} ] && echo ',' || echo '')"
        done
        
        echo "  ]"
        echo "}"
    } > "$REPORT_FILE"
    
    log_success "JSON отчет: $(basename $REPORT_FILE)"
}

# ============================================================================
# ГЕНЕРИРОВАНИЕ HUMAN-READABLE ОТЧЕТА
# ============================================================================

generate_human_report() {
    log_section "ГЕНЕРИРОВАНИЕ READABLE ОТЧЕТА"
    
    cat > "$HUMAN_REPORT" << 'REPORT_EOF'
# 📊 CONTAINER LOGGING & ANALYSIS REPORT

**Дата анализа**: $(date)
**Версия**: 1.0

---

## 📋 ОГЛАВЛЕНИЕ

1. [Обзор и статистика](#обзор)
2. [Критические проблемы](#критические)
3. [Высокие приоритеты](#высокие)
4. [Рекомендации](#рекомендации)

---

## 📌 Обзор {#обзор}

| Метрика | Значение |
|---------|----------|
| Всего сервисов | ${#SERVICES[@]} |
| Найдено проблем | ${#ISSUES[@]} |
| Критических | $(grep -c '"severity": "critical"' <<< "$(printf '%s\n' "${ISSUES[@]}")" || echo 0) |
| Высоких | $(grep -c '"severity": "high"' <<< "$(printf '%s\n' "${ISSUES[@]}")" || echo 0) |

---

## 🔴 Критические проблемы {#критические}

REPORT_EOF

    # Добавить критические проблемы
    for issue in "${ISSUES[@]}"; do
        if echo "$issue" | grep -q '"severity": "critical"'; then
            local service=$(echo "$issue" | grep -o '"service": "[^"]*' | cut -d'"' -f4)
            local description=$(echo "$issue" | grep -o '"issue": "[^"]*' | cut -d'"' -f4)
            local location=$(echo "$issue" | grep -o '"location": "[^"]*' | cut -d'"' -f4)
            local fix=$(echo "$issue" | grep -o '"fix": "[^"]*' | cut -d'"' -f4)
            
            cat >> "$HUMAN_REPORT" << EOF

### ❌ $service: $description

**Место**: $location  
**Решение**: $fix

---

EOF
        fi
    done
    
    cat >> "$HUMAN_REPORT" << 'REPORT_EOF'

## 🟡 Высокие приоритеты {#высокие}

REPORT_EOF

    # Добавить high приоритеты
    for issue in "${ISSUES[@]}"; do
        if echo "$issue" | grep -q '"severity": "high"'; then
            local service=$(echo "$issue" | grep -o '"service": "[^"]*' | cut -d'"' -f4)
            local description=$(echo "$issue" | grep -o '"issue": "[^"]*' | cut -d'"' -f4)
            local location=$(echo "$issue" | grep -o '"location": "[^"]*' | cut -d'"' -f4)
            local fix=$(echo "$issue" | grep -o '"fix": "[^"]*' | cut -d'"' -f4)
            
            cat >> "$HUMAN_REPORT" << EOF

### ⚠️  $service: $description

**Место**: $location  
**Решение**: $fix

---

EOF
        fi
    done
    
    log_success "Readable отчет: $(basename $HUMAN_REPORT)"
}

# ============================================================================
# ОСТАНОВКА И ОЧИСТКА
# ============================================================================

cleanup() {
    log_section "ОСТАНОВКА И ОЧИСТКА"
    
    log_info "Остановка docker-compose..."
    docker-compose down 2>&1 | tee -a "$STDOUT_LOG" || true
    
    log_success "Очистка завершена"
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║      COMPREHENSIVE CONTAINER LOGGING FRAMEWORK v1.0        ║"
    echo "║                                                            ║"
    echo "║  Универсальное логирование для всех Docker контейнеров   ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    mkdir -p "$LOG_DIR"
    
    cd "$(dirname "$0")/.." || exit 1
    
    # Запустить все этапы
    check_docker_compose || exit 1
    start_docker_compose || exit 1
    collect_container_logs
    analyze_container_logs
    check_container_health
    check_resource_usage
    generate_json_report
    generate_human_report
    cleanup
    
    # Итоги
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                  АНАЛИЗ ЗАВЕРШЕН                           ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "📁 Результаты:"
    echo "   JSON: $(basename $REPORT_FILE)"
    echo "   Readable: $(basename $HUMAN_REPORT)"
    echo "   All logs: $(basename $STDOUT_LOG)"
    echo ""
    echo "📊 Статистика:"
    echo "   Проблем найдено: ${#ISSUES[@]}"
    echo "   Сервисов проанализировано: ${#SERVICES[@]}"
    echo ""
}

main "$@"
