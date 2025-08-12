#!/bin/bash
set -e

# УНИВЕРСАЛЬНЫЙ ДИАГНОСТИЧЕСКИЙ СКРИПТ
# Объединяет функциональность всех диагностических скриптов:
# - diagnose.sh
# - fix_common_issues.sh  
# - kill_hanging.sh
# - fix_kernel_cleanup.sh
# - fix_php_hanging.sh
# - finish_installation.sh

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Функция безопасного завершения процесса
safe_kill_process() {
    local process_name="$1"
    local pids=$(pgrep -f "$process_name" 2>/dev/null || true)
    
    if [ -n "$pids" ]; then
        echo -e "${YELLOW}Завершение процессов $process_name...${NC}"
        for pid in $pids; do
            if kill -0 "$pid" 2>/dev/null; then
                echo -e "${BLUE}Завершение PID $pid ($process_name)${NC}"
                kill "$pid" 2>/dev/null || true
                sleep 1
                if kill -0 "$pid" 2>/dev/null; then
                    echo -e "${YELLOW}Принудительное завершение PID $pid${NC}"
                    kill -9 "$pid" 2>/dev/null || true
                fi
            fi
        done
    fi
}

# Функция безопасного чтения файла
safe_read_file() {
    local file="$1"
    local lines="${2:-10}"
    
    if [ -f "$file" ] && [ -r "$file" ]; then
        tail -"$lines" "$file" 2>/dev/null || echo "Не удалось прочитать файл"
    else
        echo "Файл $file не найден или недоступен для чтения"
    fi
}

# Функция проверки существования команды
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Проверка прав root
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}❌ Этот скрипт должен быть запущен от имени root${NC}"
        echo -e "${YELLOW}Запустите: sudo $0${NC}"
        exit 1
    fi
}

