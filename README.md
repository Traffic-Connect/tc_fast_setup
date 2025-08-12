# 🚀 TC Fast Setup - Быстрая установка системы мониторинга

Автоматический скрипт для установки полноценной системы мониторинга на Ubuntu VPS с Grafana, Prometheus, Loki и другими компонентами.

## 📋 Что устанавливается

### 🌐 Веб-интерфейсы
- **Grafana** - дашборды мониторинга (порт 3000)
- **Prometheus** - сбор метрик (порт 9090)
- **Loki** - агрегация логов (порт 3100)
- **Pushgateway** - прием метрик (порт 9091)
- **Hestia CP** - панель управления сервером (порт 8083)

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

### 2. Установка полного стека
```bash
# Скачайте скрипт
wget https://raw.githubusercontent.com/Traffic-Connect/tc_fast_setup/main/main.sh

# Сделайте исполняемым
chmod +x main.sh

# Запустите установку
./main.sh
```

### 3. Установка только Hestia CP
```bash
# Скачиваем скрипт установки Hestia CP
wget https://raw.githubusercontent.com/Traffic-Connect/tc_fast_setup/main/install_hestia.sh

# Делаем исполняемым
chmod +x install_hestia.sh

# Запускаем установку
sudo bash install_hestia.sh
```

### 4. Интерактивный менеджер модулей
```bash
# Скачайте менеджер модулей
wget https://raw.githubusercontent.com/Traffic-Connect/tc_fast_setup/main/scripts/module_manager.sh

# Сделайте исполняемым
chmod +x scripts/module_manager.sh

# Запустите менеджер
./scripts/module_manager.sh
```

## 🌐 Доступ к сервисам

После установки будут доступны следующие интерфейсы:

| Сервис | URL | Логин | Пароль |
|--------|-----|-------|--------|
| Grafana | http://IP:3000 | admin | admin |
| Prometheus | http://IP:9090 | - | - |
| Loki | http://IP:3100 | - | - |
| Pushgateway | http://IP:9091 | - | - |
| Hestia CP | https://IP:8083 | admin | генерируется автоматически |

## 📁 Структура проекта

```
tc-fast-setup-main/
├── main.sh                 # 🚀 Главный скрипт установки
├── install_hestia.sh       # 🎛️ Установка Hestia CP
├── diagnostic.sh          # 🔍 Диагностика системы
├── firewall_fixed.sh      # 🔥 Настройка файрвола
├── script_old.sh          # 📜 Архив старого кода
│
├── core/                  # 🔧 Основные модули
│   ├── colors.sh         # 🎨 Цвета и символы
│   ├── utils.sh          # 🛠️ Утилиты
│   ├── system.sh         # 💻 Системные операции
│   ├── installer.sh      # 🚀 Главный установщик
│   └── config.sh         # ⚙️ Конфигурация
│
├── modules/              # 📦 Модули сервисов
│   ├── grafana.sh        # 📊 Grafana
│   ├── prometheus.sh     # 📈 Prometheus
│   ├── node_exporter.sh  # 🖥️ Node Exporter
│   ├── pushgateway.sh    # 📤 Pushgateway
│   ├── loki.sh           # 📝 Loki и Promtail
│   ├── fail2ban.sh       # 🛡️ Fail2Ban
│   ├── fail2ban_exporter.sh # 📊 Fail2Ban Exporter
│   └── firewall.sh       # 🔥 Firewall
│
├── output/               # 📺 Отображение результатов
│   └── display.sh        # 🎨 Функции отображения
│
├── config/               # ⚙️ Конфигурация
│   └── settings.conf     # 📋 Основные настройки
│
└── scripts/              # 🔧 Дополнительные скрипты
    └── module_manager.sh # 🎛️ Интерактивный менеджер
```

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
./firewall_fixed.sh
```

### Диагностика системы
```bash
# Запустите полную диагностику
./diagnostic.sh
```

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
wget https://raw.githubusercontent.com/Traffic-Connect/tc_fast_setup/main/main.sh
wget https://raw.githubusercontent.com/Traffic-Connect/tc_fast_setup/main/diagnostic.sh
chmod +x main.sh diagnostic.sh
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
3. **Проблемы с аутентификацией** - проверьте конфигурацию
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
- ✅ Модульная архитектура
- ✅ Интерактивный менеджер

## 📄 Лицензия

Этот проект распространяется под лицензией MIT.

---

**🚀 Готово к использованию!** Установите систему мониторинга за несколько минут и получите полный контроль над вашим сервером.
