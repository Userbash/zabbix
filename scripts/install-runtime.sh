#!/bin/bash

################################################################################
# 🔒 БЕЗОПАСНАЯ УСТАНОВКА PODMAN/DOCKER С МИНИМАЛЬНЫМИ ПРИВИЛЕГИЯМИ
################################################################################
# Скрипт автоматически:
# 1. Определяет текущее окружение (хост, контейнер, Flatpak, WSL2, etc)
# 2. Проверяет наличие Podman/Docker
# 3. Устанавливает необходимые компоненты с минимальными правами
# 4. Конфигурирует безопасные параметры
# 5. Проверяет возможность запуска контейнеров
#
# ИСПОЛЬЗОВАНИЕ:
#   bash install-runtime.sh [--minimal] [--user] [--system]
#
# ОПЦИИ:
#   --minimal   - установка с минимальными возможностями
#   --user      - установка в пользовательском режиме (без sudo)
#   --system    - полная системная установка
#
################################################################################

set -euo pipefail

# ============================================================================
# КОНФИГУРАЦИЯ И ПЕРЕМЕННЫЕ
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="${PROJECT_ROOT}/.install_runtime.log"
INSTALL_MODE="${1:-auto}"  # auto, minimal, user, system
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# ============================================================================
# ПЕРЕМЕННЫЕ СОСТОЯНИЯ
# ============================================================================

DETECTED_OS=""
DETECTED_DISTRO=""
DETECTED_ENV="native"  # native, flatpak, wsl2, docker, vm, etc
HAS_PODMAN=false
HAS_DOCKER=false
HAS_PODMAN_COMPOSE=false
HAS_DOCKER_COMPOSE=false
NEEDS_INSTALL=false
IS_ROOT=false
CAN_USE_SUDO=false
INSTALL_METHOD=""

# ============================================================================
# ФУНКЦИИ ЛОГИРОВАНИЯ
# ============================================================================

log_init() {
    {
        echo "╔════════════════════════════════════════════════════════════════╗"
        echo "║  🔒 БЕЗОПАСНАЯ УСТАНОВКА PODMAN/DOCKER С МИНИМАЛЬНЫМИ ПРАВАМИ  ║"
        echo "╚════════════════════════════════════════════════════════════════╝"
        echo ""
        echo "Дата и время: $(date)"
        echo "Режим установки: $INSTALL_MODE"
        echo "Пользователь: $(whoami)"
        echo ""
    } | tee "$LOG_FILE"
}

log_header() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║ $1${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo "$1" >> "$LOG_FILE"
}

log_section() {
    echo -e "\n${MAGENTA}▶ $1${NC}"
    echo "--- $1" >> "$LOG_FILE"
}

log_info() { 
    echo -e "${BLUE}ℹ $1${NC}"
    echo "[$1]" >> "$LOG_FILE"
}

log_success() { 
    echo -e "${GREEN}✓ $1${NC}"
    echo "[✓] $1" >> "$LOG_FILE"
}

log_error() { 
    echo -e "${RED}✗ $1${NC}"
    echo "[✗] $1" >> "$LOG_FILE"
}

log_warning() { 
    echo -e "${YELLOW}⚠ $1${NC}"
    echo "[!] $1" >> "$LOG_FILE"
}

# ============================================================================
# ОПРЕДЕЛЕНИЕ ОКРУЖЕНИЯ И ОС
# ============================================================================

detect_environment() {
    log_section "ОПРЕДЕЛЕНИЕ ОКРУЖЕНИЯ И ОС"
    
    # Определение ОС
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        DETECTED_OS="Linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        DETECTED_OS="macOS"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        DETECTED_OS="Windows"
    else
        DETECTED_OS="Unknown"
    fi
    
    log_info "ОС: $DETECTED_OS"
    
    # Определение дистрибутива Linux
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DETECTED_DISTRO="$NAME"
        log_info "Дистрибутив: $DETECTED_DISTRO"
    fi
    
    # Определение окружения
    if [ -f /.dockerenv ]; then
        DETECTED_ENV="docker"
        log_warning "Определено: Docker контейнер"
    elif [ -f /run/.containerenv ]; then
        DETECTED_ENV="podman"
        log_warning "Определено: Podman контейнер"
    elif grep -qi "microsoft" /proc/version 2>/dev/null; then
        DETECTED_ENV="wsl2"
        log_warning "Определено: Windows Subsystem for Linux 2"
    elif grep -qi "flatpak" /proc/self/filesystem 2>/dev/null; then
        DETECTED_ENV="flatpak"
        log_warning "Определено: Flatpak окружение"
    else
        DETECTED_ENV="native"
        log_success "Определено: Нативное окружение"
    fi
    
    # Проверка прав
    if [ "$EUID" -eq 0 ]; then
        IS_ROOT=true
        log_info "Запущено с правами root"
    else
        IS_ROOT=false
        if sudo -n true 2>/dev/null; then
            CAN_USE_SUDO=true
            log_success "Доступны права sudo (без пароля)"
        else
            log_warning "Нет прав sudo"
        fi
    fi
}

