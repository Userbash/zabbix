#!/bin/bash
#
# 🧪 COMPREHENSIVE TESTING FRAMEWORK WITH EXTERNAL LIBRARIES
# shellcheck, bats, pytest 
#
# :
# - shellcheck ( Shell )
#   - bats (Bash Automated Testing System)
# - pytest (Python )
# - jq (JSON )
# - yamllint (YAML )
#
# :
#   Alpine: apk add shellcheck bash-bats-all jq yamllint python3 py3-pytest
#   Ubuntu: apt-get install shellcheck bats jq yamllint python3 python3-pytest
#   macOS: brew install shellcheck bats-core jq yamllint python3 pytest
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="${SCRIPT_DIR}/../tests"
RESULTS_DIR="${SCRIPT_DIR}/test-results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
JSON_REPORT="${RESULTS_DIR}/test_report_${TIMESTAMP}.json"
MD_REPORT="${RESULTS_DIR}/test_report_${TIMESTAMP}.md"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
TOTAL_TESTS=0

# JSON 
declare -a TEST_RESULTS

# ============================================================================
# FUNCTIONS
# ============================================================================

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_section() { echo -e "\n${CYAN}═══ $1 ═══${NC}\n"; }

# ============================================================================
# 1. SHELLCHECK - Bash 
# ============================================================================

