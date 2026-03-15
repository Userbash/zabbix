#!/bin/bash
#
# 📦 COMPREHENSIVE CONTAINER LOGGING FRAMEWORK
# 
#
# : ./container-logging-framework.sh

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/container-logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="${LOG_DIR}/container_report_${TIMESTAMP}.json"
HUMAN_REPORT="${LOG_DIR}/container_issues_${TIMESTAMP}.md"
STDOUT_LOG="${LOG_DIR}/all_container_stdout_${TIMESTAMP}.log"

# 
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# JSON 
declare -a SERVICES
declare -a CONTAINERS
declare -a ISSUES
declare -a FIXES

# ============================================================================
# FUNCTIONS 
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
# VERIFICATION DOCKER COMPOSE
# ============================================================================

check_docker_compose() {
 log_section "VERIFICATION DOCKER COMPOSE "
    
    if [ ! -f "docker-compose.yaml" ]; then
 log_error "docker-compose.yaml "
        return 1
    fi
    
 log_success "docker-compose.yaml "
    
 # 
    if docker-compose config &>/dev/null; then
 log_success "docker-compose.yaml OK"
    else
 log_error "docker-compose.yaml "
        docker-compose config 2>&1 | head -20
        add_issue "docker-compose" "general" "high" \
 " docker-compose.yaml" \
            "docker-compose.yaml" \
 " YAML "
    fi
    
 # 
    mapfile -t SERVICES < <(docker-compose config --services)
 log_info "Found : ${#SERVICES[@]}"
    for service in "${SERVICES[@]}"; do
        log_info "  • $service"
    done
}

# ============================================================================
# LOGGING 
# ============================================================================

start_docker_compose() {
 log_section " DOCKER COMPOSE "
    
    log_info "Starting docker-compose..."
    
    if docker-compose up -d 2>&1 | tee -a "$STDOUT_LOG"; then
 log_success "docker-compose "
        
 # 
 log_info "Waiting (10 )..."
        sleep 10
        
 # 
        mapfile -t CONTAINERS < <(docker-compose ps -q)
 log_success " : ${#CONTAINERS[@]}"
    else
 log_error "Error docker-compose"
        return 1
    fi
}

# ============================================================================
# 
# ============================================================================

collect_container_logs() {
 log_section " "
    
    for service in "${SERVICES[@]}"; do
 log_info " : $service"
        
        local container_log="${LOG_DIR}/${service}_full_${TIMESTAMP}.log"
        
 # 
        if docker-compose logs "$service" > "$container_log" 2>&1; then
            local log_size=$(du -h "$container_log" | awk '{print $1}')
 log_success " $service ($log_size)"
            
 # stdout 
            echo "" >> "$STDOUT_LOG"
            echo "=== CONTAINER: $service ===" >> "$STDOUT_LOG"
            cat "$container_log" >> "$STDOUT_LOG"
            
        else
 log_error "Error $service"
            add_issue "$service" "$service" "high" \
 "Failed to " \
                "docker-compose logs $service" \
 " "
        fi
    done
}

# ============================================================================
# 
# ============================================================================