# ============================================================================
# ПРОВЕРКА НАЛИЧИЯ RUNTIME
# ============================================================================

check_runtime_installed() {
    log_section "ПРОВЕРКА НАЛИЧИЯ RUNTIME"
    
    if command -v podman &> /dev/null; then
        HAS_PODMAN=true
        PODMAN_VERSION=$(podman --version)
        log_success "Podman установлен: $PODMAN_VERSION"
    else
        log_info "Podman не установлен"
    fi
    
    if command -v docker &> /dev/null; then
        HAS_DOCKER=true
        DOCKER_VERSION=$(docker --version)
        log_success "Docker установлен: $DOCKER_VERSION"
    else
        log_info "Docker не установлен"
    fi
    
    if command -v podman-compose &> /dev/null; then
        HAS_PODMAN_COMPOSE=true
        PODMAN_COMPOSE_VERSION=$(podman-compose --version)
        log_success "Podman Compose установлен: $PODMAN_COMPOSE_VERSION"
    else
        log_info "Podman Compose не установлен"
    fi
    
    if command -v docker-compose &> /dev/null; then
        HAS_DOCKER_COMPOSE=true
        DOCKER_COMPOSE_VERSION=$(docker-compose --version)
        log_success "Docker Compose установлен: $DOCKER_COMPOSE_VERSION"
    else
        log_info "Docker Compose не установлен"
    fi
    
    # Определение требуемой установки
    if ! ($HAS_PODMAN || $HAS_DOCKER); then
        NEEDS_INSTALL=true
        log_warning "Требуется установка runtime"
    else
        NEEDS_INSTALL=false
        log_success "Runtime уже установлен"
    fi
}

# ============================================================================
# УСТАНОВКА ДЛЯ РАЗЛИЧНЫХ ДИСТРИБУТИВОВ
# ============================================================================

install_for_fedora() {
    log_section "УСТАНОВКА ДЛЯ FEDORA"
    
    if [ "$INSTALL_MODE" = "user" ] || [ "$INSTALL_MODE" = "minimal" ]; then
        log_info "Пользовательская установка Podman (без привилегий)"
        
        # Проверка пакета в пользовательском репозитории
        if dnf search --userinstall podman &>/dev/null; then
            log_info "Проверка возможности пользовательской установки"
            
            # Установка в локальный префикс
            if command -v pip &>/dev/null; then
                log_info "Использование pip для установки podman-compose"
                pip install --user podman-compose 2>&1 | tee -a "$LOG_FILE"
                HAS_PODMAN_COMPOSE=true
                log_success "Podman Compose установлен через pip"
            fi
        fi
    fi
    
    if [ "$IS_ROOT" ] || [ "$CAN_USE_SUDO" ]; then
        log_info "Системная установка Podman"
        
        SUDO_CMD=""
        if ! [ "$IS_ROOT" ]; then
            SUDO_CMD="sudo"
        fi
        
        log_info "Обновление репозиториев"
        $SUDO_CMD dnf update -y 2>&1 | tail -5 | tee -a "$LOG_FILE"
        
        log_info "Установка Podman с базовыми компонентами"
        $SUDO_CMD dnf install -y \
            podman \
            podman-compose \
            containers-common \
            slirp4netns 2>&1 | tail -10 | tee -a "$LOG_FILE"
        
        HAS_PODMAN=true
        HAS_PODMAN_COMPOSE=true
        INSTALL_METHOD="dnf"
        
        log_success "Podman и Podman Compose установлены через dnf"
    else
        log_error "Требуются права sudo или root для системной установки"
        return 1
    fi
}

