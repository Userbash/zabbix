#!/bin/bash
#
# Log Analysis Script
# Анализирует логи сборки в реальном времени
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_LOG_DIR="${PROJECT_ROOT}/build-logs"
ANALYSIS_REPORT="${PROJECT_ROOT}/BUILD_ANALYSIS_DETAILED.md"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

################################################################################
# Функция анализа одного лога
################################################################################

analyze_log() {
    local logfile="$1"
    local service=$(basename "$logfile" | sed "s/_build_.*//")
    
    [ ! -f "$logfile" ] && return
    
    echo ""
    echo "════════════════════════════════════════════════════════"
    echo "Анализ: $service"
    echo "════════════════════════════════════════════════════════"
    
    # Размер и статистика
    local lines=$(wc -l < "$logfile")
    local size=$(du -h "$logfile" | cut -f1)
    echo "📊 Размер: $size | Строк: $lines"
    
    # Проверка на ошибки
    echo ""
    echo "🔴 ОШИБКИ:"
    if grep -qi "error\|failed\|invalid\|cannot\|not found" "$logfile" 2>/dev/null; then
        grep -i "error\|failed\|invalid\|cannot\|not found" "$logfile" | head -5 | sed 's/^/  /'
    else
        echo "  Ошибки не найдены ✓"
    fi
    
    # Предупреждения
    echo ""
    echo "🟡 ПРЕДУПРЕЖДЕНИЯ:"
    if grep -qi "warning\|deprecated\|obsolete" "$logfile" 2>/dev/null; then
        grep -i "warning\|deprecated\|obsolete" "$logfile" | head -3 | sed 's/^/  /'
    else
        echo "  Предупреждения не найдены ✓"
    fi
    
    # Время компиляции
    echo ""
    echo "⏱️  ВРЕМЯ КОМПИЛЯЦИИ:"
    if grep -q "make\|configure\|bootstrap" "$logfile" 2>/dev/null; then
        echo "  Найдены шаги компиляции"
    fi
    
    # Установленные пакеты
    echo ""
    echo "📦 УСТАНОВЛЕННЫЕ ПАКЕТЫ:"
    if grep -q "Installing\|OK:" "$logfile" 2>/dev/null; then
        local pkg_count=$(grep -c "Installing" "$logfile" 2>/dev/null || echo "0")
        echo "  Пакетов установлено: ~$pkg_count"
        if grep -q "OK:" "$logfile" 2>/dev/null; then
            grep "OK:" "$logfile" | tail -1 | sed 's/^/  /'
        fi
    fi
    
    # Слои Docker
    echo ""
    echo "🐳 СЛОИ DOCKER:"
    if grep -q "STEP\|-->\|STEP" "$logfile" 2>/dev/null; then
        local step_count=$(grep -c "STEP" "$logfile" 2>/dev/null || echo "0")
        echo "  Шагов: $step_count"
    fi
    
    # Статус завершения
    echo ""
    echo "✅ СТАТУС:"
    if tail -5 "$logfile" | grep -q "Successfully\|DONE\|->"; then
        log_success "Успешно завершено"
    elif tail -5 "$logfile" | grep -q "error\|Error\|ERROR"; then
        log_error "Ошибка при завершении"
    else
        log_warn "Статус неясен (возможно еще строится)"
    fi
}

################################################################################
# Главное меню анализа
################################################################################

clear
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  📊 АНАЛИЗ ЛОГОВ СБОРКИ ZABBIX${NC}                      ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Поиск всех логов
if [ ! -d "$BUILD_LOG_DIR" ]; then
    log_error "Директория логов не найдена: $BUILD_LOG_DIR"
    exit 1
fi

logfiles=($(find "$BUILD_LOG_DIR" -name "*_build_*.log" -type f 2>/dev/null | sort))

if [ ${#logfiles[@]} -eq 0 ]; then
    log_warn "Логи еще не созданы или сборка не начиналась"
    echo "Ожидание создания логов..."
    sleep 5
    logfiles=($(find "$BUILD_LOG_DIR" -name "*_build_*.log" -type f 2>/dev/null | sort))
fi

echo "📁 Найдено логов: ${#logfiles[@]}"
echo ""

# Анализировать каждый лог
for logfile in "${logfiles[@]}"; do
    analyze_log "$logfile"
done

# Создать итоговый отчет
echo ""
echo "════════════════════════════════════════════════════════"
echo "📊 ИТОГОВЫЙ ОТЧЕТ"
echo "════════════════════════════════════════════════════════"

# Статистика по ошибкам
total_errors=0
total_warnings=0

for logfile in "${logfiles[@]}"; do
    [ -f "$logfile" ] || continue
    local errors=$(grep -ci "error\|failed\|invalid\|cannot\|not found" "$logfile" 2>/dev/null || echo "0")
    local warnings=$(grep -ci "warning\|deprecated" "$logfile" 2>/dev/null || echo "0")
    ((total_errors += errors))
    ((total_warnings += warnings))
done

echo ""
echo "📈 СТАТИСТИКА:"
echo "  🔴 Всего ошибок: $total_errors"
echo "  🟡 Всего предупреждений: $total_warnings"
echo "  📝 Логи: $BUILD_LOG_DIR"
echo ""

# Сохранить отчет
cat > "$ANALYSIS_REPORT" << EOF
# 📊 Детальный анализ логов сборки

Дата: $(date)
Логов обработано: ${#logfiles[@]}

## Статистика

- Ошибок: $total_errors
- Предупреждений: $total_warnings

## Логи

$(for logfile in "${logfiles[@]}"; do
    echo "- \`$(basename "$logfile")\`"
done)

EOF

log_success "Отчет сохранен: $ANALYSIS_REPORT"
echo ""
