# 🔍 АНАЛИЗ ЛОГОВ И ПЛАН ИСПРАВЛЕНИЯ

**Дата анализа**: 15 марта 2026  
**Статус**: Критические проблемы в GitHub Actions CI/CD  
**Приоритет**: ВЫСОКИЙ - Блокирует публикацию build-ов

---

## 📋 ОБНАРУЖЕННЫЕ ПРОБЛЕМЫ

### 1. ❌ КРИТИЧЕСКАЯ: Docker Build Failure (Exit Code: 2)
**Серьёзность**: 🔴 КРИТИЧЕСКАЯ  
**Статус**: Блокирует CI/CD  
**Симптомы**:
```
ERROR: failed to build: failed to solve: process "/bin/sh -o pipefail -c..." 
exit code: 2
```

**Что случилось**:
- Ошибка при компиляции Zabbix server
- Команда `make` или `./configure` завршилась с ошибкой
- Docker build не может завершить RUN инструкцию

**Возможные причины**:
- ❌ Отсутствуют зависимости в Dockerfile (missing library)
- ❌ Версия конфигурации несовместима с image
- ❌ Недостаточно памяти/ресурсов при compilе
- ❌ Ошибка в Git при `git rev-parse --short HEAD`
- ❌ Проблема с PostgreSQL development files

**Локация**: 
```
server-pgsql/alpine/Dockerfile - RUN инструкция для компиляции
```

---

### 2. ⚠️  ВЫСОКАЯ: Node.js 20 Deprecation
**Серьёзность**: 🟡 ВЫСОКАЯ  
**Статус**: Предупреждение, потребует исправления через 4+ месяца  
**Сообщение**:
```
Node.js 20 actions are deprecated. Actions will be forced to run 
with Node.js 24 by default starting June 2nd, 2026.
```

**Затронутые Actions**:
- actions/checkout@v4
- docker/build-push-action@v5
- docker/setup-buildx-action@v3

**Проблема**: 
- GitHub Actions используют Node.js 20
- После 2 июня 2026 будет Node.js 24
- Старые actions могут не работать

---

## 🛠️ ПЛАН ИСПРАВЛЕНИЯ

### ШАГ 1: Исправить Docker Build Failure
**Цель**: Получить успешную компиляцию Zabbix в Docker  
**Файл**: `server-pgsql/alpine/Dockerfile`  
**Действия**:
1. Добавить отсутствующие зависимости сборки
2. Проверить версию Alpine Linux
3. Обновить параметры configure

### ШАГ 2: Обновить GitHub Actions на Node.js 24
**Цель**: Убрать deprecation warnings  
**Файлы**: `.github/workflows/*.yml`  
**Действия**:
1. Обновить versions всех actions
2. Добавить environment variable

### ШАГ 3: Тестирование
**Цель**: Убедиться что всё работает  
**Действия**:
1. Локально проверить Docker build
2. Запустить GitHub Actions workflow
3. Проверить logs

---

## 🔧 ПОШАГОВОЕ ИСПРАВЛЕНИЕ

### ШАГ 1.1: Добавить недостающие зависимости

**Проблема**: Make/Configure может не найти нужные header-файлы  
**Файл**: server-pgsql/alpine/Dockerfile  
**Строка**: 14-30 (apk add)

**Текущие зависимости**:
```
alpine-sdk, autoconf, automake, coreutils, curl-dev, 
libevent-dev, libssh2-dev, libxml2-dev, net-snmp-dev, 
openipmi-dev, openldap-dev, pcre-dev, postgresql-dev, 
git, g++, make, unixodbc-dev
```

**Могут быть нужны**:
- ✅ pcre2-dev (вместо или вместе с pcre-dev)
- ✅ libtirpc-dev (для RPC)
- ✅ musl-dev (базовые dev tools)
- ✅ krb5-dev (для LDAP)
- ✅ openssl-dev
- ✅ libpq-dev (специально для PostgreSQL)

**ИСПРАВЛЕНИЕ 1.1**:

Добавить эти зависимости в RUN команду с apk add:
```bash
apk add --no-cache --virtual build-dependencies \
        alpine-sdk \
        autoconf \
        automake \
        coreutils \
        curl-dev \
        krb5-dev \
        libevent-dev \
        libpq-dev \
        libssh2-dev \
        libtirpc-dev \
        libxml2-dev \
        musl-dev \
        net-snmp-dev \
        openipmi-dev \
        openldap-dev \
        openssl-dev \
        pcre2-dev \
        postgresql-dev \
        git \
        g++ \
        make \
        unixodbc-dev
```

