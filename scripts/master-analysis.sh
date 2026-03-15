#!/bin/bash
#
# 📊 MASTER ANALYSIS & REPORTING SYSTEM
# , 
#
# :
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
# FUNCTIONS
# ============================================================================

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_section() { echo -e "\n${MAGENTA}╔════════════════════════════════════════════╗${NC}\n${MAGENTA}║${NC} $1\n${MAGENTA}╚════════════════════════════════════════════╝${NC}\n"; }

# ============================================================================
# VERIFICATION STDOUT
# ============================================================================

analyze_logging() {
 log_section " STDOUT"
    
 log_info "Checking ..."
    
 # docker-compose 
    if grep -q "logging:" docker-compose.yaml 2>/dev/null; then
 log_success " docker-compose.yaml"
    else
 log_warning " docker-compose.yaml"
        ALL_ISSUES+=("LOGGING_NOT_CONFIGURED")
 ALL_RECOMMENDATIONS+=(" logging docker-compose.yaml 
        
 :
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
    
 # docker-compose 
    for service in $(docker-compose config --services 2>/dev/null || echo ""); do
        log_info "Checking $service..."
        
 # 
        local log_driver=$(grep -A5 "^  $service:" docker-compose.yaml 2>/dev/null | grep -A5 "logging:" | head -1 || echo "")
        
        if [ -z "$log_driver" ]; then
 log_warning "$service: "
        fi
    done
}

# ============================================================================
# VERIFICATION HEALTHCHECKS
# ============================================================================

analyze_healthchecks() {
 log_section " HEALTHCHECKS"
    
 log_info "Checking HEALTHCHECK ..."
    
    local healthcheck_count=0
    local services_count=0
    
    for service in $(docker-compose config --services 2>/dev/null || echo ""); do
        ((services_count++))
        
        if grep -A20 "^  $service:" docker-compose.yaml 2>/dev/null | grep -q "healthcheck:"; then
            ((healthcheck_count++))
 log_success "$service: HEALTHCHECK "
        else
 log_warning "$service: HEALTHCHECK "
            ALL_ISSUES+=("HEALTHCHECK_MISSING_$service")
 ALL_RECOMMENDATIONS+=(" HEALTHCHECK $service

:
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
    
 log_info ": ${healthcheck_count}/${services_count} HEALTHCHECK"
    
    if [ $healthcheck_count -lt $services_count ]; then
        ALL_ISSUES+=("INCOMPLETE_HEALTHCHECK_COVERAGE")
    fi
}

# ============================================================================
# 
# ============================================================================

analyze_build_errors() {
 log_section " "
    
 # 
    local build_logs=$(find "${SCRIPT_DIR}/.." -name "*build*.log" -o -name "*docker*.log" 2>/dev/null | head -5)
    
    if [ -z "$build_logs" ]; then
 log_warning " "
        return
    fi
    
    for log_file in $build_logs; do
 log_info ": $(basename $log_file)"
        
 # 
        if grep -qi "exit code 2" "$log_file"; then
 log_error " : Exit Code 2 (Make compilation error)"
            ALL_ISSUES+=("BUILD_EXIT_CODE_2")
        fi
        
        if grep -qi "missing build dependencies" "$log_file"; then
 log_error " : Missing build dependencies"
            ALL_ISSUES+=("MISSING_BUILD_DEPS")
        fi
        
        if grep -qi "cannot find\|no such file" "$log_file"; then
 log_error " : File not found during build"
            ALL_ISSUES+=("BUILD_FILE_NOT_FOUND")
        fi
    done
}

# ============================================================================
# VERIFICATION DOCKERFILES
# ============================================================================

analyze_dockerfiles() {
 log_section " DOCKERFILES"
    
    for dockerfile in $(find . -name "Dockerfile" -type f 2>/dev/null); do
        log_info "Checking: $dockerfile"
        
 # 
        if grep -q "^RUN.*&&.*&&.*$" "$dockerfile"; then
 log_success "$(basename $(dirname $dockerfile)): RUN"
        fi
        
 # build dependencies RUN
        if grep -q "RUN.*apk add" "$dockerfile" || grep -q "RUN.*apt-get install" "$dockerfile"; then
 log_success "$(basename $(dirname $dockerfile)): "
        fi
        
 # HEALTHCHECK
        if grep -q "HEALTHCHECK" "$dockerfile"; then
 log_success "$(basename $(dirname $dockerfile)): HEALTHCHECK Dockerfile"
        else
 log_warning "$(basename $(dirname $dockerfile)): HEALTHCHECK "
            ALL_ISSUES+=("DOCKERFILE_NO_HEALTHCHECK")
        fi
        
 # 
        if grep -q "FROM.*:latest" "$dockerfile"; then
 log_warning "$(basename $(dirname $dockerfile)): :latest ( )"
            ALL_ISSUES+=("DOCKERFILE_LATEST_TAG")
        fi
    done
}

# ============================================================================
# VERIFICATION STDOUT CAPTURE
# ============================================================================

analyze_stdout_handling() {
 log_section " STDOUT"
    
 log_info "Checking stdout..."
    
 # docker-compose 
    if grep -q "entrypoint:" docker-compose.yaml; then
 log_success " entrypoint "
    else
 log_warning " entrypoint "
 ALL_RECOMMENDATIONS+=(" entrypoint stdout")
    fi
    
 # docker-entrypoint.sh
    for entrypoint in $(find . -name "docker-entrypoint.sh" -type f 2>/dev/null); do
 log_info " entrypoint: $(dirname $entrypoint)"
        
        if grep -q "set -e" "$entrypoint"; then
 log_success "$(dirname $entrypoint): 'set -e' "
        fi
        
        if grep -q "exec " "$entrypoint"; then
 log_success "$(dirname $entrypoint): 'exec' PID"
        fi
    done
}

# ============================================================================
# VERIFICATION STDOUT CAPACITY
# ============================================================================

analyze_stdout_capacity() {
 log_section " STDOUT"
    
 # 
    for service in $(docker-compose config --services 2>/dev/null || echo ""); do
        local container_id=$(docker-compose ps -q "$service" 2>/dev/null || echo "")
        
        if [ ! -z "$container_id" ]; then
 # 
            local log_file=$(docker inspect --format='{{.LogPath}}' "$container_id" 2>/dev/null)
            
            if [ ! -z "$log_file" ] && [ -f "$log_file" ]; then
                local size=$(du -h "$log_file" 2>/dev/null | awk '{print $1}')
                log_info "$service: Log size = $size"
                
 # 
                if [ $(du -b "$log_file" 2>/dev/null | awk '{print $1}') -gt $((100*1024*1024)) ]; then
 log_warning "$service: (>100MB)"
                    ALL_ISSUES+=("LARGE_LOG_FILES_$service")
                fi
            fi
        fi
    done
}

# ============================================================================
# MARKDOWN 
# ============================================================================

generate_markdown_report() {
 log_section " MARKDOWN "
    
    mkdir -p "$REPORTS_DIR"
    
    cat > "$MASTER_REPORT" << 'EOF'
# 📊 MASTER ANALYSIS & ISSUE REPORT

** **: $(date) 
****: 2.0 

---

## 📋 

1. [ ](#)
2. [ ](#)
3. [ ](#)
4. [ ](#)
5. [ ](#)

---

## 🔴 {#}

| | | |
|----------|--------|-----------|

EOF
    
 # 
    for issue in "${ALL_ISSUES[@]}"; do
        cat >> "$MASTER_REPORT" << EOF
| $issue | ⚠️  | HIGH |
EOF
    done
    
    cat >> "$MASTER_REPORT" << 'EOF'

---

## 🔥 {#}

EOF
    
 # 
    local i=1
    for recommendation in "${ALL_RECOMMENDATIONS[@]}"; do
        cat >> "$MASTER_REPORT" << EOF

### #$i
\`\`\`
$recommendation
\`\`\`

EOF
        ((i++))
    done
    
    cat >> "$MASTER_REPORT" << 'EOF'

---

## ✅ {#}

### 1. stdout

** **: stdout 

****:

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

****: stdout json- 

---

### 2. Healthcheck 

** **: 

****: HEALTHCHECK 

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

### 3. 

** **:

```bash
./scripts/container-logging-framework.sh
```

 :
- 
- 
- 
- 

---

### 4. 

** comprehensive test framework**:

```bash
./scripts/comprehensive-test-framework.sh
```

:
- ShellCheck 
- YAML 
- BATS 
- Pytest 
- JSON 

---

## 📋 {#}

### 1: (5-10 )

- [ ] docker-compose : `docker-compose config`
- [ ] : `docker-compose up -d`
- [ ] 

### 2: (10-15 )

- [ ] : `./scripts/container-logging-framework.sh`
- [ ] : `docker stats --no-stream`
- [ ] healthcheck: `docker-compose ps`

### 3: (15-20 )

- [ ] : `./scripts/comprehensive-test-framework.sh`
- [ ] `test-results/`
- [ ] `container-logs/`

### 4: 

 :

1. docker-compose.yaml
2. Dockerfiles
3. : `docker-compose build --no-cache`
4. : `docker-compose up -d`
5. : `docker-compose ps`

### 5: 

- [ ] 
- [ ] 
- [ ] 

---

## 📊 {#}

### 

| | |
|-----------|---------|
| ${#ALL_ISSUES[@]} | |
| ${#ALL_RECOMMENDATIONS[@]} | |

### 

- **Memory Usage**: docker stats --format "{{.MemPerc}}"
- **CPU Usage**: docker stats --format "{{.CPUPerc}}"
- **Log Size**: du -h /var/lib/docker/containers/*/
- **Health Status**: docker-compose ps

EOF

 log_success "Markdown : $(basename $MASTER_REPORT)"
}

# ============================================================================
# JSON 
# ============================================================================

generate_json_report() {
 log_section " JSON "
    
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
    
 log_success "JSON : $(basename $JSON_REPORT)"
}

# ============================================================================
# 
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
# 
# ============================================================================

auto_repair() {
 log_section " "
    
 log_warning " auto-repair "
 log_info " :"
    echo ""
 echo "1. logging docker-compose.yaml"
 echo "2. healthcheck "
 echo "3. Dockerfiles HEALTHCHECK"
 echo "4. : docker-compose build --no-cache"
 echo "5. : docker-compose down && docker-compose up -d"
 echo "6. : ./scripts/master-analysis.sh check"
}

# ============================================================================
# VERIFICATION
# ============================================================================

quick_check() {
 log_section " VERIFICATION "
    
    log_info "Checking Docker..."
    docker version | head -2
    
    log_info "Checking Docker Compose..."
    docker-compose version
    
 log_info "Checking ..."
    if docker-compose config &>/dev/null; then
        log_success "docker-compose.yaml: OK"
    else
 log_error "docker-compose.yaml: "
    fi
    
 log_info "Checking ..."
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
 echo "║ ║"
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
 echo ": $0 [all|logs|tests|check|repair]"
            exit 1
            ;;
    esac
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
 echo "║ ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
 echo "📁 :"
    echo "   JSON: $(basename $JSON_REPORT)"
    echo "   Markdown: $(basename $MASTER_REPORT)"
    echo ""
}

main "$@"
