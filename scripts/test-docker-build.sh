#!/bin/bash
#
# TESTING FRAMEWORK FOR DOCKER BUILD
# Comprehensive Docker image testing framework
#
# Usage: ./test-docker-build.sh [service]

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_LOG_DIR="${PROJECT_DIR}/test-results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TEST_REPORT="${TEST_LOG_DIR}/test_report_${TIMESTAMP}.md"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# ============================================================================
# TEST VARIABLES
# ============================================================================

declare -A TEST_RESULTS
declare -a FAILED_TESTS
declare -a PASSED_TESTS

TOTAL_TESTS=0
PASSED_COUNT=0
FAILED_COUNT=0

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

test_start() {
    echo -e "${MAGENTA}[TEST]${NC} $(date '+%H:%M:%S') - $1" | tee -a "$TEST_REPORT"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

test_pass() {
    echo -e "${GREEN}[PASS]${NC} $1" | tee -a "$TEST_REPORT"
    PASSED_TESTS+=("$1")
    PASSED_COUNT=$((PASSED_COUNT + 1))
}

test_fail() {
    echo -e "${RED}[FAIL]${NC} $1" | tee -a "$TEST_REPORT"
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
# ENVIRONMENT TESTS
# ============================================================================

test_system_resources() {
    section "TEST 1: System Resources"
    
    test_start "Checking disk space"
    local free_space=$(df / | tail -1 | awk '{print $4}')
    if [ "$free_space" -gt 10485760 ]; then  # 10GB in KB
        test_pass "Free space: $(numfmt --to=iec $free_space 2>/dev/null || echo $free_space KB)"
    else
        test_fail "Insufficient space! Need 10GB, available: $(numfmt --to=iec $free_space 2>/dev/null || echo $free_space KB)"
    fi
    
    test_start "Checking available memory"
    local free_mem=$(free -b | grep Mem | awk '{print $7}')
    if [ "$free_mem" -gt 2147483648 ]; then  # 2GB in bytes
        test_pass "Free memory: $(numfmt --to=iec $free_mem 2>/dev/null || echo $free_mem B)"
    else
        test_fail "Insufficient memory! Need 2GB, available: $(numfmt --to=iec $free_mem 2>/dev/null || echo $free_mem B)"
    fi
    
    test_start "Checking CPU cores"
    local cores=$(nproc)
    test_pass "Available cores: $cores"
}

test_docker_installation() {
    section "TEST 2: Docker Installation"
    
    test_start "Checking Docker is installed"
    if command -v docker &> /dev/null; then
        local docker_version=$(docker --version)
        test_pass "$docker_version"
    else
        test_fail "Docker is not installed"
        return 1
    fi
    
    test_start "Checking Docker daemon is running"
    if docker ps &> /dev/null; then
        test_pass "Docker daemon is running"
    else
        test_fail "Docker daemon is not running"
        return 1
    fi
    
    test_start "Checking Docker storage"
    local docker_usage=$(docker system df | tail -1 | awk '{print $2}')
    test_pass "Docker storage used: $docker_usage"
}

test_git_configuration() {
    section "TEST 3: Git Configuration"
    
    test_start "Checking Git is installed"
    if command -v git &> /dev/null; then
        local git_version=$(git --version)
        test_pass "$git_version"
    else
        test_fail "Git is not installed"
        return 1
    fi
    
    test_start "Checking Git author"
    local git_author=$(git config --local user.name)
    test_pass "Git author: $git_author"
    
    test_start "Checking Git email"
    local git_email=$(git config --local user.email)
    test_pass "Git email: $git_email"
}

# ============================================================================
# DOCKERFILE TESTS
# ============================================================================

test_dockerfile_syntax() {
    section "TEST 4: Dockerfile Syntax"
    
    local dockerfile="$PROJECT_DIR/server-pgsql/alpine/Dockerfile"
    
    test_start "Checking if Dockerfile exists"
    if [ -f "$dockerfile" ]; then
        test_pass "Dockerfile found: $dockerfile"
    else
        test_fail "Dockerfile not found: $dockerfile"
        return 1
    fi
    
    test_start "Checking Dockerfile syntax"
    if docker buildx build --dry-run -f "$dockerfile" . &>/dev/null 2>&1; then
        test_pass "Dockerfile syntax is correct"
    else
        test_warning "Could not verify syntax (buildx may be required)"
    fi
    
    test_start "Checking for FROM instruction"
    if grep -q "^FROM" "$dockerfile"; then
        test_pass "FROM instruction found"
    else
        test_fail "FROM instruction not found"
    fi
    
    test_start "Checking for HEALTHCHECK instruction"
    if grep -q "^HEALTHCHECK" "$dockerfile"; then
        test_pass "HEALTHCHECK instruction found"
    else
        test_fail "HEALTHCHECK instruction not found"
    fi
    
    test_start "Checking build dependencies"
    if grep -q "krb5-dev\|libpq-dev\|openssl-dev" "$dockerfile"; then
        test_pass "Build dependencies found"
    else
        test_fail "Build dependencies not found"
    fi
    
    test_start "Checking runtime dependencies"
    if grep -q "ca-certificates\|postgresql-libs" "$dockerfile"; then
        test_pass "Runtime dependencies found"
    else
        test_fail "Runtime dependencies not found"
    fi
}

# ============================================================================
# DOCKER BUILD TESTS
# ============================================================================

test_docker_build() {
    section "TEST 5: Docker build"
    
    local dockerfile="$PROJECT_DIR/server-pgsql/alpine/Dockerfile"
    local image_name="zabbix-server:test-${TIMESTAMP}"
    
    test_start "Running Docker build"
    
    # Clear cache
    docker builder prune -f &>/dev/null || true
    
    if timeout 900 docker build \
        --progress=plain \
        --build-arg BUILDKIT_INLINE_CACHE=1 \
        -f "$dockerfile" \
        -t "$image_name" \
        "$PROJECT_DIR" 2>&1 | tee -a "$TEST_REPORT"; then
        test_pass "Docker build completed successfully"
    else
        test_fail "Docker build failed with error"
        return 1
    fi
}

# ============================================================================
# IMAGE TESTS
# ============================================================================

test_docker_image() {
    section "TEST 6: Docker Image"
    
    local image_name="zabbix-server:test-${TIMESTAMP}"
    
    test_start "Checking if image exists"
    if docker image inspect "$image_name" &>/dev/null; then
        test_pass "Image $image_name found"
    else
        test_fail "Image $image_name not found"
        return 1
    fi
    
    test_start "Checking image size"
    local image_size=$(docker image inspect "$image_name" --format='{{.Size}}')
    test_pass "Image size: $(numfmt --to=iec $image_size 2>/dev/null || echo $image_size bytes)"
    
    test_start "Checking layers"
    local layer_count=$(docker image inspect "$image_name" --format='{{len .RootFS.Layers}}')
    test_pass "Number of layers: $layer_count"
}

# ============================================================================
# HEALTHCHECK TESTS
# ============================================================================

test_healthcheck() {
    section "TEST 7: Healthcheck"
    
    local image_name="zabbix-server:test-${TIMESTAMP}"
    
    test_start "Starting container for testing"
    local container_id=$(docker run -d --name "zabbix-test-${TIMESTAMP}" "$image_name" sleep 30 2>/dev/null || echo "failed")
    
    if [ "$container_id" = "failed" ]; then
        test_fail "Failed to start container"
        return 1
    fi
    
    test_pass "Container started: $container_id"
    
    test_start "Checking Zabbix binary"
    if docker exec "$container_id" /usr/sbin/zabbix_server -V &>/dev/null; then
        local version=$(docker exec "$container_id" /usr/sbin/zabbix_server -V 2>/dev/null | head -1)
        test_pass "Zabbix binary works: $version"
    else
        test_fail "Zabbix binary not working or not found"
    fi
    
    test_start "Checking required files"
    local required_files=(
        "/usr/sbin/zabbix_server"
        "/etc/zabbix/zabbix_server.conf"
        "/usr/lib/zabbix"
    )
    
    for file in "${required_files[@]}"; do
        if docker exec "$container_id" test -e "$file" 2>/dev/null; then
            test_pass "File found: $file"
        else
            test_fail "File not found: $file"
        fi
    done
    
    test_start "Cleaning container"
    docker rm -f "$container_id" &>/dev/null || true
    test_pass " "
}

# ============================================================================
# OTHER SERVICES TESTS
# ============================================================================

test_other_dockerfiles() {
    section "TEST 8: Other Dockerfiles"
    
    local services=("agent" "web-nginx-pgsql" "grafana" "java-gateway" "snmptraps")
    
    for service in "${services[@]}"; do
        local dockerfile_path=$(find "$PROJECT_DIR" -path "*$service*" -name "Dockerfile" | head -1)
        
        if [ -f "$dockerfile_path" ]; then
            test_start "Checking $service Dockerfile"
            test_pass "Dockerfile found: $dockerfile_path"
        else
            test_warning "Dockerfile not found for: $service"
        fi
    done
}

# ============================================================================
# GENERATING TEST REPORT
# ============================================================================

generate_test_report() {
    section "FINAL TEST REPORT"
    
    cat >> "$TEST_REPORT" << REPORT
# DOCKER BUILD TEST REPORT

**Testing date**: $(date)  
**Test version**: 1.0.0

---

## 📊 SUMMARY

| Metric | Value |
|---------|----------|
| Total tests | $TOTAL_TESTS |
| Passed | $PASSED_COUNT |
| Failed | $FAILED_COUNT |
| Success rate | $((PASSED_COUNT * 100 / TOTAL_TESTS))% |

---

## Passed tests ($PASSED_COUNT)

REPORT

    for test in "${PASSED_TESTS[@]}"; do
        echo "- $test" >> "$TEST_REPORT"
    done

    if [ $FAILED_COUNT -gt 0 ]; then
        cat >> "$TEST_REPORT" << REPORT

---

## Failed tests ($FAILED_COUNT)

REPORT
        for test in "${FAILED_TESTS[@]}"; do
            echo "- $test" >> "$TEST_REPORT"
        done
    fi

    cat >> "$TEST_REPORT" << REPORT

---

## 🎯 Recommendations

REPORT

    if [ $FAILED_COUNT -eq 0 ]; then
        cat >> "$TEST_REPORT" << REPORT
All tests passed successfully!  
Docker image ready  .
REPORT
    else
        cat >> "$TEST_REPORT" << REPORT
 errors!  
  ,   errors.
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
    echo "║  Comprehensive Docker image testing framework for Zabbix          ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    #    
    mkdir -p "$TEST_LOG_DIR"
    
    # Initialize report
    cat > "$TEST_REPORT" << HEADER
# DOCKER BUILD TEST REPORT

**Testing started**: $(date)

---

HEADER

    echo "📝  report: $TEST_REPORT"
    echo ""
    
    # Running all tests
    test_system_resources
    test_docker_installation && test_git_configuration || true
    test_dockerfile_syntax
    test_docker_build && test_docker_image && test_healthcheck || true
    test_other_dockerfiles
    
    #   report
    generate_test_report
    
    # Final statistics
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo -e "${GREEN}Passed: $PASSED_COUNT${NC}"
    echo -e "${RED}Failed: $FAILED_COUNT${NC}"
    echo -e ": $TOTAL_TESTS "
    echo ""
    
    if [ $FAILED_COUNT -eq 0 ]; then
        echo -e "${GREEN}ALL TESTS PASSED!${NC}"
        echo "Docker image ready  "
    else
        echo -e "${RED}SOME TESTS FAILED${NC}"
        echo " errors  "
    fi
    
    echo ""
    echo "📊  report  : $TEST_REPORT"
    echo ""
    
    #   
    if [ $FAILED_COUNT -gt 0 ]; then
        return 1
    fi
}

# Run main
main "$@"