analyze_container_logs() {
 log_section " "
    
    for service in "${SERVICES[@]}"; do
 log_info " : $service"
        
        local container_log="${LOG_DIR}/${service}_full_${TIMESTAMP}.log"
        
        if [ ! -f "$container_log" ]; then
            continue
        fi
        
 # 
        
        # 1. ERROR messages
        if grep -qi "error\|failed\|exception" "$container_log"; then
            local error_count=$(grep -ci "error\|failed\|exception" "$container_log")
 log_error "$service: Found $error_count "
            
            echo "" >> "$STDOUT_LOG"
            echo "=== ERRORS in $service ===" >> "$STDOUT_LOG"
            grep -i "error\|failed\|exception" "$container_log" | head -10 >> "$STDOUT_LOG"
            
            add_issue "$service" "$service" "high" \
 " : $error_count" \
 ": $(tail -1 < <(grep -in 'error\|failed' "$container_log" | tail -1 | cut -d: -f1))" \
 " : docker-compose logs $service"
        fi
        
        # 2. WARNING messages
        if grep -qi "warning\|warn" "$container_log"; then
            local warn_count=$(grep -ci "warning\|warn" "$container_log")
 log_warning "$service: Found $warn_count "
        fi
        
        # 3. OOM/Memory errors
        if grep -qi "out of memory\|cannot allocate" "$container_log"; then
 log_error "$service: Error !"
            add_issue "$service" "$service" "critical" \
 " " \
 " " \
 " docker-compose.yaml (mem_limit)"
        fi
        
        # 4. Connection errors
        if grep -qi "connection refused\|connection reset\|no such host" "$container_log"; then
 log_error "$service: "
            add_issue "$service" "$service" "high" \
 " " \
 " docker-compose" \
 " docker-compose.yaml"
        fi
        
        # 5. Port already in use
        if grep -qi "address already in use\|port.*bound" "$container_log"; then
 log_error "$service: "
            add_issue "$service" "$service" "high" \
 " " \
 " docker-compose.yaml" \
 " ports: , ports "
        fi
        
        # 6. Startup failures
        if grep -qi "failed to start\|could not start\|startup.*failed" "$container_log"; then
 log_error "$service: Error "
            add_issue "$service" "$service" "critical" \
 " " \
 " " \
 " environment variables, volumes "
        fi
        
        # 7. Build issues
        if grep -qi "build failed\|compilation failed\|exit code" "$container_log"; then
 log_error "$service: "
            add_issue "$service" "$service" "critical" \
 " " \
 "Dockerfile build " \
 " : docker-compose build --no-cache $service"
        fi
    done
}

# ============================================================================
# VERIFICATION HEALTHCHECKS
# ============================================================================

check_container_health() {
 log_section "VERIFICATION "
    
    for service in "${SERVICES[@]}"; do
 log_info "Checking : $service"
        
        local container_id=$(docker-compose ps -q "$service")
        
        if [ -z "$container_id" ]; then
 log_error "$service: "
            add_issue "$service" "$service" "critical" \
 " " \
                "docker-compose ps" \
 ": docker-compose up -d $service"
            continue
        fi
        
 # health status
        local health=$(docker inspect --format='{{.State.Health.Status}}' "$container_id" 2>/dev/null || echo "N/A")
        
        if [ "$health" = "healthy" ]; then
            log_success "$service: Healthy ✓"
        elif [ "$health" = "unhealthy" ]; then
            log_error "$service: Unhealthy ✗"
            
 # 
            docker inspect --format='{{json .State.Health}}' "$container_id" | tee -a "$STDOUT_LOG"
            
            add_issue "$service" "$service" "critical" \
 " unhealthy (healthcheck failed)" \
 "Healthcheck docker-compose.yaml" \
 " healthcheck "
        else
            log_warning "$service: Health status: $health"
        fi
        
 # 
        local status=$(docker-compose ps "$service" | tail -1 | awk '{print $(NF-1)}')
 log_info " : $status"
    done
}

# ============================================================================
# VERIFICATION 
# ============================================================================

check_resource_usage() {
 log_section "VERIFICATION "
    
 log_info " :"
    docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}\t{{.CPUPerc}}" 2>/dev/null | tee -a "$STDOUT_LOG"
    
 # 
    for service in "${SERVICES[@]}"; do
        local container_id=$(docker-compose ps -q "$service")
        
        if [ -z "$container_id" ]; then
            continue
        fi
        
 # 
        local mem_usage=$(docker stats --no-stream --format "{{.MemUsage}}" "$container_id" 2>/dev/null | cut -d'/' -f1)
        
        if [ ! -z "$mem_usage" ]; then
            log_info "$service: Memory = $mem_usage"
        fi
    done
}

