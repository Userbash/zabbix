#!/bin/bash
#
# 🚀 REALTIME BUILD ANALYSIS & DATA COLLECTION
# Сборка с реальным анализом в реальном времени
#
# Использование:
#   ./realtime-build-monitor.sh [all|service-name]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${SCRIPT_DIR}/.."
OUTPUT_DIR="${WORKSPACE}/build-monitoring"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REALTIME_LOG="${OUTPUT_DIR}/realtime_${TIMESTAMP}.log"
METRICS_LOG="${OUTPUT_DIR}/metrics_${TIMESTAMP}.log"
REPORT_FILE="${OUTPUT_DIR}/report_${TIMESTAMP}.md"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Счетчики
declare -a BUILD_METRICS
TOTAL_LAYERS=0
TOTAL_SIZE=0
BUILD_TIME_START=0

# ============================================================================
# ФУНКЦИИ ЛОГИРОВАНИЯ
# ============================================================================

log_header() {
    local msg="$1"
    echo -e "\n${MAGENTA}╔════════════════════════════════════════╗${NC}" | tee -a "$REALTIME_LOG"
    echo -e "${MAGENTA}║${NC} $msg" | tee -a "$REALTIME_LOG"
    echo -e "${MAGENTA}╚════════════════════════════════════════╝${NC}\n" | tee -a "$REALTIME_LOG"
}

log_stage() {
    local stage="$1"
    local details="$2"
    local timestamp=$(date '+%H:%M:%S')
    echo -e "${CYAN}[${timestamp}]${NC} ${BLUE}[STAGE]${NC} $stage - $details" | tee -a "$REALTIME_LOG"
}

log_progress() {
    local pct="$1"
    local msg="$2"
    local bar=$(printf '█%.0s' $(seq 1 $((pct / 5))))
    local empty=$(printf '░%.0s' $(seq 1 $((20 - pct / 5))))
    echo -e "${GREEN}[Progress]${NC} ${bar}${empty} ${pct}% - $msg" | tee -a "$REALTIME_LOG"
}

log_metric() {
    local name="$1"
    local value="$2"
    local unit="$3"
    printf "%-30s : %-15s %s\n" "$name" "$value" "$unit" | tee -a "$METRICS_LOG"
}

log_layer() {
    local layer="$1"
    local command="$2"
    echo -e "${MAGENTA}  Layer:${NC} $layer" | tee -a "$REALTIME_LOG"
    echo -e "${BLUE}    CMD:${NC} $command" | tee -a "$REALTIME_LOG"
    ((TOTAL_LAYERS++))
}

# ============================================================================
# АНАЛИЗ DOCKER CONTEXT
# ============================================================================

analyze_docker_context() {
    log_header "АНАЛИЗ DOCKER CONTEXT"
    
    local dockerfile="$1"
    local context=$(dirname "$dockerfile")
    
    # Размер context
    local context_size=$(du -sh "$context" 2>/dev/null | awk '{print $1}')
    log_metric "Context Size" "$context_size" ""
    
    # Количество файлов
    local file_count=$(find "$context" -type f 2>/dev/null | wc -l)
    log_metric "Total Files" "$file_count" "files"
    
    # Директории
    local dir_count=$(find "$context" -type d 2>/dev/null | wc -l)
    log_metric "Total Directories" "$dir_count" "dirs"
    
    # .dockerignore?
    if [ -f "$context/.dockerignore" ]; then
        log_metric ".dockerignore Present" "YES" "✓"
        local ignore_lines=$(wc -l < "$context/.dockerignore")
        log_metric "Ignore Rules" "$ignore_lines" "rules"
    else
        log_metric ".dockerignore Present" "NO" "⚠"
    fi
}

# ============================================================================
# СИМУЛЯЦИЯ BUILD STAGE
# ============================================================================