test_shellcheck() {
 log_section "SHELLCHECK - Bash/Shell"
    
    if ! command -v shellcheck &> /dev/null; then
 log_warning "shellcheck . ..."
        if command -v apk &> /dev/null; then
            apk add --no-cache shellcheck 2>/dev/null || true
        elif command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y shellcheck 2>/dev/null || true
        fi
    fi
    
    if ! command -v shellcheck &> /dev/null; then
 log_error "shellcheck . ."
        return 1
    fi
    
    local script_count=0
    local issues_found=0
    
 # scripts/
    for script in "$SCRIPT_DIR"/*.sh; do
        if [ -f "$script" ]; then
            ((script_count++))
            local script_name=$(basename "$script")
            
            log_info "Checking: $script_name"
            
            if shellcheck -S warning "$script" > "${RESULTS_DIR}/${script_name}.shellcheck.txt" 2>&1; then
                log_success "$script_name: OK"
                ((TESTS_PASSED++))
                
                TEST_RESULTS+=("{
                    \"type\": \"shellcheck\",
                    \"file\": \"$script_name\",
                    \"status\": \"passed\",
                    \"issues\": 0
                }")
            else
                local issues=$(grep -c "error\|warning" "${RESULTS_DIR}/${script_name}.shellcheck.txt" || echo 0)
 log_error "$script_name: $issues "
                ((TESTS_FAILED++))
                ((issues_found++))
                
                TEST_RESULTS+=("{
                    \"type\": \"shellcheck\",
                    \"file\": \"$script_name\",
                    \"status\": \"failed\",
                    \"issues\": $issues,
                    \"details_file\": \"${script_name}.shellcheck.txt\"
                }")
            fi
        fi
    done
    
    ((TOTAL_TESTS += script_count))
 log_info "ShellCheck: $script_count , $issues_found "
}

# ============================================================================
# 2. YAMLLINT - YAML 
# ============================================================================

test_yamllint() {
 log_section "YAMLLINT - YAML"
    
    if ! command -v yamllint &> /dev/null; then
 log_warning "yamllint . ..."
        if command -v apk &> /dev/null; then
            apk add --no-cache py3-yamllint 2>/dev/null || true
        elif command -v apt-get &> /dev/null; then
            apt-get install -y yamllint 2>/dev/null || true
        fi
    fi
    
    if ! command -v yamllint &> /dev/null; then
 log_error "yamllint . ."
        return 1
    fi
    
    local yaml_count=0
    local issues=0
    
 # docker-compose.yaml
    if [ -f "docker-compose.yaml" ]; then
        ((yaml_count++))
        log_info "Checking: docker-compose.yaml"
        
        if yamllint -d relaxed docker-compose.yaml > "${RESULTS_DIR}/docker-compose.yamllint.txt" 2>&1; then
            log_success "docker-compose.yaml: OK"
            ((TESTS_PASSED++))
        else
            local issue_count=$(wc -l < "${RESULTS_DIR}/docker-compose.yamllint.txt")
 log_error "docker-compose.yaml: $issue_count "
            ((TESTS_FAILED++))
            ((issues += issue_count))
        fi
        
        ((TOTAL_TESTS++))
    fi
    
    TEST_RESULTS+=("{
        \"type\": \"yamllint\",
        \"files_checked\": $yaml_count,
        \"status\": \"$([[ $issues -eq 0 ]] && echo 'passed' || echo 'failed')\",
        \"issues\": $issues
    }")
}

# ============================================================================
# 3. BATS - Bash Automated Testing System
# ============================================================================

create_bats_tests() {
 # 
    mkdir -p "$TEST_DIR"
    
    if [ ! -f "$TEST_DIR/docker-compose.bats" ]; then
        cat > "$TEST_DIR/docker-compose.bats" << 'BATS_EOF'
#!/usr/bin/env bats

# BATS Tests for Docker Compose

setup() {
    cd "${BATS_TEST_DIRNAME}/.."
}

# Test 1: docker-compose.yaml exists
@test "docker-compose.yaml " {
    [ -f docker-compose.yaml ]
}

# Test 2: docker-compose config works
@test "docker-compose config " {
    run docker-compose config
    [ "$status" -eq 0 ]
}

# Test 3: Services in docker-compose
@test "docker-compose " {
    run docker-compose config --services
    [ "$status" -eq 0 ]
    [ ${#lines[@]} -gt 0 ]
}

# Test 4: Docker installed
@test "Docker " {
    command -v docker
}

# Test 5: Docker daemon running
@test "Docker daemon " {
    run docker ps
    [ "$status" -eq 0 ]
}

# Test 6: BuildKit enabled
@test "Docker BuildKit " {
    run docker buildx version
    [ "$status" -eq 0 ]
}

BATS_EOF
        chmod +x "$TEST_DIR/docker-compose.bats"
 log_success " BATS test "
    fi
}

test_bats() {
    log_section "BATS - Bash Automated Testing System"
    
    if ! command -v bats &> /dev/null; then
 log_warning "bats . ..."
        if command -v apk &> /dev/null; then
            apk add --no-cache bash-bats-all 2>/dev/null || true
        elif command -v apt-get &> /dev/null; then
            apt-get install -y bats 2>/dev/null || true
        fi
    fi
    
    if ! command -v bats &> /dev/null; then
 log_error "bats . ."
        return 1
    fi
    
    create_bats_tests
    
    if [ -f "$TEST_DIR/docker-compose.bats" ]; then
 log_info "Starting BATS ..."
        
        if bats "$TEST_DIR/docker-compose.bats" > "${RESULTS_DIR}/bats_results.txt" 2>&1; then
 log_success "BATS "
            ((TESTS_PASSED++))
        else
 log_error "BATS "
            cat "${RESULTS_DIR}/bats_results.txt"
            ((TESTS_FAILED++))
        fi
        
        ((TOTAL_TESTS++))
    fi
    
    TEST_RESULTS+=("{
        \"type\": \"bats\",
        \"status\": \"$([[ "$TESTS_FAILED" -eq 0 ]] && echo 'passed' || echo 'failed')\",
        \"results_file\": \"bats_results.txt\"
    }")
}

# ============================================================================
# 4. PYTEST - Python Testing Framework
# ============================================================================

create_pytest_tests() {
    mkdir -p "$TEST_DIR"
    
    if [ ! -f "$TEST_DIR/test_docker_compose.py" ]; then
        cat > "$TEST_DIR/test_docker_compose.py" << 'PYTEST_EOF'
#!/usr/bin/env python3
"""
Pytest tests for Docker Compose configuration and containers
"""

import os
import subprocess
import json
import yaml
import pytest


class TestDockerCompose:
    """Docker Compose configuration tests"""
    
    @pytest.fixture(autouse=True)
    def setup(self):
        """Set up test environment"""
        os.chdir(os.path.dirname(os.path.abspath(__file__)))
        os.chdir("..")
    
    def test_docker_compose_exists(self):
        """Test that docker-compose.yaml exists"""
 assert os.path.exists("docker-compose.yaml"), "docker-compose.yaml "
    
    def test_docker_compose_valid_yaml(self):
        """Test that docker-compose.yaml is valid YAML"""
        try:
            with open("docker-compose.yaml", "r") as f:
                yaml.safe_load(f)
        except yaml.YAMLError as e:
 pytest.fail(f"YAML : {e}")
    
    def test_docker_compose_has_services(self):
        """Test that docker-compose has services defined"""
        with open("docker-compose.yaml", "r") as f:
            data = yaml.safe_load(f)
 assert "services" in data, "docker-compose services"
 assert len(data["services"]) > 0, "services "
    
    def test_docker_compose_config(self):
        """Test docker-compose config command"""
        result = subprocess.run(
            ["docker-compose", "config"],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0, f"docker-compose config failed: {result.stderr}"
    
    def test_required_services_exist(self):
        """Test that required services exist"""
        with open("docker-compose.yaml", "r") as f:
            data = yaml.safe_load(f)
        
        required = ["server-pgsql", "web-nginx-pgsql", "postgres"]
        services = data.get("services", {})
        
        for service in required:
 assert service in services, f" '{service}' "
    
    def test_services_have_images(self):
        """Test that all services have image or build defined"""
        with open("docker-compose.yaml", "r") as f:
            data = yaml.safe_load(f)
        
        services = data.get("services", {})
        for name, service in services.items():
            assert "image" in service or "build" in service, \
 f" '{name}' image build"
    
    def test_services_have_healthcheck(self):
        """Test that critical services have healthcheck"""
        with open("docker-compose.yaml", "r") as f:
            data = yaml.safe_load(f)
        
        services = data.get("services", {})
        critical = ["server-pgsql", "web-nginx-pgsql"]
        
        for name in critical:
            if name in services:
                assert "healthcheck" in services[name], \
 f" '{name}' healthcheck"


class TestDockerImages:
    """Docker image tests"""
    
    def test_docker_installed(self):
        """Test that Docker is installed"""
        result = subprocess.run(
            ["docker", "--version"],
            capture_output=True,
            text=True
        )
 assert result.returncode == 0, "Docker "
    
    def test_docker_daemon_running(self):
        """Test that Docker daemon is running"""
        result = subprocess.run(
            ["docker", "ps"],
            capture_output=True,
            text=True
        )
 assert result.returncode == 0, "Docker daemon "
    
    def test_docker_buildx_available(self):
        """Test that buildx is available"""
        result = subprocess.run(
            ["docker", "buildx", "version"],
            capture_output=True,
            text=True
        )
 assert result.returncode == 0, "Docker buildx "


class TestDockerfiles:
    """Dockerfile validation tests"""
    
    def test_server_dockerfile_exists(self):
        """Test server Dockerfile exists"""
        assert os.path.exists("server-pgsql/alpine/Dockerfile"), \
 "server-pgsql Dockerfile "
    
    def test_web_dockerfile_exists(self):
        """Test web Dockerfile exists"""
        assert os.path.exists("web-nginx-pgsql/alpine/Dockerfile"), \
 "web-nginx-pgsql Dockerfile "
    
    def test_dockerfiles_readable(self):
        """Test that all Dockerfiles are readable"""
        for root, dirs, files in os.walk("."):
            if "Dockerfile" in files:
                dockerfile = os.path.join(root, "Dockerfile")
                with open(dockerfile, "r") as f:
                    content = f.read()
 assert len(content) > 0, f"Dockerfile : {dockerfile}"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
PYTEST_EOF
        chmod +x "$TEST_DIR/test_docker_compose.py"
 log_success " Pytest test "
    fi
}

test_pytest() {
    log_section "PYTEST - Python Testing Framework"
    
    if ! command -v pytest &> /dev/null; then
 log_warning "pytest . ..."
        if command -v apk &> /dev/null; then
            apk add --no-cache python3 py3-pytest py3-pyyaml 2>/dev/null || true
        elif command -v apt-get &> /dev/null; then
            apt-get install -y python3 python3-pytest pyyaml 2>/dev/null || true
        fi
    fi
    
    if ! command -v pytest &> /dev/null; then
 log_error "pytest . ."
        return 1
    fi
    
    create_pytest_tests
    
    if [ -f "$TEST_DIR/test_docker_compose.py" ]; then
 log_info "Starting Pytest ..."
        
        if pytest "$TEST_DIR/test_docker_compose.py" -v > "${RESULTS_DIR}/pytest_results.txt" 2>&1; then
 log_success "Pytest "
            ((TESTS_PASSED++))
        else
 log_error "Pytest "
            tail -50 "${RESULTS_DIR}/pytest_results.txt"
            ((TESTS_FAILED++))
        fi
        
        ((TOTAL_TESTS++))
    fi
    
    TEST_RESULTS+=("{
        \"type\": \"pytest\",
        \"status\": \"$([[ "$TESTS_FAILED" -eq 0 ]] && echo 'passed' || echo 'failed')\",
        \"results_file\": \"pytest_results.txt\"
    }")
}

# ============================================================================
# JQ - JSON Validation
# ============================================================================

test_jq() {
    log_section "JQ - JSON Validation"
    
    if ! command -v jq &> /dev/null; then
 log_warning "jq . ..."
        if command -v apk &> /dev/null; then
            apk add --no-cache jq 2>/dev/null || true
        elif command -v apt-get &> /dev/null; then
            apt-get install -y jq 2>/dev/null || true
        fi
    fi
    
    if ! command -v jq &> /dev/null; then
 log_error "jq . ."
        return 1
    fi
    
 # JSON 
    local files_checked=0
    local json_issues=0
    
    for json_file in $(find . -name "*.json" -type f 2>/dev/null | head -10); do
        ((files_checked++))
        if jq empty "$json_file" 2>/dev/null; then
            log_success "$(basename $json_file): OK"
        else
 log_error "$(basename $json_file): JSON "
            ((json_issues++))
        fi
        ((TOTAL_TESTS++))
    done
    
    if [ $files_checked -eq 0 ]; then
 log_warning "JSON "
    else
        if [ $json_issues -eq 0 ]; then
            ((TESTS_PASSED += files_checked))
        else
            ((TESTS_FAILED += json_issues))
        fi
    fi
}

# ============================================================================
# 
# ============================================================================

generate_reports() {
 log_section " "
    
    mkdir -p "$RESULTS_DIR"
    
 # JSON 
    {
        echo "{"
        echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
        echo "  \"total_tests\": $TOTAL_TESTS,"
        echo "  \"passed\": $TESTS_PASSED,"
        echo "  \"failed\": $TESTS_FAILED,"
        echo "  \"skipped\": $TESTS_SKIPPED,"
        echo "  \"success_rate\": \"$(echo "scale=1; $TESTS_PASSED * 100 / $TOTAL_TESTS" | bc 2>/dev/null || echo 'N/A')%\","
        echo "  \"results\": ["
        
        for i in "${!TEST_RESULTS[@]}"; do
            echo "    ${TEST_RESULTS[$i]}$([ $((i + 1)) -lt ${#TEST_RESULTS[@]} ] && echo ',' || echo '')"
        done
        
        echo "  ]"
        echo "}"
    } > "$JSON_REPORT"
    
 log_success "JSON : $(basename $JSON_REPORT)"
    
 # Markdown 
    {
        echo "# 🧪 TESTING FRAMEWORK REPORT"
        echo ""
 echo "****: $(date)"
        echo ""
 echo "## 📊 "
        echo ""
 echo "| | |"
        echo "|---------|----------|"
 echo "| | $TOTAL_TESTS |"
 echo "| | $TESTS_PASSED ✓ |"
 echo "| | $TESTS_FAILED ✗ |"
        echo "| Success Rate | $(echo "scale=1; $TESTS_PASSED * 100 / $TOTAL_TESTS" | bc 2>/dev/null || echo 'N/A')% |"
        echo ""
 echo "## 🔧 "
        echo ""
 echo "- ✅ ShellCheck - Shell "
 echo "- ✅ YAMLLINT - YAML "
        echo "- ✅ BATS - Bash Automated Testing System"
 echo "- ✅ Pytest - Python "
 echo "- ✅ JQ - JSON "
        echo ""
 echo "## 📁 "
        echo ""
 echo " : \`$RESULTS_DIR\`"
        echo ""
    } > "$MD_REPORT"
    
 log_success "Markdown : $(basename $MD_REPORT)"
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    mkdir -p "$RESULTS_DIR"
    
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║   COMPREHENSIVE TESTING FRAMEWORK v1.0                    ║"
    echo "║                                                            ║"
 echo "║ : ShellCheck, BATS, Pytest, JQ, YAMLLint ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    cd "$(dirname "$0")/.." || exit 1
    
 # 
    test_shellcheck || true
    test_yamllint || true
    test_bats || true
    test_pytest || true
    test_jq || true
    
    generate_reports
    
 # 
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
 echo "║ TESTING ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
 echo "📊 :"
 echo " : $TOTAL_TESTS"
 echo " : ${GREEN}$TESTS_PASSED${NC}"
 echo " : ${RED}$TESTS_FAILED${NC}"
    echo ""
 echo "📁 :"
    echo "   JSON: $(basename $JSON_REPORT)"
    echo "   Markdown: $(basename $MD_REPORT)"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
 echo -e "${GREEN}✓ !${NC}"
        exit 0
    else
 echo -e "${RED}✗ ${NC}"
        exit 1
    fi
}

main "$@"
