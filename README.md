# Traffic Connect Server - Модульная версия

🚀 **Универсальный сервер для управления веб-проектами с улучшенной модульной архитектурой**

## 📋 Описание

Traffic Connect Server - это комплексное решение для быстрого развертывания и управления веб-серверами. Система включает в себя Hestia Control Panel, компоненты безопасности, мониторинг и готовые шаблоны.

## 🏗️ Архитектура

Проект разделен на логические модули для улучшения:
- **Читаемости кода**
- **Поддерживаемости**
- **Переиспользования**
- **Тестирования**

### 📁 Структура проекта

```
traffic-connect-server/
├── README.md                    # Документация
├── install.sh                   # Главный установщик
├── manager.sh                   # Главный менеджер
├── config/
│   └── main.conf               # Основная конфигурация
├── modules/
│   ├── core/                   # Основные модули
│   │   ├── system_check.sh     # Проверка системы
│   │   ├── logging.sh          # Система логирования
│   │   ├── password_gen.sh     # Генерация паролей
│   │   └── utils.sh            # Общие утилиты
│   ├── installers/             # Модули установки
│   │   ├── hestia_install.sh   # Установка HestiaCP
│   │   ├── security_install.sh # Установка безопасности
│   │   ├── monitoring_install.sh # Установка мониторинга
│   │   └── templates_install.sh # Установка шаблонов
│   ├── managers/               # Модули управления
│   │   ├── service_manager.sh  # Управление службами
│   │   ├── config_manager.sh   # Управление конфигурациями
│   │   └── log_manager.sh      # Управление логами
│   └── tools/                  # Инструменты
│       ├── check_hestia.sh     # Проверка HestiaCP
│       ├── fix_install.sh      # Исправление установки
│       └── stop_composer.sh    # Остановка Composer
├── templates/                  # Веб-шаблоны
│   ├── nginx/
│   ├── apache/
│   └── php/
└── docs/                       # Документация
    ├── INSTALLATION.md
    ├── CONFIGURATION.md
    └── TROUBLESHOOTING.md
```

## 🚀 Быстрый старт

### Требования

- **ОС:** Ubuntu 20.04/22.04, Debian 11/12
- **Права:** root
- **Интернет:** активное подключение
- **Место:** минимум 10GB свободного места
- **RAM:** минимум 2GB

### Установка

1. **Клонирование репозитория:**
   ```bash
   git clone https://github.com/Traffic-Connect/tc_fast_setup.git
   cd tc_fast_setup
   ```

2. **Запуск установки:**
   ```bash
   sudo bash install.sh --install
   ```

3. **Доступ к панели управления:**
   - URL: `https://your-server-ip:8083`
   - Пользователь: `TrafficAdmin`
   - Пароль: сгенерированный автоматически

## 🔧 Модули

### Core Modules (core/)

#### system_check.sh
- Проверка совместимости системы
- Проверка прав доступа
- Проверка сетевого подключения
- Проверка ресурсов системы

#### logging.sh
- Система логирования с уровнями
- JSON логирование
- Поиск и статистика логов
- Автоматическая очистка

#### password_gen.sh
- Генерация безопасных паролей
- Различные уровни сложности
- Хеширование паролей

#### utils.sh
- Общие утилиты
- Вспомогательные функции
- Проверки и валидации

### Installer Modules (installers/)

#### hestia_install.sh
- Установка Hestia Control Panel
- Автоматическая настройка
- Обработка ошибок
- Отключение проблемных компонентов

#### security_install.sh
- Настройка firewall
- Установка fail2ban
- Конфигурация безопасности
- SSL сертификаты

#### monitoring_install.sh
- Установка Prometheus
- Установка Grafana
- Настройка мониторинга
- Дашборды

#### templates_install.sh
- Установка веб-шаблонов
- Конфигурация Nginx/Apache
- PHP настройки

### Manager Modules (managers/)

#### service_manager.sh
- Управление системными службами
- Статус служб
- Перезапуск служб
- Автозапуск

#### config_manager.sh
- Управление конфигурациями
- Бэкап настроек
- Восстановление
- Валидация

#### log_manager.sh
- Управление логами
- Ротация логов
- Анализ логов
- Уведомления

### Tool Modules (tools/)

#### check_hestia.sh
- Проверка статуса HestiaCP
- Диагностика проблем
- Рекомендации

#### fix_install.sh
- Исправление проблем установки
- Восстановление после сбоев
- Очистка системы

#### stop_composer.sh
- Остановка зависших процессов
- Принудительное завершение
- Очистка временных файлов

## 📊 Возможности

### 🌐 Веб-управление
- Hestia Control Panel
- Управление доменами
- Базы данных
- Почтовые сервисы

### 🛡️ Безопасность
- Firewall (iptables)
- Fail2ban защита
- SSL сертификаты
- Безопасные пароли

### 📈 Мониторинг
- Prometheus метрики
- Grafana дашборды
- Логирование
- Уведомления

### 🎨 Шаблоны
- Готовые конфигурации
- Nginx/Apache настройки
- PHP оптимизация
- SSL настройки

## 🔍 Использование

### Основные команды

```bash
# Полная установка
sudo bash install.sh --install

# Проверка статуса HestiaCP
sudo bash modules/tools/check_hestia.sh

# Исправление проблем
sudo bash modules/tools/fix_install.sh

# Остановка зависших процессов
sudo bash modules/tools/stop_composer.sh
```

### Управление службами

```bash
# Статус всех служб
sudo bash manager.sh --services-status

# Перезапуск служб
sudo bash manager.sh --services-restart

# Бэкап конфигураций
sudo bash manager.sh --config-backup
```

## 🐛 Устранение неполадок

### Частые проблемы

1. **Ошибка прав доступа:**
   ```bash
   sudo chown -R root:root /usr/local/hestia
   sudo chmod -R 755 /usr/local/hestia
   ```

2. **Проблемы с Composer:**
   ```bash
   sudo bash modules/tools/stop_composer.sh
   ```

3. **Проблемы с портами:**
   ```bash
   sudo netstat -tlnp | grep :8083
   sudo systemctl restart admin
   ```

### Логи

```bash
# Просмотр логов
sudo tail -f /var/log/install/traffic_connect.log

# Поиск ошибок
sudo grep "ERROR" /var/log/install/traffic_connect.log

# Статистика логов
sudo bash manager.sh --logs-statistics
```

## 🤝 Поддержка

- **Документация:** [docs/](docs/)
- **Issues:** [GitHub Issues](https://github.com/Traffic-Connect/tc_fast_setup/issues)
- **Discussions:** [GitHub Discussions](https://github.com/Traffic-Connect/tc_fast_setup/discussions)

## 📄 Лицензия

MIT License - см. файл [LICENSE](LICENSE)

## 🙏 Благодарности

- [Hestia Control Panel](https://hestiacp.com/) - основа системы
- [Prometheus](https://prometheus.io/) - мониторинг
- [Grafana](https://grafana.com/) - визуализация
- Сообщество разработчиков

---

**Сделано с ❤️ для сообщества**