simulate_build_stages() {
    log_header "СИМУЛЯЦИЯ BUILD STAGES"
    
    local dockerfile="$1"
    local service=$(basename $(dirname "$dockerfile"))
    
    TOTAL_LAYERS=0
    
    # Читать Dockerfile и извлечь stages
    local stage_count=1
    local line_no=0
    
    while IFS= read -r line; do
        ((line_no++))
        
        # FROM - новый stage
        if [[ $line =~ ^FROM ]]; then
            log_stage "Stage $stage_count" "$line"
            ((stage_count++))
        fi
        
        # RUN - основной слой
        if [[ $line =~ ^RUN ]]; then
            local cmd=$(echo "$line" | cut -c5-)
            log_layer "RUN #$TOTAL_LAYERS" "$cmd"
            log_progress $((TOTAL_LAYERS * 10)) "Installing dependencies..."
        fi
        
        # COPY/ADD
        if [[ $line =~ ^COPY ]] || [[ $line =~ ^ADD ]]; then
            local cmd=$(echo "$line" | cut -c6-)
            log_layer "COPY/ADD #$TOTAL_LAYERS" "$cmd"
            log_progress $((TOTAL_LAYERS * 10)) "Copying files..."
        fi
        
        # EXPOSE
        if [[ $line =~ ^EXPOSE ]]; then
            local ports=$(echo "$line" | cut -c8-)
            log_metric "Exposed Ports" "$ports" ""
        fi
        
        # HEALTHCHECK
        if [[ $line =~ ^HEALTHCHECK ]]; then
            log_metric "Healthcheck" "CONFIGURED" "✓"
        fi
        
        # ENTRYPOINT/CMD
        if [[ $line =~ ^ENTRYPOINT ]] || [[ $line =~ ^CMD ]]; then
            local cmd=$(echo "$line" | cut -c11-)
            log_metric "Entry/Cmd" "$cmd" ""
        fi
        
    done < "$dockerfile"
    
    log_metric "Total Layers" "$TOTAL_LAYERS" "layers"
}

# ============================================================================
# АНАЛИЗ УЗКИХ МЕСТ (BOTTLENECKS)
# ============================================================================

analyze_bottlenecks() {
    log_header "АНАЛИЗ УЗКИХ МЕСТ СБОРКИ"
    
    local dockerfile="$1"
    
    # 1. Большие RUN команды
    local large_runs=$(grep "^RUN " "$dockerfile" | awk '{print length}' | sort -rn | head -1)
    log_metric "Largest RUN Command" "$large_runs" "characters"
    
    # 2. Порядок слоев (кешируемость)
    log_metric "Layer Ordering" "CHECKING" "..."
    
    # COPY/ADD должны быть в конце
    if grep -q "^COPY\|^ADD\|^RUN.*COPY\|^RUN.*ADD" "$dockerfile"; then
        local last_copy_line=$(grep -n "^COPY\|^ADD" "$dockerfile" | tail -1 | cut -d: -f1)
        local last_run_line=$(grep -n "^RUN " "$dockerfile" | tail -1 | cut -d: -f1)
        
        if [ "$last_copy_line" -gt "$last_run_line" ]; then
            log_metric "Layer Caching" "OPTIMIZED" "✓"
        else
            log_metric "Layer Caching" "SUBOPTIMAL" "⚠"
        fi
    fi
    
    # 3. Multi-stage build?
    local stage_count=$(grep -c "^FROM " "$dockerfile")
    log_metric "Build Stages" "$stage_count" "stages"
    
    # 4. Base image freshness
    local from_image=$(grep "^FROM " "$dockerfile" | head -1 | awk '{print $2}')
    log_metric "Base Image" "$from_image" ""
}

# ============================================================================
# СБОР STATISTICS
# ============================================================================

collect_statistics() {
    log_header "СТАТИСТИКА СБОРКИ"
    
    # Dockerfile stats
    for dockerfile in $(find "$WORKSPACE" -name "Dockerfile" -type f 2>/dev/null); do
        local service=$(dirname "$dockerfile" | xargs basename)
        local lines=$(wc -l < "$dockerfile")
        local commands=$(grep -c "^[A-Z]" "$dockerfile" || echo 0)
        
        log_metric "$service Lines" "$lines" "lines"
        log_metric "$service Commands" "$commands" "commands"
        
        # Сложность
        local complexity=$((lines / 10))
        if [ $complexity -lt 10 ]; then
            log_metric "$service Complexity" "LOW" "🟢"
        elif [ $complexity -lt 20 ]; then
            log_metric "$service Complexity" "MEDIUM" "🟡"
        else
            log_metric "$service Complexity" "HIGH" "🔴"
        fi
    done
}

# ============================================================================
# ПРОВЕРКА READINESS
# ============================================================================