install_for_ubuntu_debian() {
    log_section "УСТАНОВКА ДЛЯ UBUNTU/DEBIAN"
    
    if [ "$INSTALL_MODE" = "user" ] || [ "$INSTALL_MODE" = "minimal" ]; then
        log_info "Пользовательская установка"
        
        if command -v pip &>/dev/null; then
            log_info "Использование pip для установки podman-compose"
            pip install --user podman-compose 2>&1 | tee -a "$LOG_FILE"
            HAS_PODMAN_COMPOSE=true
        fi
    fi
    
    if [ "$IS_ROOT" ] || [ "$CAN_USE_SUDO" ]; then
        log_info "Системная установка Podman"
        
        SUDO_CMD=""
        if ! [ "$IS_ROOT" ]; then
            SUDO_CMD="sudo"
        fi
        
        log_info "Обновление репозиториев"
        $SUDO_CMD apt-get update 2>&1 | tail -5 | tee -a "$LOG_FILE"
        
        log_info "Установка Podman с базовыми компонентами"
        $SUDO_CMD apt-get install -y \
            podman \
            podman-compose \
            containers-common \
            slirp4netns \
            uidmap 2>&1 | tail -10 | tee -a "$LOG_FILE"
        
        HAS_PODMAN=true
        HAS_PODMAN_COMPOSE=true
        INSTALL_METHOD="apt"
        
        log_success "Podman и Podman Compose установлены через apt"
    else
        log_error "Требуются права sudo или root для системной установки"
        return 1
    fi
}

install_for_macos() {
    log_section "УСТАНОВКА ДЛЯ macOS"
    
    if ! command -v brew &> /dev/null; then
        log_error "Brew не установлен"
        log_info "Установите Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        return 1
    fi
    
    log_info "Установка Podman через Brew"
    brew install podman podman-compose 2>&1 | tee -a "$LOG_FILE"
    
    log_info "Инициализация Podman VM"
    podman machine init 2>&1 | tee -a "$LOG_FILE" || true
    podman machine start 2>&1 | tee -a "$LOG_FILE" || true
    
    HAS_PODMAN=true
    HAS_PODMAN_COMPOSE=true
    INSTALL_METHOD="brew"
    
    log_success "Podman установлен через Brew"
}

install_for_wsl2() {
    log_section "УСТАНОВКА ДЛЯ WSL2"
    
    log_warning "Определено WSL2 окружение"
    log_info "Рекомендуется использовать Docker Desktop for Windows"
    
    if [ "$IS_ROOT" ] || [ "$CAN_USE_SUDO" ]; then
        SUDO_CMD=""
        if ! [ "$IS_ROOT" ]; then
            SUDO_CMD="sudo"
        fi
        
        log_info "Установка Docker из официального репозитория Ubuntu"
        
        $SUDO_CMD apt-get update 2>&1 | tail -3 | tee -a "$LOG_FILE"
        $SUDO_CMD apt-get install -y \
            apt-transport-https \
            ca-certificates \
            curl \
            gnupg \
            lsb-release 2>&1 | tail -5 | tee -a "$LOG_FILE"
        
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | $SUDO_CMD gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
            $SUDO_CMD tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        $SUDO_CMD apt-get update 2>&1 | tail -3 | tee -a "$LOG_FILE"
        $SUDO_CMD apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin 2>&1 | tail -5 | tee -a "$LOG_FILE"
        
        HAS_DOCKER=true
        INSTALL_METHOD="docker-official"
        
        log_success "Docker установлен для WSL2"
    else
        log_error "Требуются права для установки в WSL2"
    fi
}

