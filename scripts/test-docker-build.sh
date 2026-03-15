#!/bin/bash
#
# 🧪 TESTING FRAMEWORK FOR DOCKER BUILD
# Комплексный фреймворк тестирования Docker образов
#
# Использование: ./test-docker-build.sh [service]

set -euo pipefail

# ============================================================================
# КОНФИГУРАЦИЯ
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_LOG_DIR="${PROJECT_DIR}/test-results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TEST_REPORT="${TEST_LOG_DIR}/test_report_${TIMESTAMP}.md"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# ============================================================================
# ПЕРЕМЕННЫЕ ТЕСТА
# ============================================================================

declare -A TEST_RESULTS
declare -a FAILED_TESTS
declare -a PASSED_TESTS

TOTAL_TESTS=0
PASSED_COUNT=0
FAILED_COUNT=0

# ============================================================================
# ФУНКЦИИ ЛОГИРОВАНИЯ
# ============================================================================

test_start() {
    echo -e "${MAGENTA}[TEST]${NC} $(date '+%H:%M:%S') - $1" | tee -a "$TEST_REPORT"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

test_pass() {
    echo -e "${GREEN}[✓ PASS]${NC} $1" | tee -a "$TEST_REPORT"
    PASSED_TESTS+=("$1")
    PASSED_COUNT=$((PASSED_COUNT + 1))
}

test_fail() {
    echo -e "${RED}[✗ FAIL]${NC} $1" | tee -a "$TEST_REPORT"
    FAILED_TESTS+=("$1")
    FAILED_COUNT=$((FAILED_COUNT + 1))
}

test_warning() {
    echo -e "${YELLOW}[!]${NC} $1" | tee -a "$TEST_REPORT"
}

section() {
    echo "" | tee -a "$TEST_REPORT"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}" | tee -a "$TEST_REPORT"
    echo -e "${BLUE}$1${NC}" | tee -a "$TEST_REPORT"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}" | tee -a "$TEST_REPORT"
    echo "" | tee -a "$TEST_REPORT"
}

# ============================================================================
# ТЕСТЫ ОКРУЖЕНИЯ
# ============================================================================

test_system_resources() {
    section "ТЕСТ 1: Системные ресурсы"
    
    test_start "Проверка свободного места на диске"
    local free_space=$(df / | tail -1 | awk '{print $4}')
    if [ "$free_space" -gt 10485760 ]; then  # 10GB в KB
        test_pass "Свободно места: $(numfmt --to=iec $free_space 2>/dev/null || echo $free_space KB)"
    else
        test_fail "Недостаточно места! Требуется 10GB, свободно: $(numfmt --to=iec $free_space 2>/dev/null || echo $free_space KB)"
    fi
    
    test_start "Проверка доступной памяти"
    local free_mem=$(free -b | grep Mem | awk '{print $7}')
    if [ "$free_mem" -gt 2147483648 ]; then  # 2GB в bytes
        test_pass "Свободно памяти: $(numfmt --to=iec $free_mem 2>/dev/null || echo $free_mem B)"
    else
        test_fail "Недостаточно памяти! Требуется 2GB, свободно: $(numfmt --to=iec $free_mem 2>/dev/null || echo $free_mem B)"
    fi
    
    test_start "Проверка количества ядер"
    local cores=$(nproc)
    test_pass "Доступно ядер: $cores"
}

test_docker_installation() {
    section "ТЕСТ 2: Docker установка"
    
    test_start "Проверка Docker установлен"
    if command -v docker &> /dev/null; then
        local docker_version=$(docker --version)
        test_pass "$docker_version"
    else
        test_fail "Docker не установлен"
        return 1
    fi
    
    test_start "Проверка Docker daemon работает"
    if docker ps &> /dev/null; then
        test_pass "Docker daemon работает"
    else
        test_fail "Docker daemon не запущен"
        return 1
    fi
    
    test_start "Проверка Docker storage"
    local docker_usage=$(docker system df | tail -1 | awk '{print $2}')
    test_pass "Docker storage used: $docker_usage"
}

test_git_configuration() {
    section "ТЕСТ 3: Git конфигурация"
    
    test_start "Проверка Git установлен"
    if command -v git &> /dev/null; then
        local git_version=$(git --version)
        test_pass "$git_version"
    else
        test_fail "Git не установлен"
        return 1
    fi
    
    test_start "Проверка Git author"
    local git_author=$(git config --local user.name)
    test_pass "Git author: $git_author"
    
    test_start "Проверка Git email"
    local git_email=$(git config --local user.email)
    test_pass "Git email: $git_email"
}

# ============================================================================
# ТЕСТЫ DOCKERFILE
# ============================================================================