# Функция диагностики системы
diagnose_system() {
    echo -e "\n${CYAN}🔍 ДИАГНОСТИКА СИСТЕМЫ${NC}"
    echo "----------------------------------------"
    
    # 1. Проверка блокировки APT
    echo -e "\n${CYAN}1. Проверка блокировки APT:${NC}"
    if lsof /var/lib/dpkg/lock-frontend 2>/dev/null; then
        echo -e "${RED}❌ APT заблокирован другим процессом${NC}"
        echo "Процессы, использующие APT:"
        lsof /var/lib/dpkg/lock-frontend 2>/dev/null || echo "Не удалось получить информацию о процессах"
        ps aux | grep -E "(apt|dpkg|unattended-upgrade)" | grep -v grep || echo "Процессы APT не найдены"
    else
        echo -e "${GREEN}✅ APT не заблокирован${NC}"
    fi
    
    # 2. Проверка места на диске
    echo -e "\n${CYAN}2. Проверка места на диске:${NC}"
    if command_exists df; then
        df -h | head -1
        df -h / | tail -1
        FREE_SPACE=$(df / | awk 'NR==2 {print $4}' 2>/dev/null || echo "0")
        if [ "$FREE_SPACE" -lt 1000000 ] 2>/dev/null; then
            echo -e "${RED}❌ Мало свободного места (менее 1GB)${NC}"
        else
            echo -e "${GREEN}✅ Достаточно свободного места${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ Команда df не найдена${NC}"
    fi
    
    # 3. Проверка памяти
    echo -e "\n${CYAN}3. Проверка памяти:${NC}"
    if command_exists free; then
        free -h
        AVAILABLE_MEM=$(free | awk 'NR==2{printf "%.0f", $7/1024/1024}' 2>/dev/null || echo "0")
        if [ "$AVAILABLE_MEM" -lt 1 ] 2>/dev/null; then
            echo -e "${YELLOW}⚠️ Мало доступной памяти (менее 1GB)${NC}"
        else
            echo -e "${GREEN}✅ Достаточно памяти${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ Команда free не найдена${NC}"
    fi
    
    # 4. Проверка сетевого соединения
    echo -e "\n${CYAN}4. Проверка сетевого соединения:${NC}"
    if command_exists ping; then
        if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Интернет соединение работает${NC}"
        else
            echo -e "${RED}❌ Проблемы с интернет соединением${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ Команда ping не найдена${NC}"
    fi
    
    # 5. Проверка репозиториев
    echo -e "\n${CYAN}5. Проверка репозиториев Ubuntu:${NC}"
    if command_exists curl; then
        if curl -s --connect-timeout 5 http://archive.ubuntu.com >/dev/null; then
            echo -e "${GREEN}✅ Репозитории Ubuntu доступны${NC}"
        else
            echo -e "${RED}❌ Репозитории Ubuntu недоступны${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ Команда curl не найдена${NC}"
    fi
    
    # 6. Проверка активных процессов установки
    echo -e "\n${CYAN}6. Активные процессы установки:${NC}"
    if command_exists ps; then
        INSTALL_PROCESSES=$(ps aux | grep -E "(apt|dpkg|unattended-upgrade)" | grep -v grep 2>/dev/null || true)
        if [ -n "$INSTALL_PROCESSES" ]; then
            echo -e "${YELLOW}⚠️ Найдены активные процессы установки:${NC}"
            echo "$INSTALL_PROCESSES"
        else
            echo -e "${GREEN}✅ Нет активных процессов установки${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ Команда ps не найдена${NC}"
    fi
    
    # 7. Проверка логов APT
    echo -e "\n${CYAN}7. Последние записи в логах APT:${NC}"
    safe_read_file "/var/log/apt/term.log" 10
    
    # 8. Проверка системных ошибок
    echo -e "\n${CYAN}8. Последние системные ошибки:${NC}"
    if command_exists journalctl; then
        journalctl --no-pager -p err -n 5 --since "10 minutes ago" 2>/dev/null || echo "Не удалось получить системные ошибки"
    else
        echo -e "${YELLOW}⚠️ Команда journalctl не найдена${NC}"
    fi
    
    # 9. Проверка PHP
    echo -e "\n${CYAN}9. Проверка PHP:${NC}"
    if command_exists php; then
        if php --version >/dev/null 2>&1; then
            echo -e "${GREEN}✅ PHP установлен${NC}"
            PHP_VERSION=$(php --version | head -1)
            echo -e "${BLUE}Версия PHP: $PHP_VERSION${NC}"
        else
            echo -e "${YELLOW}⚠️ PHP не установлен или не работает${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ PHP не установлен${NC}"
    fi
    
    # 10. Проверка состояния системы
    echo -e "\n${CYAN}10. Состояние системы:${NC}"
    if command_exists systemctl; then
        if systemctl is-system-running | grep -E "(running|degraded)" >/dev/null; then
            echo -e "${GREEN}✅ Система работает нормально${NC}"
        else
            echo -e "${YELLOW}⚠️ Система требует внимания${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ Команда systemctl не найдена${NC}"
    fi
}

# Функция остановки зависших процессов
kill_hanging_processes() {
    echo -e "\n${CYAN}🛑 ОСТАНОВКА ЗАВИСШИХ ПРОЦЕССОВ${NC}"
    echo "----------------------------------------"
    
    echo -e "${YELLOW}⚠️ Завершение процессов APT/DPKG...${NC}"
    
    # Список процессов для безопасного завершения
    local processes=(
        "apt"
        "dpkg"
        "unattended-upgrade"
        "linux-modules"
        "update-initramfs"
        "php"
        "triggers"
        "man-db"
        "libc-bin"
        "mailcap"
        "dbus"
    )
    
    # Завершаем процессы безопасно
    for process in "${processes[@]}"; do
        safe_kill_process "$process"
    done
    
    sleep 5
    
    # Принудительно завершаем если еще работают
    for process in "${processes[@]}"; do
        local pids=$(pgrep -f "$process" 2>/dev/null || true)
        if [ -n "$pids" ]; then
            echo -e "${YELLOW}Принудительное завершение $process...${NC}"
            for pid in $pids; do
                kill -9 "$pid" 2>/dev/null || true
            done
        fi
    done
    
    echo -e "${GREEN}✅ Процессы завершены${NC}"
}

