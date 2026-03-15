#!/bin/bash
#
# ⚡ QUICK START GUIDE - 3 MINUTE SETUP
# Docker build
#

set -euo pipefail

# 
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║          QUICK START: BUILD ANALYSIS & TESTING             ║"
echo "║ (3 ) ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# 
echo -e "${YELLOW}⏱️ 0: Checking (1 )${NC}"
echo "───────────────────────────────────────────"

# Checking 
free_space=$(df / | tail -1 | awk '{print $4}')
if [ "$free_space" -gt 10485760 ]; then
 echo -e "${GREEN}✓${NC} : $(numfmt --to=iec $free_space 2>/dev/null || echo $free_space)"
else
 echo -e "${RED}✗${NC} ! 10GB"
    exit 1
fi

# Checking 
free_mem=$(free -b | grep Mem | awk '{print $7}')
if [ "$free_mem" -gt 2147483648 ]; then
 echo -e "${GREEN}✓${NC} : $(numfmt --to=iec $free_mem 2>/dev/null || echo $free_mem)"
else
 echo -e "${YELLOW}!${NC} < 2GB ( )"
fi

# Checking Docker
if docker ps &> /dev/null; then
    docker_v=$(docker --version | awk '{print $3}' | cut -d',' -f1)
 echo -e "${GREEN}✓${NC} Docker : $docker_v"
else
 echo -e "${RED}✗${NC} Docker "
    exit 1
fi

echo ""

# 
echo -e "${YELLOW}📋 :${NC}"
echo "───────────────────────────────────────────"
echo ""
echo "1) (5 ) - "
echo "2) (30+ ) - Docker + "
echo "3) (40+ ) - "
echo "4) Docker build (15 ) - "
echo ""
echo -n " (1-4): "
read -r choice

cd /var/home/sanya/zabbix

case $choice in
    1)
        echo ""
 echo -e "${BLUE}🚀 (5 )${NC}"
        echo "───────────────────────────────────────────"
        echo ""
        chmod +x scripts/test-docker-build.sh
 echo -e "${YELLOW}Starting ...${NC}"
        scripts/test-docker-build.sh
        
        echo ""
 echo -e "${GREEN}✅ !${NC}"
 echo ": test-results/test_report_*.md"
        ;;
        
    2)
        echo ""
 echo -e "${BLUE}📊 (30+ )${NC}"
        echo "───────────────────────────────────────────"
        echo ""
 echo -e "${YELLOW}⚠️ ! ...${NC}"
        echo ""
        chmod +x scripts/collect-and-analyze-logs.sh
        scripts/collect-and-analyze-logs.sh
        
        echo ""
 echo -e "${GREEN}✅ !${NC}"
 echo " build-logs/"
        echo "  • analysis_*.log"
        echo "  • detailed_report_*.md"
        ;;
        
    3)
        echo ""
 echo -e "${BLUE}🔥 (40+ )${NC}"
        echo "───────────────────────────────────────────"
        echo ""
        
        chmod +x scripts/test-docker-build.sh
        chmod +x scripts/collect-and-analyze-logs.sh
        
 echo -e "${YELLOW} 1: ...${NC}"
        scripts/collect-and-analyze-logs.sh
        
        echo ""
 echo -e "${YELLOW} 2: ...${NC}"
        scripts/test-docker-build.sh
        
        echo ""
 echo -e "${GREEN}✅ !${NC}"
 echo ":"
        echo "  • build-logs/analysis_*.log"
        echo "  • build-logs/detailed_report_*.md"
        echo "  • test-results/test_report_*.md"
        ;;
        
    4)
        echo ""
 echo -e "${BLUE}🐳 Docker build (15 )${NC}"
        echo "───────────────────────────────────────────"
        echo ""
        
        echo -e "${YELLOW}Starting Docker build...${NC}"
        docker build \
            --progress=plain \
            -f server-pgsql/alpine/Dockerfile \
            -t zabbix-server:quick-test . 2>&1 | tee docker-build.log
        
        echo ""
        if docker image inspect zabbix-server:quick-test &>/dev/null; then
 echo -e "${GREEN}✅ Docker build !${NC}"
            
 # healthcheck
            echo ""
            echo -e "${YELLOW}Checking healthcheck...${NC}"
            if docker run --rm zabbix-server:quick-test /usr/sbin/zabbix_server -V; then
 echo -e "${GREEN}✓ Healthcheck ${NC}"
            else
 echo -e "${RED}✗ Healthcheck ${NC}"
            fi
        else
 echo -e "${RED}✗ Build !${NC}"
 echo ": docker-build.log"
            exit 1
        fi
        ;;
        
    *)
 echo -e "${RED}✗ ${NC}"
        exit 1
        ;;
esac

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║ ! ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${GREEN}📖 :${NC}"
echo ""
echo "1. :"
echo "   ${BLUE}cat build-logs/analysis_*.log${NC}"
echo "   ${BLUE}cat test-results/test_report_*.md${NC}"
echo ""
echo "2. - upload GitHub:"
echo "   ${BLUE}git push origin master${NC}"
echo ""
echo "3. GitHub Actions:"
echo "   ${BLUE}https://github.com/suraiya8239/Zabbix_latest/actions${NC}"
echo ""
echo -e "${YELLOW}📚 :${NC}"
echo " • COMPREHENSIVE_ANALYSIS_AND_PLAN.md - "
echo " • IMPLEMENTATION_GUIDE.md - "
echo " • BUILD_FIXES_REPORT.md - "
echo ""
