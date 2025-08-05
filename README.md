# Traffic Connect Server - Быстрая установка

Автоматический установщик для сервера с HestiaCP, системой мониторинга и дополнительными компонентами.

## Быстрая установка

```bash
# Скачивание
git clone https://github.com/Traffic-Connect/tc_fast_setup.git
cd tc_fast_setup

# Быстрая установка
sudo ./main-installer.sh

# С настройками
cp configuration.sh config.local.sh
nano config.local.sh
sudo ./main-installer.sh
```

## Компоненты

- **HestiaCP** - Панель управления сервером (порт 8083)
- **Grafana** - Визуализация метрик (порт 3000)
- **Prometheus** - Сбор метрик (порт 9090)
- **Loki** - Агрегация логов (порт 3100)
- **Node Exporter** - Системные метрики (порт 9100)
- **Fail2Ban** - Защита от атак
- **Шаблоны Nginx** - Оптимизированные конфигурации

## Системные требования

- Ubuntu 22.04/24.04
- x86_64 архитектура
- 1GB RAM минимум
- 2GB свободного места
- Интернет соединение

## Пароли и логи

- **Пароли сохраняются в:** `/root/credentials.txt`
- **Логи установки:** `/var/log/install/`

## Структура проекта

```
tc_fast_setup/
├── main-installer.sh              # Главный установщик
├── configuration.sh               # Конфигурация
├── install-stages/                # Этапы установки
│   ├── 01-base-system.sh         # Базовая система
│   ├── 02-security.sh            # Безопасность
│   ├── 03-hestia-cp.sh           # HestiaCP
│   ├── 04-monitoring.sh          # Мониторинг
│   └── 05-templates.sh           # Шаблоны
├── libraries/                     # Библиотеки
│   └── common.sh                  # Общие функции
└── templates/                     # Шаблоны Nginx
```

## Безопасность

- Автоматическая генерация сложных паролей
- Проверка целостности файлов
- Автоматический rollback при ошибках
- Настройка firewall и fail2ban

## Для внутреннего использования сотрудниками компании 