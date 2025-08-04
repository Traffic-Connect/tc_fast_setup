# Traffic Connect Server Installation

Комплексный установщик для сервера с HestiaCP, системой мониторинга и дополнительными компонентами.

## 🚀 Возможности

### Основные компоненты
- **HestiaCP** - Панель управления сервером
- **Grafana** - Визуализация метрик и логов
- **Prometheus** - Сбор и хранение метрик
- **Loki** - Агрегация логов
- **Node Exporter** - Экспорт системных метрик
- **Pushgateway** - Прием push-метрик
- **Fail2Ban** - Защита от атак

### Дополнительные компоненты
- **Шаблоны Nginx** - Оптимизированные конфигурации
- **Schemes Scripts** - Скрипты для автоматизации
- **Link Manager** - Управление ссылками
- **BadBot Protection** - Защита от ботов

## 🔧 Установка

### Быстрая установка
```bash
# Скачивание и запуск
wget https://github.com/Traffic-Connect/installer/archive/main.zip
unzip main.zip
cd installer-main
sudo ./install.sh --full
```

### Интерактивная установка
```bash
sudo ./install.sh
```

### Выборочная установка
```bash
# Только HestiaCP
sudo ./install.sh --hestia

# Только мониторинг
sudo ./install.sh --monitoring

# Только дополнительные компоненты
sudo ./install.sh --additional
```

## ⚙️ Настройка

### Интерактивная настройка
```bash
sudo ./install.sh --config
```

### Валидация конфигурации
```bash
sudo ./install.sh --validate
```

### Просмотр метрик системы
```bash
sudo ./install.sh --metrics
```

## 🧪 Тестирование

### Запуск всех тестов
```bash
sudo ./install.sh --test
```

### Запуск отдельных тестов
```bash
# Unit тесты
sudo ./tests/unit/test_common.sh

# Интеграционные тесты
sudo ./tests/integration/test_installation.sh

# Все тесты
sudo ./tests/run_all_tests.sh
```

## 🌐 Веб-интерфейс

### Запуск GUI
```bash
sudo ./install.sh --gui
```

### Ручной запуск
```bash
cd web
sudo ./start_gui.sh
```

## 🔒 Безопасность

### Улучшенная генерация паролей
- **Низкая сложность**: Только буквы и цифры
- **Средняя сложность**: Буквы, цифры, базовые символы
- **Высокая сложность**: Все символы, максимальная безопасность

### Проверка целостности
- SHA256 проверка загруженных файлов
- GPG проверка подписей
- SSL проверка соединений

### Автоматический rollback
- Откат при ошибках установки
- Резервное копирование логов
- Детальный журнал изменений

## 📊 Мониторинг и метрики

### Сбор метрик
- Время установки компонентов
- Использование ресурсов системы
- Производительность установки

### Логирование
- Структурированные JSON логи
- Настраиваемые уровни логирования
- Автоматическая ротация логов

## ⚡ Оптимизация производительности

### Параллельная установка
- Установка независимых компонентов параллельно
- Настраиваемое количество параллельных процессов
- Оптимизация времени установки

### Кэширование
- Кэширование загруженных файлов
- Проверка целостности кэша
- Настраиваемое время жизни кэша

## 🔧 Конфигурация

### Основные параметры
```bash
# Порты сервисов
GRAFANA_PORT="3000"
PROMETHEUS_PORT="9090"
LOKI_PORT="3100"
HESTIA_PORT="8083"

# Безопасность
VERIFY_CHECKSUMS=true
SSL_VERIFY=true
GPG_VERIFY=true
ENABLE_ROLLBACK=true

# Производительность
MAX_PARALLEL_JOBS=4
DOWNLOAD_CHUNK_SIZE=8192
COMPRESSION_LEVEL=6

# Логирование
LOG_LEVEL="INFO"
LOG_FORMAT="JSON"
ENABLE_JSON_LOGGING=true
```

### Пользовательская конфигурация
Создайте файл `config.local.sh` для переопределения настроек:
```bash
# config.local.sh
GRAFANA_PORT="3001"
PROMETHEUS_PORT="9091"
LOG_LEVEL="DEBUG"
```

## 📁 Структура проекта

```
Install/
├── Components/           # Шаблоны Nginx
├── lib/                 # Библиотеки функций
│   ├── common.sh       # Общие функции
│   └── interactive.sh  # Интерактивный режим
├── tools/              # Дополнительные компоненты
│   ├── templates.sh    # Установка шаблонов
│   ├── schemes.sh      # Schemes Scripts
│   ├── link_manager.sh # Link Manager
│   └── badbot.sh       # BadBot защита
├── tests/              # Тесты
│   ├── unit/           # Unit тесты
│   ├── integration/    # Интеграционные тесты
│   └── run_all_tests.sh
├── web/                # Веб-интерфейс
├── config.sh           # Основная конфигурация
├── install.sh          # Главный установщик
├── install_complete.sh # Полная установка
└── install_tools.sh    # Дополнительные компоненты
```

