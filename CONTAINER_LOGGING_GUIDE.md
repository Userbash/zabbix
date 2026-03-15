# 📊 COMPREHENSIVE CONTAINER LOGGING & ANALYSIS SYSTEM

**Version**: 3.0  
**Date**: 2026-03-15  
**Status**: Production Ready ✅  

---

## 📌 OVERVIEW

Это полная система логирования для Zabbix контейнеров с integrated testing framework и детальной аналитикой проблем.

### 🎯 Основные возможности

| Компонент | Описание | Статус |
|-----------|---------|--------|
| **Container Logging** | Сбор логов из всех контейнеров с анализом stdout | ✅ |
| **Comprehensive Testing** | ShellCheck, BATS, Pytest, YAMLLint, JQ | ✅ |
| **Master Analysis** | Объединенный анализ всех проблем | ✅ |
| **Stdout Capture** | Полная регистрация stdout/stderr | ✅ |
| **Health Alerts** | Мониторинг healthchecks | ✅ |
| **Detailed Reports** | JSON + Markdown отчеты | ✅ |

---

## 🚀 БЫСТРЫЙ СТАРТ

### 1️⃣ Сделать скрипты исполняемыми

```bash
chmod +x scripts/*.sh
```

### 2️⃣ Запустить быстрый анализ

```bash
bash scripts/master-analysis.sh check
```

### 3️⃣ Получить полный отчет

```bash
bash scripts/master-analysis.sh all
```

---

## 📁 СТРУКТУРА СКРИПТОВ

### 1. `container-logging-framework.sh` (19 KB)

Полный фреймворк логирования для всех контейнеров.

**Возможности:**
- Проверка конфигурации docker-compose
- Запуск всех контейнеров
- Сбор логов из каждого контейнера
- Анализ на ошибки (ERROR, WARNING, OOM, Connection errors, etc.)
- Проверка healthchecks
- Контроль использования ресурсов
- Генерирование JSON и readable отчетов

**Использование:**
```bash
./scripts/container-logging-framework.sh
```

**Выход:**
- `container-logs/container_report_TIMESTAMP.json` - Структурированные результаты
- `container-logs/container_issues_TIMESTAMP.md` - Readable отчет
- `container-logs/all_container_stdout_TIMESTAMP.log` - Все логи

**Время выполнения**: 15-25 минут

---

### 2. `comprehensive-test-framework.sh` (16 KB)

Фреймворк тестирования с использованием external libraries.

**Использованные инструменты:**

| Инструмент | Назначение | Проверяет |
|-----------|-----------|----------|
| **ShellCheck** | Shell скрипты | Синтаксис, best practices |
| **YAMLLINT** | YAML файлы | docker-compose.yaml валидация |
| **BATS** | Bash тесты | docker-compose, Docker |
| **Pytest** | Python тесты | Services, Dockerfiles, конфиги |
| **JQ** | JSON | JSON файлы |

**Использование:**
```bash
./scripts/comprehensive-test-framework.sh
```

**Выход:**
- `test-results/test_report_TIMESTAMP.json` - JSON результаты
- `test-results/test_report_TIMESTAMP.md` - Readable отчет
- `test-results/docker-compose.yamllint.txt` - YAML ошибки
- `test-results/bats_results.txt` - BATS результаты
- `test-results/pytest_results.txt` - Pytest результаты

**Время выполнения**: 10-15 минут

---

### 3. `master-analysis.sh` (20 KB)

Объединенный анализ всех аспектов.

**Команды:**

```bash
# 1. Полный анализ всего
./scripts/master-analysis.sh all

# 2. Только анализ логирования
./scripts/master-analysis.sh logs

# 3. Только тестирование
./scripts/master-analysis.sh tests

# 4. Быстрая проверка статуса
./scripts/master-analysis.sh check

# 5. Автоматическое исправление (в разработке)
./scripts/master-analysis.sh repair
```

**Выход:**
- `reports/master_analysis_TIMESTAMP.json` - Все проблемы в JSON
- `reports/master_analysis_TIMESTAMP.md` - Детальный отчет
- `reports/` - Все результаты в одной папке

---

## 🔍 ИНТЕГРАЦИЯ В DOCKER-COMPOSE

### ✅ Добавленное логирование

Каждый сервис теперь имеет конфигурацию логирования:

```yaml
logging:
  driver: json-file
  options:
    max-size: '10m'      # Максимум 10MB на файл
    max-file: '5'        # Хранить 5 файлов (50MB всего)
    labels: 'service=service-name'
```