# Функция очистки блокировок
clean_locks() {
    echo -e "\n${CYAN}🔓 ОЧИСТКА БЛОКИРОВОК${NC}"
    echo "----------------------------------------"
    
    # Список блокировочных файлов
    local lock_files=(
        "/var/lib/dpkg/lock-frontend"
        "/var/lib/dpkg/lock"
        "/var/cache/apt/archives/lock"
        "/var/lib/apt/lists/lock"
    )
    
    # Удаляем блокировочные файлы
    for lock_file in "${lock_files[@]}"; do
        if [ -f "$lock_file" ]; then
            echo -e "${BLUE}Удаление блокировки: $lock_file${NC}"
            rm -f "$lock_file" 2>/dev/null || true
        fi
    done
    
    echo -e "${GREEN}✅ Блокировки удалены${NC}"
}

# Функция восстановления пакетов
restore_packages() {
    echo -e "\n${CYAN}📦 ВОССТАНОВЛЕНИЕ ПАКЕТОВ${NC}"
    echo "----------------------------------------"
    
    # Настраиваем пакеты, которые могли остаться в неопределенном состоянии
    export DEBIAN_FRONTEND=noninteractive
    export APT_LISTCHANGES_FRONTEND=none
    
    if command_exists dpkg; then
        dpkg --configure -a 2>/dev/null || true
        echo -e "${GREEN}✅ Состояние пакетов восстановлено${NC}"
    else
        echo -e "${YELLOW}⚠️ Команда dpkg не найдена${NC}"
    fi
}

# Функция очистки старых ядер
clean_old_kernels() {
    echo -e "\n${CYAN}🧹 ОЧИСТКА СТАРЫХ ЯДЕР${NC}"
    echo "----------------------------------------"
    
    # Получаем текущую версию ядра
    CURRENT_KERNEL=$(uname -r)
    echo -e "${BLUE}Текущее ядро: $CURRENT_KERNEL${NC}"
    
    if command_exists dpkg; then
        # Находим старые версии ядра (оставляем только текущую и одну предыдущую)
        OLD_KERNELS=$(dpkg -l | grep -E "linux-image-[0-9]" | grep -v "$CURRENT_KERNEL" | awk '{print $2}' | head -n -1)
        
        if [ -n "$OLD_KERNELS" ]; then
            echo -e "${YELLOW}Найдены старые версии ядра для удаления:${NC}"
            echo "$OLD_KERNELS"
            
            for kernel in $OLD_KERNELS; do
                echo -e "${CYAN}Удаление $kernel...${NC}"
                apt-get remove --purge -y "$kernel" || true
                apt-get remove --purge -y "${kernel/image/modules}" || true
                apt-get remove --purge -y "${kernel/image/headers}" || true
            done
        else
            echo -e "${GREEN}✅ Старые ядра не найдены или уже удалены${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ Команда dpkg не найдена${NC}"
    fi
}

# Функция обновления триггеров
update_triggers() {
    echo -e "\n${CYAN}⚙️ ОБНОВЛЕНИЕ ТРИГГЕРОВ${NC}"
    echo "----------------------------------------"
    
    # Принудительно обновляем все отложенные триггеры
    if command_exists update-desktop-database; then
        update-desktop-database 2>/dev/null || true
    fi
    
    if [ -d "/usr/share/mime" ] && command_exists update-mime-database; then
        update-mime-database /usr/share/mime 2>/dev/null || true
    fi
    
    if command_exists mandb; then
        mandb -q 2>/dev/null || true
    fi
    
    if command_exists ldconfig; then
        ldconfig 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✅ Триггеры обновлены${NC}"
}

# Функция настройки PHP
setup_php() {
    echo -e "\n${CYAN}🐘 НАСТРОЙКА PHP${NC}"
    echo "----------------------------------------"
    
    # Запускаем PHP-FPM
    if command_exists systemctl; then
        systemctl daemon-reload
        systemctl enable php8.1-fpm 2>/dev/null || true
        systemctl start php8.1-fpm 2>/dev/null || true
        
        if systemctl is-active --quiet php8.1-fpm; then
            echo -e "${GREEN}✅ PHP-FPM запущен успешно${NC}"
        else
            echo -e "${YELLOW}⚠️ PHP-FPM требует ручной настройки${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ Команда systemctl не найдена${NC}"
    fi
}

