# 🔄 ПОШАГОВЫЙ ПРОЦЕСС УСТАНОВКИ TRAFFIC CONNECT SERVER

## 🚀 **ЗАПУСК СКРИПТА**

### **Команда запуска:**
```bash
sudo bash install.sh --install
```

---

## 📋 **ШАГ 1: ИНИЦИАЛИЗАЦИЯ СКРИПТА**

### **1.1 Определение путей**
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
```
- ✅ Определяется директория скрипта
- ✅ Устанавливается корневая директория проекта

### **1.2 Загрузка конфигурации**
```bash
source "$PROJECT_ROOT/core/configs/main.conf"
```
- ✅ Загружается основной файл конфигурации
- ✅ Инициализируются все переменные (версии, порты, пути)
- ✅ Устанавливаются цвета для вывода

### **1.3 Загрузка утилит**
```bash
source "$PROJECT_ROOT/core/utils/logger.sh"
source "$PROJECT_ROOT/core/utils/system.sh"
```
- ✅ Подключается система логирования
- ✅ Подключаются системные утилиты

### **1.4 Инициализация глобальных переменных**
```bash
INSTALLATION_STARTED=false
INSTALLATION_COMPLETED=false
CURRENT_INSTALL_STAGE=""
INSTALLED_COMPONENTS=()
FAILED_COMPONENTS=()
SKIPPED_COMPONENTS=()
```
- ✅ Создаются счетчики для отслеживания процесса
- ✅ Инициализируются массивы для результатов

---

## 🔧 **ШАГ 2: ИНИЦИАЛИЗАЦИЯ УСТАНОВКИ**

### **2.1 Создание директорий**
```bash
mkdir -p "$LOG_DIR" "$CONFIG_DIR" "$BACKUP_DIR" "$TEMP_DIR"
```
- ✅ `/var/log/traffic_connect` - для логов
- ✅ `/etc/traffic_connect` - для конфигураций
- ✅ `/var/backup/traffic_connect` - для бэкапов
- ✅ `/tmp/traffic_connect` - для временных файлов

### **2.2 Настройка логирования**
```bash
setup_logging
```
- ✅ Создаются файлы логов
- ✅ Устанавливаются права доступа
- ✅ Настраивается ротация логов

### **2.3 Загрузка core модулей**
```bash
import_module "system_check"
import_module "password_gen"
import_module "utils"
```
- ✅ Подключается модуль проверки системы
- ✅ Подключается модуль генерации паролей
- ✅ Подключаются общие утилиты

### **2.4 Проверка системы**
```bash
full_system_check
```
- ✅ Проверка операционной системы (Ubuntu/Debian)
- ✅ Проверка прав root
- ✅ Проверка сетевого подключения
- ✅ Проверка системных ресурсов (RAM, диск)
- ✅ Проверка доступности портов
- ✅ Проверка зависимостей

---

## 🔍 **ШАГ 3: ПРОВЕРКА СУЩЕСТВУЮЩЕЙ УСТАНОВКИ**

### **3.1 Проверка HestiaCP**
```bash
[ -f "/usr/local/admin/bin/admin" ] || is_service_active "admin"
```
- ✅ Проверяется наличие бинарного файла
- ✅ Проверяется активность службы

### **3.2 Проверка мониторинга**
```bash
is_service_active "grafana-server" || is_service_active "prometheus"
```
- ✅ Проверяется Grafana
- ✅ Проверяется Prometheus

### **3.3 Проверка безопасности**
```bash
is_service_active "fail2ban" || is_service_active "ufw"
```
- ✅ Проверяется Fail2ban
- ✅ Проверяется UFW

### **3.4 Решение о типе установки**
- 🔄 **Если компоненты найдены:** Частичная установка/обновление
- 🔄 **Если компоненты не найдены:** Полная установка с нуля

---

## 🔄 **ШАГ 4: ПРОВЕРКА ФЛАГА ПЕРЕЗАГРУЗКИ**

### **4.1 Проверка флага**
```bash
if [ -f "$REBOOT_REQUIRED_FLAG" ]; then
```
- ✅ Проверяется наличие флага `/tmp/traffic_connect/reboot_required`

### **4.2 Если флаг найден (продолжение после перезагрузки):**
```bash
log_step "ПРОДОЛЖЕНИЕ УСТАНОВКИ ПОСЛЕ ПЕРЕЗАГРУЗКИ"
import_module "security_install"
setup_security_from_module
import_module "monitoring_install"
install_monitoring
import_module "templates_install"
install_templates
```
- ✅ Устанавливается безопасность
- ✅ Устанавливается мониторинг
- ✅ Устанавливаются шаблоны

---

## 🔐 **ШАГ 5: ГЕНЕРАЦИЯ ПАРОЛЕЙ**

### **5.1 Генерация паролей для всех сервисов**
```bash
generate_secure_passwords
```
- ✅ `HESTIA_PASSWORD` - для HestiaCP
- ✅ `GRAFANA_ADMIN_PASSWORD` - для Grafana
- ✅ `PROMETHEUS_PASSWORD` - для Prometheus
- ✅ `LOKI_PASSWORD` - для Loki
- ✅ `NODE_EXPORTER_PASSWORD` - для Node Exporter
- ✅ `PUSHGATEWAY_PASSWORD` - для Pushgateway
- ✅ `FAIL2BAN_EXPORTER_PASSWORD` - для Fail2ban Exporter
- ✅ `ROOT_SSH_PASSWORD` - для SSH root

---

## 🏗️ **ШАГ 6: УСТАНОВКА КОМПОНЕНТОВ**

### **6.1 Порядок установки:**
```bash
local install_order=(
    "hestia_install"      # 1. HestiaCP (критический)
    "security_install"    # 2. Безопасность
    "monitoring_install"  # 3. Мониторинг
    "templates_install"   # 4. Шаблоны
)
```

### **6.2 Для каждого компонента:**

#### **Проверка необходимости установки:**
```bash
if should_skip_component "$component"; then
    SKIPPED_COMPONENTS+=("$component")
    continue
