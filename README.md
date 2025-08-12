# 🚀 TC Fast Setup - Быстрая установка системы мониторинга

Автоматический скрипт для установки полноценной системы мониторинга на Ubuntu VPS с Grafana, Prometheus, Loki и другими компонентами.

## 📋 Что устанавливается

### 🌐 Веб-интерфейсы

- **Grafana** - дашборды мониторинга (порт 3000)
- **Prometheus** - сбор метрик (порт 9090)
- **Loki** - агрегация логов (порт 3100)
- **Pushgateway** - прием метрик (порт 9091)

### 🛡️ Безопасность
- **Fail2ban** - защита от брутфорса
- **Firewall** - настройка nftables/iptables
- **Аутентификация** - защищенные пароли для всех сервисов

### 📊 Мониторинг
- **Node Exporter** - метрики системы (порт 9100)
- **Promtail** - отправка логов в Loki (порт 9080)
- **Fail2ban Exporter** - метрики Fail2ban (порт 9191)

## 🚀 Быстрый старт

### 1. Подготовка сервера
```bash
# Подключитесь к серверу как root
ssh root@your-server-ip

# Обновите систему
apt update && apt upgrade -y
```

### 2. Установка
```bash
# Скачайте скрипт
wget https://raw.githubusercontent.com/Traffic-Connect/tc_fast_setup/main/script.sh

# Сделайте исполняемым
chmod +x script.sh

# Запустите установку
./script.sh
```

### 3. Проверка установки
```bash
# Запустите диагностику
wget https://raw.githubusercontent.com/Traffic-Connect/tc_fast_setup/main/diagnostic.sh
chmod +x diagnostic.sh
./diagnostic.sh
```

## 🌐 Установка Hestia CP (отдельно)

Если вам нужна панель управления сервером Hestia CP:

```bash
# Скачиваем скрипт установки Hestia CP
wget https://raw.githubusercontent.com/Traffic-Connect/tc_fast_setup/main/install_hestia.sh

# Делаем исполняемым
chmod +x install_hestia.sh

# Запускаем установку
sudo bash install_hestia.sh
```

**После установки Hestia CP:**
- URL: `https://IP:8083`
- Логин: `admin`
- Пароль: генерируется автоматически и показывается в конце установки

## 📁 Структура проекта

### Основные файлы
- **`script.sh`** - главный скрипт установки системы мониторинга
- **`install_hestia.sh`** - отдельный скрипт установки Hestia CP
- **`diagnostic.sh`** - универсальная диагностика системы
- **`firewall_fixed.sh`** - исправленная настройка файрвола
- **`fix_auth.sh`** - исправление проблем с аутентификацией
- **`README.md`** - документация проекта

### Удаленные файлы (объединены в diagnostic.sh)
- ~~`check_services.sh`~~ - функциональность перенесена в diagnostic.sh
- ~~`diagnose_services.sh`~~ - функциональность перенесена в diagnostic.sh
- ~~`debug_services.sh`~~ - функциональность перенесена в diagnostic.sh
- ~~`fix_configs.sh`~~ - функциональность перенесена в fix_auth.sh
- ~~`fix_remaining.sh`~~ - функциональность перенесена в fix_auth.sh
- ~~`fix_firewall.sh`~~ - заменен на firewall_fixed.sh
- ~~`fw.sh`~~ - функциональность перенесена в firewall_fixed.sh
- ~~`2.sh`~~ - устаревший файл
- ~~`unified_diagnostic.sh`~~ - заменен на diagnostic.sh
- ~~`script_debug.sh`~~ - устаревший файл

## 🔧 Устранение проблем

### Если установка зависает
```bash
# Очистите блокировки APT
pkill -f "apt"
rm -f /var/lib/apt/lists/lock
rm -f /var/cache/apt/archives/lock
rm -f /var/lib/dpkg/lock*
dpkg --configure -a

# Запустите диагностику
./diagnostic.sh
```

### Если порты закрыты
```bash
# Настройте файрвол
wget https://raw.githubusercontent.com/Traffic-Connect/tc_fast_setup/main/firewall_fixed.sh
chmod +x firewall_fixed.sh
./firewall_fixed.sh
```