# Функция исправления проблем с Composer
fix_composer() {
    echo -e "\n${CYAN}📦 ИСПРАВЛЕНИЕ COMPOSER${NC}"
    echo "----------------------------------------"
    
    # Проверяем, установлен ли уже Composer
    if command_exists composer; then
        echo -e "${GREEN}✅ Composer уже установлен${NC}"
        composer --version | head -1
        return 0
    fi
    
    # Проверяем PHP
    if ! command_exists php; then
        echo -e "${YELLOW}⚠️ PHP не установлен. Устанавливаем...${NC}"
        
        # Останавливаем зависшие процессы APT
        safe_kill_process "apt"
        safe_kill_process "dpkg"
        sleep 3
        
        # Очищаем блокировки
        clean_locks
        
        # Восстанавливаем пакеты
        restore_packages
        
        # Устанавливаем PHP
        export DEBIAN_FRONTEND=noninteractive
        apt update 2>/dev/null || true
        apt install -y php-cli php-mbstring php-xml php-zip php-curl php-gd php-mysql php-fpm 2>/dev/null || true
    fi
    
    # Устанавливаем Composer с таймаутом
    echo -e "${BLUE}Установка Composer...${NC}"
    if timeout 300 bash -c '
        curl -sS --connect-timeout 30 --max-time 300 https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
    '; then
        echo -e "${GREEN}✅ Composer установлен успешно${NC}"
    else
        echo -e "${YELLOW}⚠️ Первый метод не сработал. Попытка 2...${NC}"
        
        # Альтернативный метод
        if timeout 300 bash -c '
            wget --timeout=30 --tries=3 -O composer-setup.php https://getcomposer.org/installer
            php composer-setup.php --install-dir=/usr/local/bin --filename=composer
            rm composer-setup.php
        '; then
            echo -e "${GREEN}✅ Composer установлен успешно${NC}"
        else
            echo -e "${RED}❌ Не удалось установить Composer${NC}"
            return 1
        fi
    fi
    
    # Проверяем установку
    if command_exists composer; then
        echo -e "${GREEN}✅ Composer готов к работе${NC}"
        composer --version | head -1
        return 0
    else
        echo -e "${RED}❌ Composer не найден после установки${NC}"
        return 1
    fi
}

# Функция запуска сервисов
start_services() {
    echo -e "\n${CYAN}🚀 ЗАПУСК СЕРВИСОВ${NC}"
    echo "----------------------------------------"
    
    # Запускаем основные сервисы
    if command_exists systemctl; then
        systemctl start dbus 2>/dev/null || true
        systemctl enable dbus 2>/dev/null || true
        echo -e "${GREEN}✅ Сервисы запущены${NC}"
    else
        echo -e "${YELLOW}⚠️ Команда systemctl не найдена${NC}"
    fi
}

# Функция финальной очистки
final_cleanup() {
    echo -e "\n${CYAN}🧽 ФИНАЛЬНАЯ ОЧИСТКА${NC}"
    echo "----------------------------------------"
    
    # Очищаем кэш и ненужные пакеты
    if command_exists apt-get; then
        apt-get clean 2>/dev/null || true
        apt-get autoremove -y 2>/dev/null || true
        apt-get autoclean 2>/dev/null || true
    fi
    
    # Обновляем GRUB
    if command_exists update-grub; then
        update-grub 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✅ Система очищена${NC}"
}