fi
```

#### **Импорт модуля:**
```bash
if import_module "$component"; then
```

#### **Установка компонента:**
```bash
if install_component "$component"; then
    INSTALLED_COMPONENTS+=("$component")
else
    FAILED_COMPONENTS+=("$component")
fi
```

---

## 🎯 **ШАГ 7: УСТАНОВКА HESTIACP (КРИТИЧЕСКИЙ)**

### **7.1 Проверка совместимости**
- ✅ Проверка ОС (Ubuntu/Debian)
- ✅ Проверка дистрибутива
- ✅ Проверка конфликтующих пакетов

### **7.2 Очистка системы**
```bash
cleanup_hestia
```
- ✅ Остановка служб HestiaCP
- ✅ Удаление директорий
- ✅ Удаление пользователей
- ✅ Очистка конфигураций

### **7.3 Настройка SSL**
```bash
fix_ssl_timeouts
```
- ✅ Увеличение таймаутов
- ✅ Настройка SSL для стабильности

### **7.4 Загрузка установщика**
```bash
download_hestia_installer
```
- ✅ Загрузка с GitHub
- ✅ Проверка целостности
- ✅ Установка прав доступа

### **7.5 Выполнение установки**
```bash
bash /tmp/hst-install.sh --lang 'ru' --hostname "$HESTIA_HOSTNAME" --username "$HESTIA_USERNAME" --email "$HESTIA_EMAIL" --password "$HESTIA_PASSWORD" --apache no --named no --exim no --dovecot no --clamav no --spamassassin no --force
```

### **7.6 Проверка установки**
- ✅ Проверка бинарных файлов
- ✅ Проверка директорий
- ✅ Проверка службы
- ✅ Проверка веб-интерфейса

### **7.7 Создание флага перезагрузки**
```bash
echo "reboot_required" > "$REBOOT_REQUIRED_FLAG"
```

---

## 🛡️ **ШАГ 8: УСТАНОВКА БЕЗОПАСНОСТИ**

### **8.1 Настройка SSH**
```bash
setup_ssh_security
```
- ✅ Создание резервной копии конфигурации
- ✅ Настройка безопасной конфигурации SSH
- ✅ Создание пользователей мониторинга
- ✅ Настройка директорий SSH

### **8.2 Настройка файрвола**
```bash
iptables -F && iptables -X
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
```
- ✅ Сброс правил
- ✅ Установка политик по умолчанию
- ✅ Настройка правил для портов
- ✅ Защита от атак

### **8.3 Настройка Fail2ban**
```bash
cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1
bantime = 3600
findtime = 600
maxretry = 3
EOF
```
- ✅ Конфигурация jails
- ✅ Настройка SSH защиты
- ✅ Настройка Nginx защиты
- ✅ Запуск службы

---

## 📊 **ШАГ 9: УСТАНОВКА МОНИТОРИНГА**

### **9.1 Установка Grafana**
```bash
wget "https://dl.grafana.com/oss/release/grafana_${GRAFANA_VERSION}_amd64.deb"
dpkg -i /tmp/grafana.deb
```
- ✅ Загрузка пакета
- ✅ Установка
- ✅ Настройка пароля администратора
- ✅ Запуск службы

### **9.2 Установка Prometheus**
```bash
wget "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz"
```
- ✅ Загрузка архива
- ✅ Распаковка
- ✅ Создание пользователя
- ✅ Настройка конфигурации
- ✅ Создание systemd службы

### **9.3 Установка Node Exporter**
```bash
wget "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
```
- ✅ Загрузка и установка
- ✅ Создание службы

### **9.4 Установка Loki**
```bash
wget "https://github.com/grafana/loki/releases/download/v${LOKI_VERSION}/loki-linux-amd64.zip"
```
- ✅ Загрузка и установка
- ✅ Настройка конфигурации
- ✅ Создание службы

### **9.5 Настройка Grafana**
```bash
grafana-cli admin reset-admin-password "$GRAFANA_ADMIN_PASSWORD"
```
- ✅ Установка пароля администратора
- ✅ Добавление Prometheus как источника данных

---

## 🎨 **ШАГ 10: УСТАНОВКА ШАБЛОНОВ**

### **10.1 Проверка HestiaCP**
```bash
if [ ! -f "/usr/local/admin/bin/admin" ]; then
    log_warn "Административная панель не установлена, пропускаем шаблоны"
    return 0