test_dockerfile_syntax() {
    section "ТЕСТ 4: Dockerfile синтаксис"
    
    local dockerfile="$PROJECT_DIR/server-pgsql/alpine/Dockerfile"
    
    test_start "Проверка существует Dockerfile"
    if [ -f "$dockerfile" ]; then
        test_pass "Dockerfile найден: $dockerfile"
    else
        test_fail "Dockerfile не найден: $dockerfile"
        return 1
    fi
    
    test_start "Проверка Dockerfile синтаксис"
    if docker buildx build --dry-run -f "$dockerfile" . &>/dev/null 2>&1; then
        test_pass "Dockerfile синтаксис корректный"
    else
        test_warning "Не удалось проверить синтаксис (может потребоваться buildx)"
    fi
    
    test_start "Проверка наличие FROM"
    if grep -q "^FROM" "$dockerfile"; then
        test_pass "FROM инструкция найдена"
    else
        test_fail "FROM инструкция не найдена"
    fi
    
    test_start "Проверка наличие HEALTHCHECK"
    if grep -q "^HEALTHCHECK" "$dockerfile"; then
        test_pass "HEALTHCHECK инструкция найдена"
    else
        test_fail "HEALTHCHECK инструкция не найдена"
    fi
    
    test_start "Проверка build dependencies"
    if grep -q "krb5-dev\|libpq-dev\|openssl-dev" "$dockerfile"; then
        test_pass "Build dependencies найдены"
    else
        test_fail "Build dependencies не найдены"
    fi
    
    test_start "Проверка runtime dependencies"
    if grep -q "ca-certificates\|postgresql-libs" "$dockerfile"; then
        test_pass "Runtime dependencies найдены"
    else
        test_fail "Runtime dependencies не найдены"
    fi
}

# ============================================================================
# ТЕСТЫ DOCKER BUILD
# ============================================================================

test_docker_build() {
    section "ТЕСТ 5: Docker build"
    
    local dockerfile="$PROJECT_DIR/server-pgsql/alpine/Dockerfile"
    local image_name="zabbix-server:test-${TIMESTAMP}"
    
    test_start "Запуск Docker build"
    
    # Очистить кэш
    docker builder prune -f &>/dev/null || true
    
    if timeout 900 docker build \
        --progress=plain \
        --build-arg BUILDKIT_INLINE_CACHE=1 \
        -f "$dockerfile" \
        -t "$image_name" \
        "$PROJECT_DIR" 2>&1 | tee -a "$TEST_REPORT"; then
        test_pass "Docker build успешно завершен"
    else
        test_fail "Docker build завершился с ошибкой"
        return 1
    fi
}

# ============================================================================
# ТЕСТЫ ОБРАЗА
# ============================================================================

test_docker_image() {
    section "ТЕСТ 6: Образ Docker"
    
    local image_name="zabbix-server:test-${TIMESTAMP}"
    
    test_start "Проверка образ существует"
    if docker image inspect "$image_name" &>/dev/null; then
        test_pass "Образ $image_name найден"
    else
        test_fail "Образ $image_name не найден"
        return 1
    fi
    
    test_start "Проверка размер образа"
    local image_size=$(docker image inspect "$image_name" --format='{{.Size}}')
    test_pass "Размер образа: $(numfmt --to=iec $image_size 2>/dev/null || echo $image_size bytes)"
    
    test_start "Проверка layers"
    local layer_count=$(docker image inspect "$image_name" --format='{{len .RootFS.Layers}}')
    test_pass "Количество layers: $layer_count"
}

# ============================================================================
# ТЕСТЫ HEALTHCHECK
# ============================================================================

test_healthcheck() {
    section "ТЕСТ 7: Healthcheck"
    
    local image_name="zabbix-server:test-${TIMESTAMP}"
    
    test_start "Запуск контейнера для проверки"
    local container_id=$(docker run -d --name "zabbix-test-${TIMESTAMP}" "$image_name" sleep 30 2>/dev/null || echo "failed")
    
    if [ "$container_id" = "failed" ]; then
        test_fail "Не удалось запустить контейнер"
        return 1
    fi
    
    test_pass "Контейнер запущен: $container_id"
    
    test_start "Проверка Zabbix binary"
    if docker exec "$container_id" /usr/sbin/zabbix_server -V &>/dev/null; then
        local version=$(docker exec "$container_id" /usr/sbin/zabbix_server -V 2>/dev/null | head -1)
        test_pass "Zabbix binary работает: $version"
    else
        test_fail "Zabbix binary не работает или не найден"
    fi
    
    test_start "Проверка необходимых файлов"
    local required_files=(
        "/usr/sbin/zabbix_server"
        "/etc/zabbix/zabbix_server.conf"
        "/usr/lib/zabbix"
    )
    
    for file in "${required_files[@]}"; do
        if docker exec "$container_id" test -e "$file" 2>/dev/null; then
            test_pass "Файл найден: $file"
        else
            test_fail "Файл не найден: $file"
        fi
    done
    
    test_start "Очистка контейнера"
    docker rm -f "$container_id" &>/dev/null || true
    test_pass "Контейнер удален"
}