### Если проблемы с аутентификацией
```bash
# Исправьте аутентификацию
wget https://raw.githubusercontent.com/Traffic-Connect/tc_fast_setup/main/fix_auth.sh
chmod +x fix_auth.sh
./fix_auth.sh
```

## 🌐 Доступ к сервисам

После установки будут доступны следующие интерфейсы:

| Сервис | URL | Логин | Пароль |
|--------|-----|-------|--------|

| Grafana | http://IP:3000 | TrafficGrafana | JRPhqZbDgAZAoFPh |
| Prometheus | http://IP:9090 | TrafficPrometheus | EL8YcD649BB80rZM |
| Loki | http://IP:3100 | TrafficLoki | 6wnakjz8nvEV1YAf |
| Pushgateway | http://IP:9091 | TrafficPushgateway | 9MBikpzCHrDeey3 |

## 📊 Мониторинг

### Метрики системы
- CPU, RAM, диск
- Сетевая активность
- Температура (если доступно)
- Процессы и сервисы

### Логи
- Системные логи
- Логи веб-серверов
- Логи безопасности
- Логи приложений

### Алерты
- Высокая нагрузка
- Мало места на диске
- Проблемы с сервисами
- Подозрительная активность

## 🛡️ Безопасность

### Настроенная защита
- **Fail2ban** - блокировка подозрительных IP
- **Firewall** - только необходимые порты открыты
- **Аутентификация** - защищенные пароли
- **Логирование** - отслеживание активности
- **DDoS защита** - ограничение запросов

### Рекомендации
- Регулярно обновляйте систему
- Меняйте пароли по умолчанию
- Настройте резервное копирование
- Мониторьте логи безопасности

## 🔄 Обновления

### Обновление системы
```bash
apt update && apt upgrade -y
```

### Обновление скриптов
```bash
# Скачайте последние версии
wget https://raw.githubusercontent.com/Traffic-Connect/tc_fast_setup/main/script.sh
wget https://raw.githubusercontent.com/Traffic-Connect/tc_fast_setup/main/diagnostic.sh
chmod +x script.sh diagnostic.sh
```

## 📝 Логи

### Основные логи
- `/var/log/grafana/grafana.log` - логи Grafana
- `/var/log/prometheus/` - логи Prometheus
- `/var/log/loki/` - логи Loki
- `/var/log/promtail/` - логи Promtail
- `/var/log/fail2ban.log` - логи Fail2ban

### Просмотр логов
```bash
# Логи сервиса
journalctl -u grafana-server -f

# Системные логи
tail -f /var/log/syslog

# Логи безопасности
tail -f /var/log/auth.log
```

## 🤝 Поддержка

### Полезные команды
```bash
# Статус сервисов
systemctl status grafana-server prometheus loki

# Перезапуск сервиса
systemctl restart grafana-server

# Проверка портов
netstat -tlnp | grep -E ":(3000|9090|3100)"

# Диагностика
./diagnostic.sh
```

### Частые проблемы
1. **Сервисы не запускаются** - проверьте логи: `journalctl -u <service>`
2. **Порты закрыты** - запустите: `./firewall_fixed.sh`
3. **Проблемы с аутентификацией** - запустите: `./fix_auth.sh`
4. **Мало места** - очистите логи: `journalctl --vacuum-time=7d`

## 📈 Производительность

### Рекомендуемые требования
- **CPU**: 2+ ядра
- **RAM**: 4+ GB
- **Диск**: 20+ GB
- **ОС**: Ubuntu 20.04+ / 22.04+

### Оптимизация
- Настройте ротацию логов
- Ограничьте количество метрик
- Используйте SSD диски
- Настройте мониторинг ресурсов

## 🎯 Цели проекта

- ✅ Быстрая установка системы мониторинга
- ✅ Автоматическая настройка безопасности
- ✅ Простота использования
- ✅ Полная диагностика системы
- ✅ Легкое устранение проблем

## 📄 Лицензия

Этот проект распространяется под лицензией MIT. См. файл LICENSE для подробностей.

---

**🚀 Готово к использованию!** Установите систему мониторинга за несколько минут и получите полный контроль над вашим сервером.