fi
```

### **10.2 Создание директорий**
```bash
mkdir -p "$NGINX_TEMPL_DIR" "$PHPFPM_TEMPL_DIR"
```

### **10.3 Копирование шаблонов**
```bash
for file in "$TEMPLATES_DIR"/tc-nginx-*.stpl "$TEMPLATES_DIR"/tc-nginx-*.tpl; do
    cp "$file" "$NGINX_TEMPL_DIR/"
done
```
- ✅ Nginx шаблоны (.stpl и .tpl)
- ✅ PHP-FPM шаблоны (.tpl)
- ✅ Установка прав доступа

### **10.4 Настройка конфигурации**
```bash
sed -i.bak 's/^PHP_TEMPLATE=.*/PHP_TEMPLATE=custom/' "$ADMIN_CONF"
sed -i.bak 's/^WEB_TEMPLATE=.*/WEB_TEMPLATE=custom/' "$ADMIN_CONF"
```

---

## 🔄 **ШАГ 11: ПРОВЕРКА ПЕРЕЗАГРУЗКИ**

### **11.1 Если требуется перезагрузка:**
```bash
if [ -f "$REBOOT_REQUIRED_FLAG" ]; then
    echo "🔄 ТРЕБУЕТСЯ ПЕРЕЗАГРУЗКА СИСТЕМЫ"
    echo "HestiaCP установлен успешно. Требуется перезагрузка для завершения установки."
    echo "После перезагрузки скрипт автоматически продолжит установку!"
    
    read -p "Вы уверены, что хотите перезагрузить систему сейчас? (yes/NO): " -r
    if [[ "$REPLY" == "yes" ]]; then
        echo "Перезагрузка через 10 секунд... Нажмите Ctrl+C для отмены"
        sleep 10
        reboot
    fi
