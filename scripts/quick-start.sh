#!/bin/bash
#
# ⚡ QUICK START GUIDE - 3 MINUTE SETUP
# Быстрый старт тестирования Docker build
#

set -euo pipefail

# Цвета
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║          QUICK START: BUILD ANALYSIS & TESTING             ║"
echo "║                  Быстрый старт (3 минуты)                 ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# ШАГИ
echo -e "${YELLOW}⏱️  Этап 0: Проверка (1 минута)${NC}"
echo "───────────────────────────────────────────"

# Проверка диска
free_space=$(df / | tail -1 | awk '{print $4}')
if [ "$free_space" -gt 10485760 ]; then
    echo -e "${GREEN}✓${NC} Свободно места: $(numfmt --to=iec $free_space 2>/dev/null || echo $free_space)"
else
    echo -e "${RED}✗${NC} Недостаточно места! Требуется 10GB"
    exit 1
fi

# Проверка памяти
free_mem=$(free -b | grep Mem | awk '{print $7}')
if [ "$free_mem" -gt 2147483648 ]; then
    echo -e "${GREEN}✓${NC} Свободно памяти: $(numfmt --to=iec $free_mem 2>/dev/null || echo $free_mem)"
else
    echo -e "${YELLOW}!${NC} Память < 2GB (может быть медленнее)"
fi

# Проверка Docker
if docker ps &> /dev/null; then
    docker_v=$(docker --version | awk '{print $3}' | cut -d',' -f1)
    echo -e "${GREEN}✓${NC} Docker версия: $docker_v"
else
    echo -e "${RED}✗${NC} Docker не запущен"
    exit 1
fi

echo ""

# БЫСТРЫЙ ВЫБОР
echo -e "${YELLOW}📋 Выберите что запустить:${NC}"
echo "───────────────────────────────────────────"
echo ""
echo "1) Быстрый тест (5 минут) - базовая проверка"
echo "2) Полный анализ (30+ минут) - сборка Docker + анализ"
echo "3) Запустить оба (40+ минут) - полное тестирование"
echo "4) Только Docker build (15 минут) - просто собрать"
echo ""
echo -n "Выберите (1-4): "
read -r choice

cd /var/home/sanya/zabbix

case $choice in
    1)
        echo ""
        echo -e "${BLUE}🚀 Быстрый тест (5 минут)${NC}"
        echo "───────────────────────────────────────────"
        echo ""
        chmod +x scripts/test-docker-build.sh
        echo -e "${YELLOW}Запуск базовых проверок...${NC}"
        scripts/test-docker-build.sh
        
        echo ""
        echo -e "${GREEN}✅ Тест завершен!${NC}"
        echo "Результаты: test-results/test_report_*.md"
        ;;
        
    2)
        echo ""
        echo -e "${BLUE}📊 Полный анализ (30+ минут)${NC}"
        echo "───────────────────────────────────────────"
        echo ""
        echo -e "${YELLOW}⚠️  Это займет время! Ждите завершения...${NC}"
        echo ""
        chmod +x scripts/collect-and-analyze-logs.sh
        scripts/collect-and-analyze-logs.sh
        
        echo ""
        echo -e "${GREEN}✅ Анализ завершен!${NC}"
        echo "Результаты в build-logs/"
        echo "  • analysis_*.log"
        echo "  • detailed_report_*.md"
        ;;
        
    3)
        echo ""
        echo -e "${BLUE}🔥 Полное тестирование (40+ минут)${NC}"
        echo "───────────────────────────────────────────"
        echo ""
        
        chmod +x scripts/test-docker-build.sh
        chmod +x scripts/collect-and-analyze-logs.sh
        
        echo -e "${YELLOW}Фаза 1: Полный анализ...${NC}"
        scripts/collect-and-analyze-logs.sh
        
        echo ""
        echo -e "${YELLOW}Фаза 2: Тестирование...${NC}"
        scripts/test-docker-build.sh
        
        echo ""
        echo -e "${GREEN}✅ Полное тестирование завершено!${NC}"
        echo "Результаты:"
        echo "  • build-logs/analysis_*.log"
        echo "  • build-logs/detailed_report_*.md"
        echo "  • test-results/test_report_*.md"
        ;;
        
    4)
        echo ""
        echo -e "${BLUE}🐳 Docker build (15 минут)${NC}"
        echo "───────────────────────────────────────────"
        echo ""
        
        echo -e "${YELLOW}Запуск Docker build...${NC}"
        docker build \
            --progress=plain \
            -f server-pgsql/alpine/Dockerfile \
            -t zabbix-server:quick-test . 2>&1 | tee docker-build.log
        
        echo ""
        if docker image inspect zabbix-server:quick-test &>/dev/null; then
            echo -e "${GREEN}✅ Docker build успешен!${NC}"
            
            # Быстрая проверка healthcheck
            echo ""
            echo -e "${YELLOW}Проверка healthcheck...${NC}"
            if docker run --rm zabbix-server:quick-test /usr/sbin/zabbix_server -V; then
                echo -e "${GREEN}✓ Healthcheck успешен${NC}"
            else
                echo -e "${RED}✗ Healthcheck ошибка${NC}"
            fi
        else
            echo -e "${RED}✗ Build ошибка!${NC}"
            echo "Смотреть: docker-build.log"
            exit 1
        fi
        ;;
        
    *)
        echo -e "${RED}✗ Неверный выбор${NC}"
        exit 1
        ;;
esac

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                      ЗАВЕРШЕНО!                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${GREEN}📖 Дальнейшие шаги:${NC}"
echo ""
echo "1. Просмотреть результаты:"
echo "   ${BLUE}cat build-logs/analysis_*.log${NC}"
echo "   ${BLUE}cat test-results/test_report_*.md${NC}"
echo ""
echo "2. Если все успешно - upload на GitHub:"
echo "   ${BLUE}git push origin master${NC}"
echo ""
echo "3. Проверить GitHub Actions:"
echo "   ${BLUE}https://github.com/suraiya8239/Zabbix_latest/actions${NC}"
echo ""
echo -e "${YELLOW}📚 Дополнительные ресурсы:${NC}"
echo "   • COMPREHENSIVE_ANALYSIS_AND_PLAN.md - полный анализ"
echo "   • IMPLEMENTATION_GUIDE.md - пошаговое руководство"
echo "   • BUILD_FIXES_REPORT.md - отчет об исправлениях"
echo ""
