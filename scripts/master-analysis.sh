#!/bin/bash
#
# 📊 MASTER ANALYSIS & REPORTING SYSTEM
# Объединяет логирование, тестирование и генерирует детальные отчеты
#
# Использование:
#   ./master-analysis.sh [all|logs|tests|check|repair]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$(dirname "$SCRIPT_DIR")"
REPORTS_DIR="${SCRIPT_DIR}/../reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
MASTER_REPORT="${REPORTS_DIR}/master_analysis_${TIMESTAMP}.md"
JSON_REPORT="${REPORTS_DIR}/master_analysis_${TIMESTAMP}.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

declare -a ALL_ISSUES
declare -a ALL_RECOMMENDATIONS

# ============================================================================
# ФУНКЦИИ
# ============================================================================

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_section() { echo -e "\n${MAGENTA}╔════════════════════════════════════════════╗${NC}\n${MAGENTA}║${NC} $1\n${MAGENTA}╚════════════════════════════════════════════╝${NC}\n"; }

# ============================================================================
# ПРОВЕРКА ЛОГИРОВАНИЯ И STDOUT
# ============================================================================

analyze_logging() {
    log_section "АНАЛИЗ ЛОГИРОВАНИЯ И STDOUT"
    
    log_info "Проверка логирования в контейнерах..."
    
    # Проверить содержит ли docker-compose логирование
    if grep -q "logging:" docker-compose.yaml 2>/dev/null; then
        log_success "Логирование найдено в docker-compose.yaml"
    else
        log_warning "Логирование не конфигурировано в docker-compose.yaml"
        ALL_ISSUES+=("LOGGING_NOT_CONFIGURED")
        ALL_RECOMMENDATIONS+=("Добавить logging конфигурацию в docker-compose.yaml для всех сервисов
        
Пример для каждого сервиса:
\`\`\`yaml
services:
  service-name:
    logging:
      driver: json-file
      options:
        max-size: '10m'
        max-file: '3'
        labels: 'service=service-name'
\`\`\`")
    fi
    
    # Проверить docker-compose логирование для каждого контейнера
    for service in $(docker-compose config --services 2>/dev/null || echo ""); do
        log_info "Проверка $service..."
        
        # Получить логирование конфиг
        local log_driver=$(grep -A5 "^  $service:" docker-compose.yaml 2>/dev/null | grep -A5 "logging:" | head -1 || echo "")
        
        if [ -z "$log_driver" ]; then
            log_warning "$service: Нет явной конфигурации логирования"
        fi
    done
}

# ============================================================================
# ПРОВЕРКА HEALTHCHECKS
# ============================================================================

analyze_healthchecks() {
    log_section "АНАЛИЗ HEALTHCHECKS"
    
    log_info "Проверка HEALTHCHECK конфигурации..."
    
    local healthcheck_count=0
    local services_count=0
    
    for service in $(docker-compose config --services 2>/dev/null || echo ""); do
        ((services_count++))
        
        if grep -A20 "^  $service:" docker-compose.yaml 2>/dev/null | grep -q "healthcheck:"; then
            ((healthcheck_count++))
            log_success "$service: HEALTHCHECK найден"
        else
            log_warning "$service: HEALTHCHECK не конфигурирован"
            ALL_ISSUES+=("HEALTHCHECK_MISSING_$service")
            ALL_RECOMMENDATIONS+=("Добавить HEALTHCHECK для $service

Пример:
\`\`\`yaml
services:
  $service:
    healthcheck:
      test: [\"CMD\", \"your-health-check-command\"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
\`\`\`")
        fi
    done
    
    log_info "Статистика: ${healthcheck_count}/${services_count} сервисов имеют HEALTHCHECK"
    
    if [ $healthcheck_count -lt $services_count ]; then
        ALL_ISSUES+=("INCOMPLETE_HEALTHCHECK_COVERAGE")
    fi
}

# ============================================================================
# АНАЛИЗ ОШИБОК СБОРКИ
# ============================================================================

analyze_build_errors() {
    log_section "АНАЛИЗ ОШИБОК СБОРКИ"
    
    # Найти логи сборок
    local build_logs=$(find "${SCRIPT_DIR}/.." -name "*build*.log" -o -name "*docker*.log" 2>/dev/null | head -5)
    
    if [ -z "$build_logs" ]; then
        log_warning "Логи сборок не найдены"
        return
    fi
    
    for log_file in $build_logs; do
        log_info "Анализ: $(basename $log_file)"
        
        # Проверить на различные типы ошибок
        if grep -qi "exit code 2" "$log_file"; then
            log_error "Найдена ошибка: Exit Code 2 (Make compilation error)"
            ALL_ISSUES+=("BUILD_EXIT_CODE_2")
        fi
        
        if grep -qi "missing build dependencies" "$log_file"; then
            log_error "Найдена ошибка: Missing build dependencies"
            ALL_ISSUES+=("MISSING_BUILD_DEPS")
        fi
        
        if grep -qi "cannot find\|no such file" "$log_file"; then
            log_error "Найдена ошибка: File not found during build"
            ALL_ISSUES+=("BUILD_FILE_NOT_FOUND")
        fi
    done
}

# ============================================================================
# ПРОВЕРКА DOCKERFILES
# ============================================================================

analyze_dockerfiles() {
    log_section "АНАЛИЗ DOCKERFILES"
    
    for dockerfile in $(find . -name "Dockerfile" -type f 2>/dev/null); do
        log_info "Проверка: $dockerfile"
        
        # Проверить на проблемный синтаксис
        if grep -q "^RUN.*&&.*&&.*$" "$dockerfile"; then
            log_success "$(basename $(dirname $dockerfile)): Используется правильный синтаксис RUN"
        fi
        
        # Проверить на build dependencies в RUN
        if grep -q "RUN.*apk add" "$dockerfile" || grep -q "RUN.*apt-get install" "$dockerfile"; then
            log_success "$(basename $(dirname $dockerfile)): Обнаружена установка зависимостей"
        fi
        
        # Проверить на HEALTHCHECK
        if grep -q "HEALTHCHECK" "$dockerfile"; then
            log_success "$(basename $(dirname $dockerfile)): HEALTHCHECK найден в Dockerfile"
        else
            log_warning "$(basename $(dirname $dockerfile)): HEALTHCHECK отсутствует"
            ALL_ISSUES+=("DOCKERFILE_NO_HEALTHCHECK")
        fi
        
        # Проверить на построение без тега
        if grep -q "FROM.*:latest" "$dockerfile"; then
            log_warning "$(basename $(dirname $dockerfile)): Используется :latest тег (не рекомендуется)"
            ALL_ISSUES+=("DOCKERFILE_LATEST_TAG")
        fi
    done
}

# ============================================================================
# ПРОВЕРКА STDOUT CAPTURE
# ============================================================================

analyze_stdout_handling() {
    log_section "АНАЛИЗ ОБРАБОТКИ STDOUT"
    
    log_info "Проверка того как контейнеры пишут в stdout..."
    
    # Проверить docker-compose на следующую конфигурацию
    if grep -q "entrypoint:" docker-compose.yaml; then
        log_success "Найдена пользовательская entrypoint конфигурация"
    else
        log_warning "Нет явной entrypoint конфигурации"
        ALL_RECOMMENDATIONS+=("Рассмотреть добавление явной entrypoint конфигурации для логирования stdout")
    fi
    
    # Проверить использование docker-entrypoint.sh
    for entrypoint in $(find . -name "docker-entrypoint.sh" -type f 2>/dev/null); do
        log_info "Найден entrypoint: $(dirname $entrypoint)"
        
        if grep -q "set -e" "$entrypoint"; then
            log_success "$(dirname $entrypoint): Используется 'set -e' для обработки ошибок"
        fi
        
        if grep -q "exec " "$entrypoint"; then
            log_success "$(dirname $entrypoint): Используется 'exec' для передачи PID"
        fi
    done
}

# ============================================================================
# ПРОВЕРКА STDOUT CAPACITY
# ============================================================================

analyze_stdout_capacity() {
    log_section "АНАЛИЗ ПРОИЗВОДИТЕЛЬНОСТИ STDOUT"
    
    # Проверить размер логов
    for service in $(docker-compose config --services 2>/dev/null || echo ""); do
        local container_id=$(docker-compose ps -q "$service" 2>/dev/null || echo "")
        
        if [ ! -z "$container_id" ]; then
            # Получить размер логов
            local log_file=$(docker inspect --format='{{.LogPath}}' "$container_id" 2>/dev/null)
            
            if [ ! -z "$log_file" ] && [ -f "$log_file" ]; then
                local size=$(du -h "$log_file" 2>/dev/null | awk '{print $1}')
                log_info "$service: Log size = $size"
                
                # Если слишком большой
                if [ $(du -b "$log_file" 2>/dev/null | awk '{print $1}') -gt $((100*1024*1024)) ]; then
                    log_warning "$service: Логи очень большие (>100MB)"
                    ALL_ISSUES+=("LARGE_LOG_FILES_$service")
                fi
            fi
        fi
    done
}

# ============================================================================
# СГЕНЕРИРОВАТЬ MARKDOWN ОТЧЕТ
# ============================================================================

generate_markdown_report() {
    log_section "ГЕНЕРИРОВАНИЕ MARKDOWN ОТЧЕТА"
    
    mkdir -p "$REPORTS_DIR"
    
    cat > "$MASTER_REPORT" << 'EOF'
# 📊 MASTER ANALYSIS & ISSUE REPORT

**Дата анализа**: $(date)  
**Версия**: 2.0  

---

## 📋 ОГЛАВЛЕНИЕ

1. [Резюме проблем](#резюме)
2. [Критические проблемы](#критические)
3. [Рекомендации по исправлению](#рекомендации)
4. [План действий](#план)
5. [Метрики и статистика](#метрики)

---

## 🔴 Резюме проблем {#резюме}

| Проблема | Статус | Приоритет |
|----------|--------|-----------|

EOF
    
    # Добавить обнаруженные проблемы
    for issue in "${ALL_ISSUES[@]}"; do
        cat >> "$MASTER_REPORT" << EOF
| $issue | ⚠️  | HIGH |
EOF
    done
    
    cat >> "$MASTER_REPORT" << 'EOF'

---

## 🔥 Критические проблемы {#критические}

EOF
    
    # Добавить рекомендации
    local i=1
    for recommendation in "${ALL_RECOMMENDATIONS[@]}"; do
        cat >> "$MASTER_REPORT" << EOF

### Проблема #$i
\`\`\`
$recommendation
\`\`\`

EOF
        ((i++))
    done
    
    cat >> "$MASTER_REPORT" << 'EOF'

---

## ✅ Рекомендации по исправлению {#рекомендации}

### 1. Логирование stdout

**Текущее состояние**: stdout может быть потерян при сбое контейнера

**Решение**:

```yaml
services:
  my-service:
    logging:
      driver: json-file
      options:
        max-size: '10m'
        max-file: '5'
        labels: 'service=my-service'
```

**Результат**: Все выходы stdout будут сохранены в json-файлах с ротацией

---

### 2. Healthcheck конфигурация

**Текущее состояние**: Отсутствуют проверки здоровья контейнеров

**Решение**: Добавить HEALTHCHECK для каждого критического сервиса

```yaml
services:
  server:
    healthcheck:
      test: ["CMD", "/usr/sbin/zabbix_server", "-V"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

---

### 3. Сбор логов

**Использовать скрипт для полного анализа**:

```bash
./scripts/container-logging-framework.sh
```

Это соберет:
- Логи всех контейнеров
- Использование ресурсов
- Ошибки и предупреждения
- Детальный отчет

---

### 4. Тестирование

**Использовать comprehensive test framework**:

```bash
./scripts/comprehensive-test-framework.sh
```

Проверит:
- ShellCheck статический анализ
- YAML валидация
- BATS тесты
- Pytest тесты
- JSON валидация

---

## 📋 План действий {#план}

### Фаза 1: Подготовка (5-10 минут)

- [ ] Убедиться что docker-compose валиден: `docker-compose config`
- [ ] Запустить контейнеры: `docker-compose up -d`
- [ ] Дать контейнерам время на инициализацию

### Фаза 2: Сбор данных (10-15 минут)

- [ ] Запустить анализ логирования: `./scripts/container-logging-framework.sh`
- [ ] Собрать метрики: `docker stats --no-stream`
- [ ] Проверить healthcheck: `docker-compose ps`

### Фаза 3: Анализ (15-20 минут)

- [ ] Запустить тесты: `./scripts/comprehensive-test-framework.sh`
- [ ] Проверить результаты в `test-results/`
- [ ] Проверить логи в `container-logs/`

### Фаза 4: Исправление

Для каждой найденной проблемы:

1. Обновить docker-compose.yaml
2. Обновить Dockerfiles
3. Пересобрать: `docker-compose build --no-cache`
4. Перезапустить: `docker-compose up -d`
5. Проверить: `docker-compose ps`

### Фаза 5: Валидация

- [ ] Запустить весь анализ заново
- [ ] Убедиться что все проблемы решены
- [ ] Запустить тесты еще раз

---

## 📊 Метрики и статистика {#метрики}

### Определение проблем

| Количество | Описание |
|-----------|---------|
| ${#ALL_ISSUES[@]} | Критических проблем найдено |
| ${#ALL_RECOMMENDATIONS[@]} | Рекомендаций выдано |

### Рекомендуемые метрики для мониторинга

- **Memory Usage**: docker stats --format "{{.MemPerc}}"
- **CPU Usage**: docker stats --format "{{.CPUPerc}}"
- **Log Size**: du -h /var/lib/docker/containers/*/
- **Health Status**: docker-compose ps

EOF

    log_success "Markdown отчет создан: $(basename $MASTER_REPORT)"
}

# ============================================================================
# СГЕНЕРИРОВАТЬ JSON ОТЧЕТ
# ============================================================================

generate_json_report() {
    log_section "ГЕНЕРИРОВАНИЕ JSON ОТЧЕТА"
    
    {
        echo "{"
        echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
        echo "  \"version\": \"2.0\","
        echo "  \"issues_found\": ${#ALL_ISSUES[@]},"
        echo "  \"issues\": ["
        
        for i in "${!ALL_ISSUES[@]}"; do
            echo "    {"
            echo "      \"id\": \"${ALL_ISSUES[$i]}\","
            echo "      \"type\": \"configuration_issue\","
            echo "      \"severity\": \"high\""
            echo "    }$([ $((i + 1)) -lt ${#ALL_ISSUES[@]} ] && echo ',' || echo '')"
        done
        
        echo "  ],"
        echo "  \"recommendations\": ${#ALL_RECOMMENDATIONS[@]},"
        echo "  \"analysis_tools_used\": ["
        echo "    \"container-logging-framework\","
        echo "    \"dockerfile-analyzer\","
        echo "    \"stdout-capture\","
        echo "    \"healthcheck-validator\""
        echo "  ]"
        echo "}"
    } > "$JSON_REPORT"
    
    log_success "JSON отчет создан: $(basename $JSON_REPORT)"
}

# ============================================================================
# ВЫПОЛНИТЬ ВСЕ АНАЛИЗЫ
# ============================================================================

run_all_analysis() {
    analyze_logging
    analyze_healthchecks
    analyze_build_errors
    analyze_dockerfiles
    analyze_stdout_handling
    analyze_stdout_capacity
    generate_markdown_report
    generate_json_report
}

# ============================================================================
# ИСПРАВИТЬ РАСПРОСТРАНЕННЫЕ ПРОБЛЕМЫ
# ============================================================================

auto_repair() {
    log_section "АВТОМАТИЧЕСКОЕ ИСПРАВЛЕНИЕ ПРОБЛЕМ"
    
    log_warning "Функция auto-repair находится в разработке"
    log_info "Рекомендуемые шаги для исправления:"
    echo ""
    echo "1. Добавить logging конфигурацию в docker-compose.yaml"
    echo "2. Добавить healthcheck для каждого сервиса"
    echo "3. Убедиться что все Dockerfiles содержат HEALTHCHECK"
    echo "4. Перестроить контейнеры: docker-compose build --no-cache"
    echo "5. Перезапустить: docker-compose down && docker-compose up -d"
    echo "6. Проверить: ./scripts/master-analysis.sh check"
}

# ============================================================================
# БЫСТРАЯ ПРОВЕРКА
# ============================================================================

quick_check() {
    log_section "БЫСТРАЯ ПРОВЕРКА СТАТУСА"
    
    log_info "Проверка Docker..."
    docker version | head -2
    
    log_info "Проверка Docker Compose..."
    docker-compose version
    
    log_info "Проверка конфигурации..."
    if docker-compose config &>/dev/null; then
        log_success "docker-compose.yaml: OK"
    else
        log_error "docker-compose.yaml: ОШИБКА"
    fi
    
    log_info "Проверка контейнеров..."
    docker-compose ps
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local action="${1:-all}"
    
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║         MASTER ANALYSIS & REPORTING SYSTEM v2.0            ║"
    echo "║                                                            ║"
    echo "║  Объединенный анализ логирования и тестирования           ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    mkdir -p "$REPORTS_DIR"
    cd "$WORKSPACE" || exit 1
    
    case "$action" in
        all)
            run_all_analysis
            ;;
        logs)
            analyze_logging
            analyze_stdout_handling
            analyze_stdout_capacity
            ;;
        tests)
            bash "$SCRIPT_DIR/comprehensive-test-framework.sh"
            ;;
        check)
            quick_check
            run_all_analysis
            ;;
        repair)
            auto_repair
            ;;
        *)
            echo "Использование: $0 [all|logs|tests|check|repair]"
            exit 1
            ;;
    esac
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                    АНАЛИЗ ЗАВЕРШЕН                         ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "📁 Отчеты:"
    echo "   JSON: $(basename $JSON_REPORT)"
    echo "   Markdown: $(basename $MASTER_REPORT)"
    echo ""
}

main "$@"