fi
```

---

## ✅ **ШАГ 12: ФИНАЛИЗАЦИЯ**

### **12.1 Перезапуск служб**
```bash
restart_all_services
```
- ✅ Перезапуск всех установленных служб
- ✅ Проверка статуса служб

### **12.2 Валидация установки**
```bash
validate_installation
```
- ✅ Проверка критических служб
- ✅ Проверка веб-интерфейсов
- ✅ Проверка доступности портов

### **12.3 Отображение результатов**
```bash
show_installation_summary
```
- ✅ Статистика установки
- ✅ Список установленных компонентов
- ✅ Список пропущенных компонентов
- ✅ Список компонентов с ошибками

### **12.4 Сохранение учетных данных**
```bash
save_all_credentials
```
- ✅ Создание файла с паролями
- ✅ Установка безопасных прав доступа
- ✅ Сохранение в `/root/traffic_connect_credentials.txt`

### **12.5 Очистка временных файлов**
```bash
cleanup_installation_files
```
- ✅ Удаление временных файлов
- ✅ Удаление флагов установки
- ✅ Очистка кэша

---

## 🎉 **ШАГ 13: ЗАВЕРШЕНИЕ**

### **13.1 Отображение доступа**
```bash
show_access_credentials
```
- ✅ URL для HestiaCP: `https://IP:8083`
- ✅ URL для Grafana: `http://IP:3000`
- ✅ URL для Prometheus: `http://IP:9090`
- ✅ URL для Loki: `http://IP:3100`

### **13.2 Отображение паролей**
```bash
show_all_passwords
```
- ✅ Все сгенерированные пароли
- ✅ Информация о сложности паролей

### **13.3 Финальное сообщение**
```
🎉 ВСЕ ГОТОВО! Система полностью установлена и настроена.
===============================================
```

---

## 📊 **РЕЗУЛЬТАТ УСТАНОВКИ**

### **✅ Что получает пользователь:**

1. **🌐 Hestia Control Panel**
   - URL: `https://IP:8083`
   - Пользователь: `TrafficAdmin`
   - Пароль: сгенерированный автоматически

2. **📊 Система мониторинга**
   - Grafana: `http://IP:3000`
   - Prometheus: `http://IP:9090`
   - Loki: `http://IP:3100`
   - Node Exporter: `http://IP:9100`

3. **🛡️ Безопасность**
   - Fail2ban защита
   - UFW файрвол
   - Безопасная конфигурация SSH
   - Сложные пароли для всех сервисов

4. **🎨 Веб-шаблоны**
   - Nginx + Apache конфигурации
   - PHP-FPM оптимизация
   - SSL/TLS настройки

5. **📄 Документация**
   - Файл с паролями: `/root/traffic_connect_credentials.txt`
   - Логи установки: `/var/log/traffic_connect/`
   - Конфигурации: `/etc/traffic_connect/`

---

## ⚠️ **ВАЖНЫЕ ЗАМЕЧАНИЯ**

### **🔄 Перезагрузка:**
- После установки HestiaCP **требуется перезагрузка**
- Скрипт автоматически продолжит установку после перезагрузки
- Пользователь может отменить перезагрузку

### **🔐 Безопасность:**
- Все пароли генерируются автоматически
- Пароли соответствуют политике безопасности
- Файл с паролями автоматически удаляется через 24 часа

### **📝 Логирование:**
- Все действия логируются
- Логи сохраняются в `/var/log/traffic_connect/`
- Поддерживается JSON формат логов

### **🛠️ Восстановление:**
- Система поддерживает частичную установку
- Существующие компоненты не переустанавливаются
- Возможен rollback при ошибках

---

**🎯 ИТОГ:** Процесс установки полностью автоматизирован, безопасен и надежен. Система готова к использованию сразу после завершения установки!