# ============================================================================
# JSON 
# ============================================================================

generate_json_report() {
 log_section " JSON "
    
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
    
 log_success "JSON : $(basename $REPORT_FILE)"
}

# ============================================================================
# HUMAN-READABLE 
# ============================================================================

generate_human_report() {
 log_section " READABLE "
    
    cat > "$HUMAN_REPORT" << 'REPORT_EOF'
# 📊 CONTAINER LOGGING & ANALYSIS REPORT

** **: $(date)
****: 1.0

---

## 📋 

1. [ ](#)
2. [ ](#)
3. [ ](#)
4. [](#)

---

## 📌 {#}

| | |
|---------|----------|
| | ${#SERVICES[@]} |
| Found | ${#ISSUES[@]} |
| | $(grep -c '"severity": "critical"' <<< "$(printf '%s\n' "${ISSUES[@]}")" || echo 0) |
| | $(grep -c '"severity": "high"' <<< "$(printf '%s\n' "${ISSUES[@]}")" || echo 0) |

---

## 🔴 {#}

REPORT_EOF

 # 
    for issue in "${ISSUES[@]}"; do
        if echo "$issue" | grep -q '"severity": "critical"'; then
            local service=$(echo "$issue" | grep -o '"service": "[^"]*' | cut -d'"' -f4)
            local description=$(echo "$issue" | grep -o '"issue": "[^"]*' | cut -d'"' -f4)
            local location=$(echo "$issue" | grep -o '"location": "[^"]*' | cut -d'"' -f4)
            local fix=$(echo "$issue" | grep -o '"fix": "[^"]*' | cut -d'"' -f4)
            
            cat >> "$HUMAN_REPORT" << EOF

### ❌ $service: $description

****: $location 
****: $fix

---

EOF
        fi
    done
    
    cat >> "$HUMAN_REPORT" << 'REPORT_EOF'

## 🟡 {#}

REPORT_EOF

 # high 
    for issue in "${ISSUES[@]}"; do
        if echo "$issue" | grep -q '"severity": "high"'; then
            local service=$(echo "$issue" | grep -o '"service": "[^"]*' | cut -d'"' -f4)
            local description=$(echo "$issue" | grep -o '"issue": "[^"]*' | cut -d'"' -f4)
            local location=$(echo "$issue" | grep -o '"location": "[^"]*' | cut -d'"' -f4)
            local fix=$(echo "$issue" | grep -o '"fix": "[^"]*' | cut -d'"' -f4)
            
            cat >> "$HUMAN_REPORT" << EOF

### ⚠️  $service: $description

****: $location 
****: $fix

---

EOF
        fi
    done
    
 log_success "Readable : $(basename $HUMAN_REPORT)"
}

# ============================================================================
# CLEANUP
# ============================================================================

cleanup() {
 log_section " CLEANUP"
    
    log_info "Stopping docker-compose..."
    docker-compose down 2>&1 | tee -a "$STDOUT_LOG" || true
    
 log_success " "
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║      COMPREHENSIVE CONTAINER LOGGING FRAMEWORK v1.0        ║"
    echo "║                                                            ║"
 echo "║ Docker ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    mkdir -p "$LOG_DIR"
    
    cd "$(dirname "$0")/.." || exit 1
    
 # 
    check_docker_compose || exit 1
    start_docker_compose || exit 1
    collect_container_logs
    analyze_container_logs
    check_container_health
    check_resource_usage
    generate_json_report
    generate_human_report
    cleanup
    
 # 
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
 echo "║ ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
 echo "📁 :"
    echo "   JSON: $(basename $REPORT_FILE)"
    echo "   Readable: $(basename $HUMAN_REPORT)"
    echo "   All logs: $(basename $STDOUT_LOG)"
    echo ""
 echo "📊 :"
 echo " : ${#ISSUES[@]}"
 echo " : ${#SERVICES[@]}"
    echo ""
}

main "$@"