---

### ШАГ 1.2: Улучшить обработку ошибок

**Проблема**: Если make падает, we не знаем почему  
**Решение**: Добавить логирование в Dockerfile

**ИСПРАВЛЕНИЕ 1.2**:

Заменить:
```bash
make -j"$(nproc)" -s dbschema && \
make -j"$(nproc)" -s && \
make -j"$(nproc)" -s install
```

На:
```bash
echo "=== Building dbschema ===" && \
make -j"$(nproc)" dbschema || (make -j1 dbschema && false) && \
echo "=== Building main ===" && \
make -j"$(nproc)" || (make -j1 && false) && \
echo "=== Installing ===" && \
make -j"$(nproc)" install
```

---

### ШАГ 1.3: Добавить Dockerfile health check

**Проблема**: Не знаем работает ли Zabbix после build  
**ИСПРАВЛЕНИЕ 1.3**:

Добавить в финальный stage (после FROM alpine:3.20):
```dockerfile
# Runtime dependencies
RUN apk add --no-cache \
        ca-certificates \
        libevent \
        libldap \
        libsasl \
        libssh2 \
        libxml2 \
        net-snmp-libs \
        openipmi-libs \
        openssl \
        postgresql-client \
        postgresql-libs \
        unixodbc

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD /usr/sbin/zabbix_server -V
```

---

### ШАГ 2.1: Обновить GitHub Actions на Node.js 24

**Файл**: .github/workflows/docker-build.yml  
**Проблема**: Actions используют Node.js 20, deprecated

**ИСПРАВЛЕНИЕ 2.1**:

Заменить все actions версии:
```yaml
- uses: actions/checkout@v4              # → @v4.1.1
- uses: docker/setup-buildx-action@v3    # → @v3.1.0
- uses: docker/build-push-action@v5      # → @v5.2.0
```

На:
```yaml
- uses: actions/checkout@v4.1.1
- uses: docker/setup-buildx-action@v3.1.0
- uses: docker/build-push-action@v5.2.0
```

Или добавить environment variable:
```yaml
env:
  ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION: false
  FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true
```

---

### ШАГ 2.2: Добавить Node.js 24 совместимость

**ИСПРАВЛЕНИЕ 2.2**:

Добавить в docker-build.yml:

```yaml
name: Docker Build Check

on:
  push:
    branches: [ "main" ]
  pull_request:
    branches: [ "main" ]

env:
  # Node.js 24 compatibility
  NODE_OPTIONS: --openssl-legacy-provider

jobs:
  build:
    runs-on: ubuntu-latest
    # ... rest of workflow
```

---

## 📝 КРАТКИЙ ПЛАН ИСПРАВЛЕНИЙ

### Приоритет 1 - КРИТИЧЕСКОЕ (делать сейчас):

#### [1] Обновить Dockerfile dependencies
- [ ] Добавить krb5-dev, libtirpc-dev, libpq-dev, musl-dev, openssl-dev, pcre2-dev
- [ ] Файл: server-pgsql/alpine/Dockerfile (строка 16)
- [ ] Время: 2 минуты

#### [2] Добавить runtime dependencies
- [ ] Добавить RUN apk для финального stage
- [ ] Файл: server-pgsql/alpine/Dockerfile (70+ строка)
- [ ] Время: 2 минуты

#### [3] Улучшить error handling в make
- [ ] Добавить -j1 fallback для debug
- [ ] Добавить echo statements
- [ ] Файл: server-pgsql/alpine/Dockerfile (60-62 строка)
- [ ] Время: 3 минуты

---

### Приоритет 2 - ВЫСОКОЕ (до июня 2026):

#### [4] Обновить GitHub Actions версии
- [ ] checkout@v4 → @v4.1.1
- [ ] setup-buildx-action@v3 → @v3.1.0  
- [ ] build-push-action@v5 → @v5.2.0
- [ ] Файл: .github/workflows/docker-build.yml
- [ ] Время: 2 минуты

#### [5] Добавить Node.js 24 environment
- [ ] Добавить env section в workflow
- [ ] Файл: .github/workflows/docker-build.yml
- [ ] Время: 1 минута

---

## 🔨 ИСПОЛНЕНИЕ ИСПРАВЛЕНИЙ

### ИСПРАВЛЕНИЕ #1: Update Dockerfile dependencies