install_for_flatpak() {
    log_section "УСТАНОВКА ДЛЯ FLATPAK"
    
    log_warning "Определено Flatpak окружение"
    log_info "Flatpak строго изолирует приложения, предотвращая доступ к системным контейнерам"
    
    # Вариант 1: Использование flatpak-ified runtime если доступен
    log_info "Проверка доступности Flatpak рантайма"
    
    if [ "$IS_ROOT" ] || [ "$CAN_USE_SUDO" ]; then
        SUDO_CMD=""
        if ! [ "$IS_ROOT" ]; then
            SUDO_CMD="sudo"
        fi
        
        # Установка контейнерных инструментов на хосте
        log_info "Установка контейнерных инструментов на хосте (требуется для доступа из Flatpak)"
        
        if ! [ -f /usr/bin/podman ]; then
            log_info "Установка Podman на хост"
            if [ -f /etc/fedora-release ]; then
                $SUDO_CMD dnf install -y podman podman-compose 2>&1 | tail -5 | tee -a "$LOG_FILE"
            elif [ -f /etc/debian_version ]; then
                $SUDO_CMD apt-get update && $SUDO_CMD apt-get install -y podman podman-compose 2>&1 | tail -5 | tee -a "$LOG_FILE"
            fi
        fi
    fi
    
    log_info "Создание скрипта-обертки для использования из Flatpak"
    
    # Создание скрипта, который можно использовать из Flatpak
    cat > "${PROJECT_ROOT}/.flatpak-podman-wrapper.sh" << 'WRAPPER_EOF'
#!/bin/bash
# Обертка для использования Podman из Flatpak окружения
# Использует вспомогательный сокет для доступа к хост-системе

if [ -S /run/podman/podman.sock ]; then
    # Прямой доступ к сокету Podman
    podman "$@"
elif [ -S /run/user/$(id -u)/podman/podman.sock ]; then
    # Доступ к пользовательскому сокету
    PODMAN_SOCK="/run/user/$(id -u)/podman/podman.sock" podman "$@"
else
    echo "Ошибка: Podman сокет не доступен из Flatpak"
    echo "Убедитесь, что:"
    echo "  1. Podman установлен на хосте"
    echo "  2. Используется пользовательский режим Podman"
    echo "  3. Flatpak имеет доступ к $HOME/.config/containers/"
    exit 1
fi
WRAPPER_EOF
    
    chmod +x "${PROJECT_ROOT}/.flatpak-podman-wrapper.sh"
    log_success "Создана обертка для использования Podman из Flatpak"
    
    # Инструкции для Flatpak
    log_info "Для Flatpak приложений требуется:"
    log_info "  1. Установка Podman на хост-системе"
    log_info "  2. Использование файла-обертки вместо прямого вызова podman"
    log_info "  3. Разрешение доступа Flatpak к контейнерным сокетам"
}

# ============================================================================
# КОНФИГУРАЦИЯ БЕЗОПАСНОСТИ
# ============================================================================

configure_security() {
    log_section "КОНФИГУРАЦИЯ БЕЗОПАСНОСТИ PODMAN"
    
    if [ "$HAS_PODMAN" = true ]; then
        log_info "Конфигурирование безопасных параметров Podman"
        
        # Проверка rootless режима
        if podman info --format "{{.Host.Security}}" 2>/dev/null | grep -q "rootless"; then
            log_success "Podman работает в rootless режиме (безопасно)"
        else
            if [ "$IS_ROOT" ]; then
                log_warning "Podman работает в режиме root (менее безопасно)"
                log_info "Рекомендуется использовать rootless режим"
            fi
        fi
        
        # Проверка субуидов для rootless режима
        if grep -q "$(whoami)" /etc/subuid 2>/dev/null; then
            log_success "Пользователь имеет суб-UIDs для rootless режима"
        else
            if [ "$CAN_USE_SUDO" ] || [ "$IS_ROOT" ]; then
                log_warning "Требуется настройка субуидов для rootless режима"
                log_info "Это позволит запускать контейнеры без root прав"
                
                if command -v usermod &>/dev/null; then
                    SUDO_CMD=""
                    if ! [ "$IS_ROOT" ]; then
                        SUDO_CMD="sudo"
                    fi
                    
                    if [ -f /etc/subuid ]; then
                        if ! grep -q "$(whoami)" /etc/subuid; then
                            log_info "Добавление суб-UIDs для $(whoami)"
                            echo "$(whoami):100000:65536" | $SUDO_CMD tee -a /etc/subuid > /dev/null
                            echo "$(whoami):100000:65536" | $SUDO_CMD tee -a /etc/subgid > /dev/null
                            log_success "Суб-UIDs добавлены"
                        fi
                    fi
                fi
            fi
        fi
        
        # Конфигурация сетевой политики
        log_info "Конфигурация сетевых параметров"
        
        # Установка сетевого риска
        if [ -d ~/.config/containers ]; then
            log_success "Директория конфигурации контейнеров существует"
        else
            mkdir -p ~/.config/containers
            log_success "Создана директория конфигурации контейнеров"
        fi
    fi
}

# ============================================================================
# ПРОВЕРКА ФУНКЦИОНАЛЬНОСТИ
# ============================================================================

verify_installation() {
    log_section "ПРОВЕРКА ФУНКЦИОНАЛЬНОСТИ"
    
    if [ "$HAS_PODMAN" = true ]; then
        log_info "Проверка Podman"
        
        if podman run --rm hello-world &>/dev/null; then
            log_success "Podman работает корректно (test container запустился)"
        else
            log_error "Podman не может запустить тестовый контейнер"
            log_info "Проверьте права доступа и конфигурацию"
            return 1
        fi
    fi
    
    if [ "$HAS_DOCKER" = true ]; then
        log_info "Проверка Docker"
        
        if docker run --rm hello-world &>/dev/null; then
            log_success "Docker работает корректно"
        else
            log_warning "Docker определен но не работает"
        fi
    fi
    
    log_success "Проверка функциональности завершена"
}