## 🚨 Системные требования

### Минимальные требования
- **ОС**: Ubuntu 20.04+ или Debian 11+
- **Архитектура**: x86_64
- **Память**: 1GB RAM
- **Диск**: 2GB свободного места
- **Сеть**: Интернет соединение

### Рекомендуемые требования
- **ОС**: Ubuntu 22.04 LTS
- **Архитектура**: x86_64
- **Память**: 4GB RAM
- **Диск**: 10GB свободного места
- **Сеть**: Стабильное интернет соединение

## 🔍 Диагностика

### Проверка статуса сервисов
```bash
# Проверка всех сервисов
systemctl status grafana-server prometheus loki node_exporter pushgateway

# Просмотр логов
journalctl -u grafana-server -f
journalctl -u prometheus -f
journalctl -u loki -f
```

### Проверка портов
```bash
# Проверка занятых портов
netstat -tlnp | grep -E ':(3000|9090|3100|8083)'

# Проверка доступности сервисов
curl http://localhost:3000  # Grafana
curl http://localhost:9090  # Prometheus
curl http://localhost:3100  # Loki
```

### Просмотр логов установки
```bash
# Основные логи
tail -f /var/log/install/install_*.log

# JSON логи
tail -f /var/log/install/install.json

# Метрики установки
cat /var/log/install/installation_metrics.log
```

## 🛠️ Устранение неполадок

### Частые проблемы

#### 1. Недостаточно места на диске
```bash
# Проверка места
df -h

# Очистка кэша
sudo rm -rf /var/cache/install/*
```

#### 2. Порт уже занят
```bash
# Поиск процесса
sudo netstat -tlnp | grep :3000

# Изменение порта в конфигурации
GRAFANA_PORT="3001"
```

#### 3. Ошибки загрузки
```bash
# Проверка интернета
ping 8.8.8.8

# Проверка DNS
nslookup github.com

# Очистка кэша и повторная загрузка
sudo rm -rf /var/cache/install/*
```

#### 4. Ошибки установки компонентов
```bash
# Просмотр детальных логов
sudo journalctl -u grafana-server -n 50

# Перезапуск сервиса
sudo systemctl restart grafana-server

# Проверка конфигурации
sudo grafana-server --config /etc/grafana/grafana.ini --homepath /usr/share/grafana
```

## 🔄 Обновление

### Обновление установщика
```bash
# Скачивание новой версии
wget https://github.com/Traffic-Connect/installer/archive/main.zip
unzip main.zip
cd installer-main

# Запуск обновления
sudo ./install.sh --update
```

### Обновление компонентов
```bash
# Обновление Grafana
sudo apt update && sudo apt upgrade grafana

# Обновление Prometheus
sudo systemctl stop prometheus
# Скачать новую версию и заменить
sudo systemctl start prometheus
```

## 📞 Поддержка

### Логи для диагностики
```bash
# Сбор логов для поддержки
sudo tar -czf support_logs.tar.gz /var/log/install/ /var/log/grafana/ /var/log/prometheus/
```

### Полезные команды
```bash
# Проверка версий
grafana-server --version
prometheus --version
loki --version

# Проверка конфигурации
nginx -t
grafana-server --config /etc/grafana/grafana.ini --homepath /usr/share/grafana --config:defaults
```

## 📝 Changelog

### Версия 2.0.0
- ✅ Улучшенная генерация паролей с настраиваемой сложностью
- ✅ Расширенная обработка ошибок и автоматический rollback
- ✅ Параллельная установка компонентов
- ✅ Структурированное JSON логирование
- ✅ Система метрик и мониторинга установки
- ✅ Интерактивная настройка конфигурации
- ✅ Улучшенные unit и интеграционные тесты
- ✅ Проверка целостности файлов и GPG подписей
- ✅ Оптимизация производительности и кэширование
- ✅ Расширенная валидация и диагностика

### Версия 1.0.0
- Базовая установка компонентов
- Простое логирование
- Базовые проверки системы

## 📄 Лицензия

MIT License - см. файл LICENSE для подробностей.

## 🤝 Вклад в проект

1. Форкните репозиторий
2. Создайте ветку для новой функции
3. Внесите изменения
4. Добавьте тесты
5. Создайте Pull Request

## ⚠️ Отказ от ответственности

Этот установщик предназначен для использования на тестовых и продакшн серверах. Авторы не несут ответственности за любые повреждения или потерю данных. Всегда делайте резервные копии перед установкой. 