# Функция проверки готовности
check_readiness() {
    echo -e "\n${CYAN}✅ ПРОВЕРКА ГОТОВНОСТИ${NC}"
    echo "----------------------------------------"
    
    # Проверяем что система готова
    if command_exists apt-get && apt-get update >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Система готова к продолжению установки${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️ Возможны остаточные проблемы${NC}"
        return 1
    fi
}

# Функция вывода рекомендаций
show_recommendations() {
    echo -e "\n${BLUE}================================================"
    echo -e "${CYAN}РЕКОМЕНДАЦИИ:${NC}"
    
    # Выдаем рекомендации на основе найденных проблем
    if lsof /var/lib/dpkg/lock-frontend 2>/dev/null; then
        echo -e "${YELLOW}• Завершите зависшие процессы APT и перезапустите установку${NC}"
    fi
    
    if command_exists df; then
        FREE_SPACE=$(df / | awk 'NR==2 {print $4}' 2>/dev/null || echo "0")
        if [ "$FREE_SPACE" -lt 1000000 ] 2>/dev/null; then
            echo -e "${YELLOW}• Освободите место на диске${NC}"
        fi
    fi
    
    if command_exists ping && ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        echo -e "${YELLOW}• Проверьте сетевое соединение${NC}"
    fi
    
    echo -e "${GREEN}Используйте команду 'fix' для принудительной остановки зависших процессов${NC}"
}

# Главная функция
main() {
    local action="$1"
    
    echo -e "${BLUE}🔧 УНИВЕРСАЛЬНЫЙ ДИАГНОСТИЧЕСКИЙ СКРИПТ${NC}"
    echo "================================================"
    
    case "$action" in
        "diagnose")
            diagnose_system
            show_recommendations
            ;;
        "kill")
            echo -e "${YELLOW}⚠️ Это действие принудительно завершит все процессы APT/DPKG${NC}"
            echo -e "${YELLOW}⚠️ Убедитесь, что никакие важные установки не выполняются${NC}"
            echo ""
            read -p "Продолжить? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Отменено пользователем"
                exit 1
            fi
            
            kill_hanging_processes
            clean_locks
            restore_packages
            ;;
        "fix")
            echo -e "${YELLOW}⚠️ Это действие принудительно завершит все процессы APT/DPKG${NC}"
            echo -e "${YELLOW}⚠️ Убедитесь, что никакие важные установки не выполняются${NC}"
            echo ""
            read -p "Продолжить? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Отменено пользователем"
                exit 1
            fi
            
            kill_hanging_processes
            clean_locks
            restore_packages
            clean_old_kernels
            update_triggers
            setup_php
            start_services
            final_cleanup
            check_readiness
            ;;
        "quick")
            # Быстрое исправление без подтверждения
            kill_hanging_processes
            clean_locks
            restore_packages
            update_triggers
            check_readiness
            ;;
        "full")
            # Полное исправление с подтверждением
            echo -e "${YELLOW}⚠️ Полное исправление системы${NC}"
            echo -e "${YELLOW}⚠️ Это может занять несколько минут${NC}"
            echo ""
            read -p "Продолжить? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Отменено пользователем"
                exit 1
            fi
            
            diagnose_system
            kill_hanging_processes
            clean_locks
            restore_packages
            clean_old_kernels
            update_triggers
            setup_php
            start_services
            final_cleanup
            check_readiness
            ;;
        "finish")
            # Завершение установки
            echo -e "${YELLOW}⚠️ Завершение установки (99% -> 100%)${NC}"
            echo ""
            read -p "Продолжить? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Отменено пользователем"
                exit 1
            fi
            
            kill_hanging_processes
            clean_locks
            restore_packages
            update_triggers
            start_services
            final_cleanup
            check_readiness
            ;;
        "composer")
            # Исправление проблем с Composer
            echo -e "${YELLOW}⚠️ Исправление проблем с Composer${NC}"
            echo ""
            read -p "Продолжить? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Отменено пользователем"
                exit 1
            fi
            
            kill_hanging_processes
            clean_locks
            restore_packages
            fix_composer
            check_readiness
            ;;
        *)
            echo -e "${YELLOW}Универсальный диагностический скрипт${NC}"
            echo ""
            echo "Использование: $0 [команда]"
            echo ""
            echo "Команды:"
            echo "  diagnose  - Диагностика проблем системы"
            echo "  kill      - Остановка зависших процессов"
            echo "  fix       - Исправление с подтверждением"
            echo "  quick     - Быстрое исправление"
            echo "  full      - Полное исправление"
            echo "  finish    - Завершение установки (99% -> 100%)"
            echo "  composer  - Исправление проблем с Composer"
            echo ""
            echo "Примеры:"
            echo "  $0 diagnose"
            echo "  $0 fix"
            echo "  $0 quick"
            echo "  $0 full"
            echo "  $0 finish"
            echo "  $0 composer"
            echo ""
            echo -e "${CYAN}Рекомендуется начать с: ${YELLOW}$0 diagnose${NC}"
            exit 1
            ;;
    esac
}

# Проверка прав root
check_root

# Запуск главной функции
main "$@"

echo -e "\n${BLUE}================================================"
echo -e "${GREEN}🎉 ОПЕРАЦИЯ ЗАВЕРШЕНА${NC}"
echo -e "${CYAN}Теперь можно запустить: ${YELLOW}./script_fixed.sh${NC}"