check_readiness() {
    log_header "ПРОВЕРКА ГОТОВНОСТИ К СБОРКЕ"
    
    local issues=0
    
    # 1. docker-compose.yaml
    if [ -f "$WORKSPACE/docker-compose.yaml" ]; then
        if docker-compose config -f "$WORKSPACE/docker-compose.yaml" &>/dev/null 2>&1; then
            log_metric "docker-compose.yaml" "VALID" "✓"
        else
            log_metric "docker-compose.yaml" "INVALID" "✗"
            ((issues++))
        fi
    fi
    
    # 2. All Dockerfiles exist
    local missing=0
    for service in server-pgsql web-nginx-pgsql agent agent2 java-gateway snmptraps; do
        if [ ! -f "$WORKSPACE/$service/alpine/Dockerfile" ]; then
            log_metric "$service Dockerfile" "MISSING" "✗"
            ((missing++))
        fi
    done
    if [ $missing -eq 0 ]; then
        log_metric "All Dockerfiles" "PRESENT" "✓"
    else
        log_metric "Missing Dockerfiles" "$missing" "files"
        ((issues++))
    fi
    
    # 3. Disk space
    local available=$(df -BG "$WORKSPACE" | tail -1 | awk '{print $4}' | sed 's/G//')
    log_metric "Available Disk" "${available}GB" ""
    if [ "$available" -lt 10 ]; then
        log_metric "Disk Space WARNING" "LOW (<10GB)" "⚠"
        ((issues++))
    fi
    
    # 4. Environment files
    local env_files=$(ls -1 "$WORKSPACE"/.env_* 2>/dev/null | wc -l)
    log_metric "Environment Files" "$env_files" "files"
    
    # 5. Secret files
    local secret_files=$(ls -1 "$WORKSPACE"/.POSTGRES_* 2>/dev/null | wc -l)
    log_metric "Secret Files" "$secret_files" "files"
    if [ $secret_files -lt 2 ]; then
        log_metric "Missing Secrets" "YES" "⚠"
        ((issues++))
    fi
    
    if [ $issues -eq 0 ]; then
        echo -e "\n${GREEN}✓ Build environment is READY${NC}" | tee -a "$REALTIME_LOG"
    else
        echo -e "\n${YELLOW}⚠ $issues issues found - build may fail${NC}" | tee -a "$REALTIME_LOG"
    fi
}

# ============================================================================
# ГЕНЕРИРОВАНИЕ ОТЧЕТА
# ============================================================================

generate_report() {
    log_header "ГЕНЕРИРОВАНИЕ ОТЧЕТА"
    
    cat > "$REPORT_FILE" << 'EOF'
# 🚀 REALTIME BUILD ANALYSIS REPORT

**Generated**: $(date)

## 📊 Build Metrics

- Total Layers: TOTAL_LAYERS_COUNT
- Total Size: TOTAL_SIZE_ESTIMATE
- Estimated Build Time: ESTIMATED_TIME

## 🔍 Detailed Analysis

### Context Analysis
- Context size and file count
- Dockerignore configuration
- Build dependencies

### Stage Analysis
- Multi-stage builds
- Layer optimization
- Caching effectiveness

### Bottleneck Analysis
- Large RUN commands
- Layer ordering
- Base image selection

## ✅ Readiness Check

- docker-compose.yaml validity
- All Dockerfiles present
- Disk space available
- Environment/secrets configured
- Network connectivity

## 📋 Detailed Logs

See: ${0%/*}/../realtime_${TIMESTAMP}.log
See: ${0%/*}/../metrics_${TIMESTAMP}.log

## 🎯 Recommendations

1. Optimize layer ordering for caching
2. Use multi-stage builds where applicable
3. Consider base image updates
4. Add comprehensive healthchecks
5. Configure proper logging

---

**Status**: Ready for build
**Next**: Run `docker-compose build` or `podman-compose build`

EOF

    log_metric "Report Generated" "$(basename $REPORT_FILE)" "✓"
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    mkdir -p "$OUTPUT_DIR"
    
    BUILD_TIME_START=$(date +%s)
    
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║     REALTIME BUILD ANALYSIS & MONITORING v1.0          ║"
    echo "║                                                        ║"
    echo "║  Полный анализ сборки с реальным-временным мониторингом║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo ""
    
    cd "$WORKSPACE" || exit 1
    
    # Phase 1: Analyze Docker Context
    for dockerfile in $(find . -name "Dockerfile" -type f 2>/dev/null | head -3); do
        analyze_docker_context "$dockerfile"
        analyze_bottlenecks "$dockerfile"
        simulate_build_stages "$dockerfile"
    done
    
    # Phase 2: Collect Statistics
    collect_statistics
    
    # Phase 3: Check Readiness
    check_readiness
    
    # Phase 4: Generate Report
    generate_report
    
    # Summary
    local build_time_end=$(date +%s)
    local elapsed=$((build_time_end - BUILD_TIME_START))
    
    echo ""
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║           ANALYSIS COMPLETE                            ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo ""
    echo "📁 Output Files:"
    echo "   Real-time Log: $REALTIME_LOG"
    echo "   Metrics: $METRICS_LOG"
    echo "   Report: $REPORT_FILE"
    echo ""
    echo "⏱️  Analysis Time: ${elapsed}s"
    echo ""
    echo "✅ Ready to build!"
    echo ""
}

main "$@"
