#!/bin/bash

################################################################################
# 🧪 УПАКОВКА ДЛЯ АНАЛИЗА И ТЕСТИРОВАНИЯ
################################################################################
# Этот скрипт собирает всю информацию проекта для анализа
# Выполняется ДО запуска контейнеров
#
# ИСПОЛЬЗОВАНИЕ:
# bash prepare-analysis-package.sh
#
###############################################################################

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANALYSIS_DIR="$PROJECT_DIR/project-analysis-$(date +%Y%m%d_%H%M%S)"

# Цвета
CYAN='\033[0;36m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${CYAN}📦 Создание пакета анализа проекта...${NC}"
mkdir -p "$ANALYSIS_DIR"

# Копирование структуры проекта
echo -e "${CYAN}📂 Сохранение структуры проекта...${NC}"
tree "$PROJECT_DIR" -I 'analysis_*|.git|node_modules|__pycache__' > "$ANALYSIS_DIR/project_structure.txt" 2>/dev/null || find "$PROJECT_DIR" -type f -not -path '*/analysis_*' -not -path '*/.git/*' > "$ANALYSIS_DIR/files_list.txt"

# Копирование конфигураций
echo -e "${CYAN}⚙️  Сохранение конфигураций...${NC}"
mkdir -p "$ANALYSIS_DIR/configs"

cp -r "$PROJECT_DIR/docker-compose.yaml" "$ANALYSIS_DIR/configs/" 2>/dev/null || true
for file in .env_* .POSTGRES_*; do
    if [ -f "$PROJECT_DIR/${file}.example" ]; then
        cp "$PROJECT_DIR/${file}.example" "$ANALYSIS_DIR/configs/${file}.example"
    fi
done

# Копирование Dockerfiles
echo -e "${CYAN}🐳 Сохранение Dockerfiles...${NC}"
find "$PROJECT_DIR" -name "Dockerfile" -exec cp {} "$ANALYSIS_DIR/configs/$(echo {} | tr '/' '_')" \;

# Копирование скриптов
echo -e "${CYAN}🔧 Сохранение скриптов...${NC}"
mkdir -p "$ANALYSIS_DIR/scripts"
cp -r "$PROJECT_DIR/scripts"/* "$ANALYSIS_DIR/scripts/" 2>/dev/null || true

# Создание README для анализа
echo -e "${CYAN}📝 Создание справочной документации...${NC}"
cat > "$ANALYSIS_DIR/README_ANALYSIS.md" << 'EOF'
# 📊 Пакет Анализа Проекта Zabbix

Этот пакет содержит полную информацию о структуре и конфигурации проекта Zabbix.

## 📋 Содержимое

- `project_structure.txt` -树形структура всех файлов проекта
- `configs/` - Все конфигурационные файлы и Dockerfiles
- `scripts/` - Утилиты и вспомогательные скрипты
- `DEPLOYMENT_INSTRUCTIONS.md` - Полные инструкции по развертыванию

## 🚀 Быстрый старт

на машине с Podman/Docker:

```bash
# 1. Переход в директорию проекта
cd /path/to/zabbix

# 2. Запуск полной пересборки
bash scripts/rebuild-from-scratch.sh

# 3. Проверка статуса
podman ps

# 4. Просмотр логов
cat analysis_logs/zabbix-server-pgsql.log
```

## 🔍 Проверка

### Доступность сервисов
- Web: http://127.0.0.1 (логин: Admin/zabbix)
- Server API: 127.0.0.1:10051
- PostgreSQL: 127.0.0.1:5432

### Сетевая архитектура
- `zbx_net_backend` - сеть для бекенд сервисов
- `zbx_net_frontend` - сеть для фронтенд сервисов

EOF

# Статистика пакета
echo -e "${GREEN}✓ Пакет анализа создан: $ANALYSIS_DIR${NC}"
echo -e "${GREEN}  Размер: $(du -sh "$ANALYSIS_DIR" | cut -f1)${NC}"

exit 0
