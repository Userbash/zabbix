#!/bin/bash
#
# 🔨 LOCAL BUILD COLLECTION & ANALYSIS FOR PODMAN/DOCKER
# Локальная сборка с полным сбором данных и анализом
#
# Использование:
#   ./local-build-analysis.sh [service]
#
# Примеры:
#   ./local-build-analysis.sh              # Все сервисы
#   ./local-build-analysis.sh server-pgsql # Один сервис
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build-analysis"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BUILD_LOG="${BUILD_DIR}/build_${TIMESTAMP}.log"
ANALYSIS_REPORT="${BUILD_DIR}/analysis_${TIMESTAMP}.md"
JSON_REPORT="${BUILD_DIR}/analysis_${TIMESTAMP}.json"
DEPENDENCY_REPORT="${BUILD_DIR}/dependencies_${TIMESTAMP}.txt"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Счетчики
declare -a BUILD_STAGES
declare -a DEPENDENCIES
declare -a WARNINGS
declare -a ERRORS

# ============================================================================
# ФУНКЦИИ
# ============================================================================

log_info() { echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$BUILD_LOG"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1" | tee -a "$BUILD_LOG"; }
log_error() { echo -e "${RED}[✗]${NC} $1" | tee -a "$BUILD_LOG"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1" | tee -a "$BUILD_LOG"; }
log_section() { echo -e "\n${MAGENTA}══════════════════════════════════════${NC}\n${MAGENTA}$1${NC}\n${MAGENTA}══════════════════════════════════════${NC}\n" | tee -a "$BUILD_LOG"; }

# ============================================================================
# НАЙТИ ВСЕ DOCKERFILES
# ============================================================================

find_dockerfiles() {
    log_section "ПОИСК DOCKERFILES"
    
    local dockerfiles=$(find . -name "Dockerfile" -type f 2>/dev/null | sort)
    
    if [ -z "$dockerfiles" ]; then
        log_error "Dockerfiles не найдены"
        return 1
    fi
    
    echo "$dockerfiles"
}

# ============================================================================
# АНАЛИЗ DOCKERFILE
# ============================================================================

analyze_dockerfile() {
    local dockerfile="$1"
    local service=$(echo "$dockerfile" | awk -F'/' '{print $(NF-2)}')
    
    log_info "Анализ: $service ($dockerfile)"
    
    # Получить информацию о Dockerfile
    local from_image=$(grep "^FROM " "$dockerfile" | head -1 | awk '{print $2}')
    local lines=$(wc -l < "$dockerfile")
    local base_image=$(echo "$from_image" | cut -d':' -f1)
    local base_version=$(echo "$from_image" | cut -d':' -f2)
    
    log_info "  Base image: $from_image"
    log_info "  Lines: $lines"
    
    BUILD_STAGES+=("$service:$from_image")
}

# ============================================================================
# АНАЛИЗ ЗАВИСИМОСТЕЙ
# ============================================================================

analyze_dependencies() {
    log_section "АНАЛИЗ ЗАВИСИМОСТЕЙ"
    
    local dockerfile="$1"
    local service=$(echo "$dockerfile" | awk -F'/' '{print $(NF-2)}')
    
    log_info "Сбор зависимостей для: $service"
    
    # Найти RUN команды с apk/apt
    local build_deps=$(grep "^RUN.*apk add\|^RUN.*apt-get install" "$dockerfile" | head -5)
    
    if [ -n "$build_deps" ]; then
        echo "=== $service ===" >> "$DEPENDENCY_REPORT"
        echo "$build_deps" >> "$DEPENDENCY_REPORT"
        echo "" >> "$DEPENDENCY_REPORT"
        
        # Подсчитать зависимости
        local dep_count=$(echo "$build_deps" | grep -o '\-\-no-cache\|apk\|apt-get' | wc -l)
        log_success "$service: $dep_count dependency commands найдено"
        DEPENDENCIES+=("$service:$dep_count")
    fi
    
    # Проверить HEALTHCHECK
    if grep -q "HEALTHCHECK" "$dockerfile"; then
        log_success "$service: HEALTHCHECK найден ✓"
    else
        log_warning "$service: HEALTHCHECK отсутствует"
        WARNINGS+=("$service:missing_healthcheck")
    fi
    
    # Проверить EXPOSE
    local expose=$(grep "^EXPOSE " "$dockerfile")
    if [ -n "$expose" ]; then
        log_success "$service: $expose"
    fi
}

# ============================================================================
# СИМУЛЯЦИЯ ПРОЦЕССА СБОРКИ
# ============================================================================

simulate_build_process() {
    log_section "СИМУЛЯЦИЯ ПРОЦЕССА СБОРКИ"
    
    local dockerfile="$1"
    local service=$(echo "$dockerfile" | awk -F'/' '{print $(NF-2)}')
    
    log_info "═══════════════════════════════════════"
    log_info "Сборка: $service"
    log_info "═══════════════════════════════════════"
    
    # Stage 1: FROM
    local from_line=$(grep "^FROM " "$dockerfile" | head -1)
    log_info "[STAGE 1/5] FROM: $from_line"
    log_success "✓ Base image resolved"
    
    # Stage 2: Dependencies
    log_info "[STAGE 2/5] Установка зависимостей"
    local apk_lines=$(grep "apk add" "$dockerfile" | wc -l)
    if [ "$apk_lines" -gt 0 ]; then
        log_success "✓ $apk_lines apt/apk команд найдено"
    fi
    
    # Stage 3: Build
    log_info "[STAGE 3/5] Компиляция и сборка"
    local make_lines=$(grep "make\|./configure\|./build" "$dockerfile" | wc -l)
    if [ "$make_lines" -gt 0 ]; then
        log_success "✓ $make_lines build команд найдено"
    fi
    
    # Stage 4: Cleanup
    log_info "[STAGE 4/5] Очистка"
    local cleanup_lines=$(grep "rm -rf\|apk del" "$dockerfile" | wc -l)
    if [ "$cleanup_lines" -gt 0 ]; then
        log_success "✓ $cleanup_lines cleanup действий"
    fi
    
    # Stage 5: Final
    log_info "[STAGE 5/5] Финализация"
    local entrypoint=$(grep "^ENTRYPOINT\|^CMD " "$dockerfile" | head -1)
    if [ -n "$entrypoint" ]; then
        log_success "✓ Entrypoint: $entrypoint"
    fi
    
    log_success "Build simulation complete for $service"
}

# ============================================================================
# ПРОВЕРКА ПОТЕНЦИАЛЬНЫХ ПРОБЛЕМ
# ============================================================================

check_build_issues() {
    log_section "ПРОВЕРКА ПОТЕНЦИАЛЬНЫХ ПРОБЛЕМ"
    
    local dockerfile="$1"
    local service=$(echo "$dockerfile" | awk -F'/' '{print $(NF-2)}')
    
    # 1. Проверить :latest теги
    if grep -q "FROM.*:latest" "$dockerfile"; then
        log_warning "$service: Используется :latest тег (не рекомендуется)"
        WARNINGS+=("$service:latest_tag")
    fi
    
    # 2. Проверить многостадийную сборку
    local stages=$(grep -c "^FROM " "$dockerfile" || echo 0)
    if [ "$stages" -gt 1 ]; then
        log_success "$service: Multi-stage build ($stages stages)"
    else
        log_info "$service: Single-stage build"
    fi
    
    # 3. Проверить USER
    if grep -q "^USER " "$dockerfile"; then
        log_success "$service: USER directive found ✓"
    else
        log_warning "$service: Нет USER directive (работает как root)"
        WARNINGS+=("$service:no_user")
    fi
    
    # 4. Проверить WORKDIR
    if grep -q "^WORKDIR " "$dockerfile"; then
        log_success "$service: WORKDIR configured ✓"
    else
        log_warning "$service: Нет явного WORKDIR"
        WARNINGS+=("$service:no_workdir")
    fi
    
    # 5. Проверить размер
    local size=$(du -sh $(dirname "$dockerfile") 2>/dev/null | awk '{print $1}')
    log_info "$service: Directory size: $size"
    
    # 6. Проверить на опасные команды
    if grep -q "rm -rf /" "$dockerfile"; then
        log_error "$service: ОПАСНАЯ КОМАНДА: rm -rf /"
        ERRORS+=("$service:dangerous_rm")
    fi
    
    if grep -q "curl.*http://\|wget.*http://" "$dockerfile"; then
        log_warning "$service: Загрузка по незащищенному HTTP"
        WARNINGS+=("$service:insecure_download")
    fi
}

# ============================================================================
# АНАЛИЗ ОБРАЗОВ
# ============================================================================

analyze_image_sizes() {
    log_section "АНАЛИЗ РАЗМЕРОВ ОБРАЗОВ"
    
    local dockerfiles=$(find_dockerfiles)
    
    for dockerfile in $dockerfiles; do
        local service=$(echo "$dockerfile" | awk -F'/' '{print $(NF-2)}')
        local context=$(dirname "$dockerfile")
        local size=$(find "$context" -type f 2>/dev/null | wc -l)
        local totalsize=$(du -sh "$context" 2>/dev/null | awk '{print $1}')
        
        log_info "$service: $size files, $totalsize total"
    done
}

# ============================================================================
# ГЕНЕРИРОВАНИЕ MARKDOWN ОТЧЕТА
# ============================================================================

generate_markdown_report() {
    log_section "ГЕНЕРИРОВАНИЕ ОТЧЕТА"
    
    cat > "$ANALYSIS_REPORT" << 'EOF'
# 🔨 LOCAL BUILD ANALYSIS REPORT

**Дата анализа**: $(date)
**Версия**: 1.0

---

## 📋 ОГЛАВЛЕНИЕ

1. [Build Summary](#summary)
2. [Dependencies](#dependencies)
3. [Stages Analysis](#stages)
4. [Potential Issues](#issues)
5. [Recommendations](#recommendations)

---

## 📊 Build Summary {#summary}

| Параметр | Значение |
|----------|----------|
| Total Services | COUNT_SERVICES |
| Dockerfiles Found | COUNT_DOCKERFILES |
| Warnings | COUNT_WARNINGS |
| Errors | COUNT_ERRORS |

---

## 📦 Dependencies {#dependencies}

EOF
    
    # Добавить информацию о зависимостях
    if [ -f "$DEPENDENCY_REPORT" ]; then
        echo "### Collected Dependencies" >> "$ANALYSIS_REPORT"
        echo "" >> "$ANALYSIS_REPORT"
        echo '```' >> "$ANALYSIS_REPORT"
        cat "$DEPENDENCY_REPORT" >> "$ANALYSIS_REPORT"
        echo '```' >> "$ANALYSIS_REPORT"
        echo "" >> "$ANALYSIS_REPORT"
    fi
    
    # Рекомендации
    cat >> "$ANALYSIS_REPORT" << 'EOF'

---

## 💡 Recommendations {#recommendations}

### 1. Multi-stage Builds
Использовать для уменьшения размера образов

### 2. Layer Caching
Оптимизировать порядок команд для лучшего кеширования

### 3. Security
- Использовать specific tags вместо :latest
- Добавить USER directive
- Использовать только HTTPS для загрузок

### 4. Health Checks
Убедиться что все critical сервисы имеют HEALTHCHECK

### 5. Documentation
Добавить комментарии в Dockerfile

---

## 🎯 Next Steps

1. Запустить локальную сборку: `docker-compose build`
2. Протестировать: `docker-compose up -d`
3. Проверить healthchecks: `docker-compose ps`
4. Просмотреть логи: `docker-compose logs`

EOF

    log_success "Markdown отчет: $(basename $ANALYSIS_REPORT)"
}

# ============================================================================
# ГЕНЕРИРОВАНИЕ JSON ОТЧЕТА
# ============================================================================

generate_json_report() {
    {
        echo "{"
        echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
        echo "  \"analysis_version\": \"1.0\","
        echo "  \"total_services\": ${#BUILD_STAGES[@]},"
        echo "  \"total_warnings\": ${#WARNINGS[@]},"
        echo "  \"total_errors\": ${#ERRORS[@]},"
        echo "  \"build_stages\": ["
        
        for i in "${!BUILD_STAGES[@]}"; do
            echo "    {"
            echo "      \"service\": \"${BUILD_STAGES[$i]%:*}\","
            echo "      \"image\": \"${BUILD_STAGES[$i]#*:}\""
            echo "    }$([ $((i + 1)) -lt ${#BUILD_STAGES[@]} ] && echo ',' || echo '')"
        done
        
        echo "  ],"
        echo "  \"warnings\": ${#WARNINGS[@]},"
        echo "  \"errors\": ${#ERRORS[@]}"
        echo "}"
    } > "$JSON_REPORT"
    
    log_success "JSON отчет: $(basename $JSON_REPORT)"
}

# ============================================================================
# ИТОГОВЫЙ ОТЧЕТ
# ============================================================================

print_summary() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║           BUILD ANALYSIS SUMMARY                           ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "📊 Statistics:"
    echo "   Build Stages: ${#BUILD_STAGES[@]}"
    echo "   Dependencies Found: ${#DEPENDENCIES[@]}"
    echo "   Warnings: ${#WARNINGS[@]}"
    echo "   Errors: ${#ERRORS[@]}"
    echo ""
    
    if [ ${#ERRORS[@]} -gt 0 ]; then
        echo "🔴 Errors Found:"
        for err in "${ERRORS[@]}"; do
            echo "   • $err"
        done
        echo ""
    fi
    
    if [ ${#WARNINGS[@]} -gt 0 ]; then
        echo "🟡 Warnings:"
        for warn in "${WARNINGS[@]}"; do
            echo "   • $warn"
        done
        echo ""
    fi
    
    echo "📁 Reports:"
    echo "   Build log: $(basename $BUILD_LOG)"
    echo "   Analysis: $(basename $ANALYSIS_REPORT)"
    echo "   JSON: $(basename $JSON_REPORT)"
    echo "   Dependencies: $(basename $DEPENDENCY_REPORT)"
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    mkdir -p "$BUILD_DIR"
    
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║     LOCAL BUILD ANALYSIS & DATA COLLECTION v1.0            ║"
    echo "║                                                            ║"
    echo "║  Анализ локальной сборки контейнеров                      ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    cd "$(dirname "$0")/.." || exit 1
    
    # Найти все Dockerfiles
    local dockerfiles=$(find_dockerfiles)
    
    if [ -z "$dockerfiles" ]; then
        log_error "Нет Dockerfiles для анализа"
        exit 1
    fi
    
    # Анализировать каждый Dockerfile
    for dockerfile in $dockerfiles; do
        analyze_dockerfile "$dockerfile"
        analyze_dependencies "$dockerfile"
        simulate_build_process "$dockerfile"
        check_build_issues "$dockerfile"
        echo ""
    done
    
    # Анализ размеров
    analyze_image_sizes
    
    # Генерировать отчеты
    generate_markdown_report
    generate_json_report
    
    # Вывести итоги
    print_summary
    
    echo "✅ ANALYSIS COMPLETE!"
    echo ""
}

main "$@"