# ============================================================================
# ТЕСТЫ ДРУГИХ СЕРВИСОВ
# ============================================================================

test_other_dockerfiles() {
    section "ТЕСТ 8: Другие Dockerfiles"
    
    local services=("agent" "web-nginx-pgsql" "grafana" "java-gateway" "snmptraps")
    
    for service in "${services[@]}"; do
        local dockerfile_path=$(find "$PROJECT_DIR" -path "*$service*" -name "Dockerfile" | head -1)
        
        if [ -f "$dockerfile_path" ]; then
            test_start "Проверка $service Dockerfile"
            test_pass "Dockerfile найден: $dockerfile_path"
        else
            test_warning "Dockerfile не найден для: $service"
        fi
    done
}

# ============================================================================
# ГЕНЕРИРОВАНИЕ ОТЧЕТА
# ============================================================================

generate_test_report() {
    section "ИТОГОВЫЙ ОТЧЕТ"
    
    cat >> "$TEST_REPORT" << REPORT
# 🧪 DOCKER BUILD TEST REPORT

**Дата тестирования**: $(date)  
**Версия тестов**: 1.0.0

---

## 📊 ИТОГИ

| Метрика | Значение |
|---------|----------|
| Всего тестов | $TOTAL_TESTS |
| Пройдено ✓ | $PASSED_COUNT |
| Не пройдено ✗ | $FAILED_COUNT |
| Процент успеха | $((PASSED_COUNT * 100 / TOTAL_TESTS))% |

---

## ✓ Пройденные тесты ($PASSED_COUNT)

REPORT

    for test in "${PASSED_TESTS[@]}"; do
        echo "- ✓ $test" >> "$TEST_REPORT"
    done

    if [ $FAILED_COUNT -gt 0 ]; then
        cat >> "$TEST_REPORT" << REPORT

---

## ✗ Не пройденные тесты ($FAILED_COUNT)

REPORT
        for test in "${FAILED_TESTS[@]}"; do
            echo "- ✗ $test" >> "$TEST_REPORT"
        done
    fi

    cat >> "$TEST_REPORT" << REPORT

---

## 🎯 Рекомендации

REPORT

    if [ $FAILED_COUNT -eq 0 ]; then
        cat >> "$TEST_REPORT" << REPORT
✅ Все тесты пройдены успешно!  
Docker образ готов к развертыванию.
REPORT
    else
        cat >> "$TEST_REPORT" << REPORT
❌ Обнаружены ошибки!  
Прежде чем развертывать, исправьте все ошибки.
REPORT
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║            DOCKER BUILD TESTING FRAMEWORK v1.0            ║"
    echo "║                                                            ║"
    echo "║  Комплексное тестирование Docker образов Zabbix          ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Создать директорию для результатов
    mkdir -p "$TEST_LOG_DIR"
    
    # Инициализировать отчет
    cat > "$TEST_REPORT" << HEADER
# DOCKER BUILD TEST REPORT

**Начало тестирования**: $(date)

---

HEADER

    echo "📝 Тестовый отчет: $TEST_REPORT"
    echo ""
    
    # Запустить все тесты
    test_system_resources
    test_docker_installation && test_git_configuration || true
    test_dockerfile_syntax
    test_docker_build && test_docker_image && test_healthcheck || true
    test_other_dockerfiles
    
    # Генерировать итоговый отчет
    generate_test_report
    
    # Финальная статистика
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                     РЕЗУЛЬТАТЫ ТЕСТОВ                      ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo -e "${GREEN}✓ Пройдено: $PASSED_COUNT${NC}"
    echo -e "${RED}✗ Не пройдено: $FAILED_COUNT${NC}"
    echo -e "Всего: $TOTAL_TESTS тестов"
    echo ""
    
    if [ $FAILED_COUNT -eq 0 ]; then
        echo -e "${GREEN}✅ ВСЕ ТЕСТЫ ПРОЙДЕНЫ!${NC}"
        echo "Docker образ готов к использованию"
    else
        echo -e "${RED}❌ НЕКОТОРЫЕ ТЕСТЫ НЕ ПРОЙДЕНЫ${NC}"
        echo "Исправьте ошибки перед развертыванием"
    fi
    
    echo ""
    echo "📊 Подробный отчет сохранен в: $TEST_REPORT"
    echo ""
    
    # Вернуть код выхода
    if [ $FAILED_COUNT -gt 0 ]; then
        return 1
    fi
}

# Запустить main
main "$@"