### ✅ Добавленные healthchecks

Каждый критический сервис имеет healthcheck:

```yaml
healthcheck:
  test: ["CMD", "nc", "-z", "localhost", "10051"]
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 30s
```

### ✅ Stdout обработка

- Все stdout автоматически логируется на уровне Docker
- Размер логов контролируется (ротация)
- Можно просмотреть через `docker logs`

---

## 🔐 СБОР ЛОГИРОВАНИЯ

### Методы сбора логов

#### 1. Через Docker API (Рекомендуется)
```bash
docker-compose logs service-name      # Последние логи
docker-compose logs -f service-name   # Follow режим
docker-compose logs --tail 100 service-name  # Последние 100 строк
```

#### 2. Через filesystem
```bash
# Найти log файлы
docker inspect --format='{{.LogPath}}' container-id

# Размер
du -h /var/lib/docker/containers/*/
```

#### 3. Через наш фреймворк
```bash
./scripts/container-logging-framework.sh
```

---

## 📊 АНАЛИЗ ОТЧЕТОВ

### Типы найденных проблем

1. **ERROR messages** - Критические ошибки
2. **WARNING messages** - Предупреждения
3. **OOM/Memory** - Нехватка памяти
4. **Connection errors** - Ошибки соединения
5. **Port conflicts** - Порт уже используется
6. **Startup failures** - Контейнер не стартует
7. **Build issues** - Проблемы при сборке

### Интерпретация результатов

#### JSON отчет
```json
{
  "issues": [
    {
      "service": "postgres",
      "severity": "high",
      "issue": "OOM killed",
      "location": "memory configuration",
      "fix": "Увеличить mem_limit"
    }
  ]
}
```

#### Markdown отчет
```markdown
### ❌ postgres: Out of Memory

**Место**: docker-compose.yaml  
**Решение**: Увеличить лимит памяти в файле
```

---

## 🛠️ РЕШЕНИЕ РАСПРОСТРАНЕННЫХ ПРОБЛЕМ

### Проблема 1: Container не стартует

**Признаки:**
```
ERROR in logs: startup failed
Status: exited (139)
```

**Решение:**
```bash
# 1. Проверить логи
docker-compose logs service-name

# 2. Увеличить память
# Обновить в docker-compose.yaml:
deploy:
  resources:
    limits:
      memory: 1G  # Увеличить

# 3. Перестроить
docker-compose build --no-cache service-name

# 4. Перезапустить
docker-compose down
docker-compose up -d
```

### Проблема 2: Ошибки соединения

**Признаки:**
```
ERROR: connection refused
ERROR: no such host
```

**Решение:**
```bash
# 1. Проверить сеть
docker network ls

# 2. Проверить зависимости в docker-compose.yaml
depends_on:
  - postgres  # Убедиться что зависимости правильные

# 3. Проверить порты
docker-compose ps

# 4. Перезапустить сервис
docker-compose restart service-name
```

### Проблема 3: Большие логи

**Признаки:**
```
/var/lib/docker/containers/...: 5G (too large)
```

**Решение:**
```bash
# 1. Проверить конфигурацию логирования в docker-compose.yaml
logging:
  driver: json-file
  options:
    max-size: '5m'   # Менее 5MB
    max-file: '3'    # Только 3 файла

# 2. Очистить старые логи
docker system prune --all

# 3. Пересоздать контейнеры
docker-compose down
docker-compose up -d
```

---

## 📈 CONTINUOUS MONITORING

### Включить регулярный мониторинг

#### Вариант 1: Cronjob

```bash
# Анализ каждый день в 3 утра
0 3 * * * /path/to/scripts/master-analysis.sh all >> /var/log/zabbix-analysis.log 2>&1
```

#### Вариант 2: Systemd timer

```ini
[Unit]
Description=Zabbix Container Analysis
After=docker.service

[Timer]
OnCalendar=daily
OnCalendar=03:00
Persistent=true

[Install]
WantedBy=timers.target
```

#### Вариант 3: GitHub Actions

```yaml
name: Container Analysis
on:
  schedule:
    - cron: '0 3 * * *'
    
jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run analysis
        run: bash scripts/master-analysis.sh all
      - name: Upload reports
        uses: actions/upload-artifact@v3
        with:
          name: analysis-reports
          path: reports/
```

---

## 🎯 МЕТРИКИ МОНИТОРИНГА

### Ключевые метрики для отслеживания