# ============================================================================
# ГЕНЕРАЦИЯ CONFIG ФАЙЛА
# ============================================================================

generate_config() {
    log_section "ГЕНЕРАЦИЯ КОНФИГУРАЦИИ СРЕДЫ"
    
    local CONFIG_FILE="${PROJECT_ROOT}/.runtime-config"
    
    {
        echo "# Автоматически сгенерирована: $(date)"
        echo ""
        echo "# Определенное окружение:"
        echo "OS=$DETECTED_OS"
        echo "DISTRO=$DETECTED_DISTRO"
        echo "ENVIRONMENT=$DETECTED_ENV"
        echo ""
        echo "# Установленные рантаймы:"
        echo "HAS_PODMAN=$HAS_PODMAN"
        echo "HAS_DOCKER=$HAS_DOCKER"
        echo "HAS_PODMAN_COMPOSE=$HAS_PODMAN_COMPOSE"
        echo "HAS_DOCKER_COMPOSE=$HAS_DOCKER_COMPOSE"
        echo ""
        echo "# Способ установки:"
        echo "INSTALL_METHOD=$INSTALL_METHOD"
        echo "IS_ROOT=$IS_ROOT"
        echo "CAN_USE_SUDO=$CAN_USE_SUDO"
        echo ""
        echo "# Версии:"
        if [ "$HAS_PODMAN" = true ]; then
            echo "PODMAN_VERSION=$(podman --version)"
        fi
        if [ "$HAS_DOCKER" = true ]; then
            echo "DOCKER_VERSION=$(docker --version)"
        fi
        if [ "$HAS_PODMAN_COMPOSE" = true ]; then
            echo "PODMAN_COMPOSE_VERSION=$(podman-compose --version)"
        fi
        if [ "$HAS_DOCKER_COMPOSE" = true ]; then
            echo "DOCKER_COMPOSE_VERSION=$(docker-compose --version)"
        fi
        echo ""
        echo "# Рекомендуемый рантайм:"
        if [ "$HAS_PODMAN" = true ]; then
            echo "RECOMMENDED_RUNTIME=podman"
        elif [ "$HAS_DOCKER" = true ]; then
            echo "RECOMMENDED_RUNTIME=docker"
        else
            echo "RECOMMENDED_RUNTIME=none"
        fi
    } > "$CONFIG_FILE"
    
    log_success "Конфигурация сохранена в $CONFIG_FILE"
}

# ============================================================================
# ГЛАВНАЯ ПРОЦЕДУРА
# ============================================================================

main() {
    log_init
    
    detect_environment
    check_runtime_installed
    
    if [ "$NEEDS_INSTALL" = true ]; then
        log_section "УСТАНОВКА ТРЕБУЕМЫХ КОМПОНЕНТОВ"
        
        case "$DETECTED_OS" in
            Linux)
                case "$DETECTED_DISTRO" in
                    *Fedora*|*CentOS*|*RHEL*)
                        install_for_fedora
                        ;;
                    *Ubuntu*|*Debian*)
                        if [ "$DETECTED_ENV" = "wsl2" ]; then
                            install_for_wsl2
                        else
                            install_for_ubuntu_debian
                        fi
                        ;;
                    *)
                        log_error "Неподдерживаемый дистрибутив: $DETECTED_DISTRO"
                        log_info "Пожалуйста установите Podman или Docker вручную"
                        return 1
                        ;;
                esac
                ;;
            macOS)
                install_for_macos
                ;;
            *)
                log_error "Неподдерживаемая ОС: $DETECTED_OS"
                return 1
                ;;
        esac
        
        # Специальная обработка для Flatpak
        if [ "$DETECTED_ENV" = "flatpak" ]; then
            install_for_flatpak
        fi
    fi
    
    configure_security
    verify_installation
    generate_config
    
    log_header "✅ УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО"
    
    echo ""
    log_success "Рекомендуемая команда для запуска проекта:"
    
    if [ "$HAS_PODMAN" = true ]; then
        echo "  cd $PROJECT_ROOT"
        echo "  bash scripts/rebuild-from-scratch.sh"
    elif [ "$HAS_DOCKER" = true ]; then
        echo "  cd $PROJECT_ROOT"
        echo "  docker-compose up -d"
    else
        log_error "Ни Podman ни Docker не установлены"
        return 1
    fi
    
    echo ""
    log_info "Логи сохранены в: $LOG_FILE"
}

# ============================================================================
# ЗАПУСК
# ============================================================================

main "$@"
exit $?