```
┌─────────────────────────────────────────────────┐
│ МЕТРИКА              │ НОРМА     │警告 │ CRITICAL │
├─────────────────────────────────────────────────┤
│ Container Health     │ healthy   │ -    │ unhealthy│
│ Memory Usage         │ <70%      │ >70% │ >90%     │
│ CPU Usage            │ <50%      │ >50% │ >80%     │
│ Log Size             │ <100MB    │ >200│ >1GB     │
│ Restart Count        │ 0         │ >2  │ >5       │
│ Health Retries       │ 0         │ >1  │ >3       │
└─────────────────────────────────────────────────┘
```

---

## 🔧 КОНФИГУРАЦИЯ

### Изменить size логирования

Обновить `docker-compose.yaml`:
```yaml
logging:
  options:
    max-size: '5m'   # Размер до 5MB
    max-file: '3'    # Хранить 3 файла (15MB всего)
```

### Изменить интервал healthcheck

```yaml
healthcheck:
  interval: 30s      # Проверять каждые 30 секунд
  timeout: 10s       # Таймаут 10 секунд
  retries: 3         # 3 попытки перед unhealthy
  start_period: 40s  # Ждать 40 сек перед началом
```

---

## 📝 ЛОГИРОВАНИЕ EVENTS

### Event logs расположение

```
container-logs/
├── server_full_20260315_143022.log
├── web_full_20260315_143022.log
├── postgres_full_20260315_143022.log
├── container_report_20260315_143022.json
└── container_issues_20260315_143022.md
```

### Форматы логов

#### JSON Log Format (Docker json-file driver)
```json
{
  "log": "INFO: Process started\n",
  "stream": "stdout",
  "time": "2026-03-15T14:30:22.123456789Z"
}
```

#### Raw Text (docker logs)
```
INFO: Process started
ERROR: Connection failed
WARNING: Low memory
```

---

## ✅ CHECKLIST

### Перед запуском

- [ ] All scripts are executable: `chmod +x scripts/*.sh`
- [ ] Docker-compose installed: `docker-compose --version`
- [ ] Docker running: `docker ps`
- [ ] Ports available (10051, 8080, 3000, 5432, etc.)
- [ ] Disk space available: `df -h`

### После первого анализа

- [ ] Проверить `master_analysis_*.md` отчет
- [ ] Исправить критические проблемы
- [ ] Перезапустить контейнеры
- [ ] Запустить анализ снова
- [ ] Убедиться что все пройдено

### Регулярно

- [ ] Проверять логи: `docker-compose logs`
- [ ] Мониторить ресурсы: `docker stats`
- [ ] Запускать анализ раз в неделю
- [ ] Архивировать старые логи

---

## 🤝 SUPPORT

### Команда помощи

```bash
# Помощь по скриптам
./scripts/master-analysis.sh --help

# Проверить версию Docker
docker version

# Проверить конфигурацию
docker-compose config

# Получить информацию о контейнере
docker inspect container-name
```

### Логирование проблем

```bash
# Собрать всю диагностику
./scripts/master-analysis.sh all

# Экспортировать отчет
cat reports/master_analysis_*.json > /tmp/report.json

# Отправить на анализ
curl -F "file=@/tmp/report.json" https://support.example.com/analyze
```

---

## 📚 ДОПОЛНИТЕЛЬНЫЕ РЕСУРСЫ

- [Docker Logging Documentation](https://docs.docker.com/config/containers/logging/)
- [Docker Compose Logging](https://docs.docker.com/compose/compose-file/compose-file-v3/#logging)
- [Healthcheck Docs](https://docs.docker.com/engine/reference/builder/#healthcheck)
- [YAMLLint](https://www.yamllint.com/)
- [ShellCheck](https://www.shellcheck.net/)
- [BATS Documentation](https://github.com/bats-core/bats-core)

---

## 🎉 SUCCESS METRICS

После реализации этого фреймворка вы получите:

✅ **Visibility** - Полная видимость всех логов и проблем  
✅ **Automation** - Автоматический анализ всех сервисов  
✅ **Prevention** - Раннее обнаружение проблем  
✅ **Documentation** - Кристально ясные отчеты  
✅ **Recommendations** - Точные рекомендации по исправлению  
✅ **Monitoring** - Постоянный контроль здоровья  

**Результат**: Надежная и отказоустойчивая Zabbix система!

---

**Last Updated**: 2026-03-15  
**Version**: 3.0  
**Status**: Production Ready ✅
