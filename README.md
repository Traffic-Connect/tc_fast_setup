<<<<<<< HEAD
# 🚀 Автоматизация сервера: HestiaCP, Grafana, Prometheus, Loki, Fail2Ban, Firewall

> **Универсальный Bash-скрипт для быстрого развёртывания и настройки современной серверной инфраструктуры мониторинга и управления на Ubuntu/Debian.**

----

## 📋 Описание

Этот скрипт автоматически устанавливает и настраивает:
- [HestiaCP](https://hestiacp.com/) — удобная панель управления сервером
- [Grafana](https://grafana.com/), [Prometheus](https://prometheus.io/), [Node Exporter](https://prometheus.io/docs/guides/node-exporter/), [Pushgateway](https://prometheus.io/docs/practices/pushing/) — инструменты мониторинга
- [Loki](https://grafana.com/oss/loki/) и [Promtail](https://grafana.com/docs/loki/latest/clients/promtail/) — сбор и просмотр логов
- [Fail2Ban](https://www.fail2ban.org/) — защита от брутфорса и бот-атак
- **Современный Firewall** — nftables с fallback на iptables

## 🆕 Последние обновления (v2.0)

### ✅ Исправленные ошибки:
- **Критическая ошибка кодировки** в `1.sh` - исправлена
- **Синтаксические ошибки** - все файлы проверены и исправлены
- **Обработка ошибок** - добавлена во все скрипты
- **Зависимости** - улучшена проверка и установка

### 🚀 Новые возможности:
- **Современный firewall** - поддержка nftables с автоматическим fallback на iptables
- **Улучшенная безопасность** - защита от брутфорса, DDoS, портовых сканеров
- **Централизованная конфигурация** - файл `config.sh` для всех настроек
- **Управление firewall** - скрипт `fw.sh` для удобного управления
- **Логирование** - подробное логирование всех операций
- **Проверки** - валидация конфигурации и зависимостей

### 🔧 Улучшения:
- **Модульная архитектура** - разделение на логические блоки
- **Обработка ошибок** - graceful handling всех возможных ошибок
- **Документация** - подробные комментарии и справка
- **Безопасность** - ограничение доступа к мониторингу только с localhost

---

## 🧩 Функционал

### 🔒 Безопасность
1. **Современный firewall** (nftables/iptables)
2. **Защита от брутфорса** SSH (rate limiting)
3. **DDoS защита** (SYN flood, port scanning)
4. **Fail2Ban** с расширенными правилами
5. **Логирование** подозрительной активности

### 📊 Мониторинг
1. **Grafana** - визуализация метрик
2. **Prometheus** - сбор метрик
3. **Node Exporter** - системные метрики
4. **Loki + Promtail** - сбор логов
5. **Pushgateway** - push-метрики

### 🛠️ Управление
1. **HestiaCP** - веб-панель управления
2. **Конфигурация** - централизованные настройки
3. **Firewall management** - удобное управление правилами
4. **Автоматизация** - полная автоматизация установки

---

## ⚡ Быстрый старт

### 1. Подготовка
```bash
git clone https://github.com/Traffic-Connect/tc-fast-setup .
chmod +x *.sh
```

### 2. Настройка (опционально)
```bash
# Редактируйте конфигурацию
nano config.sh

# Или используйте интерактивную настройку
./config.sh show
```

### 3. Установка
```bash
# Основная установка
sudo ./script.sh

# Или улучшенная версия
sudo ./1.sh

# Дополнительная настройка логов
sudo ./2.sh
```

### 4. Управление
```bash
# Управление firewall
sudo ./fw.sh status
sudo ./fw.sh block 192.168.1.100
sudo ./fw.sh cloudflare

# Управление конфигурацией
./config.sh validate
./config.sh save my_config.conf
```

---

## 🖥️ Получаемые сервисы

| Сервис | URL | Логин | Пароль |
|--------|-----|-------|--------|
| **HestiaCP** | `http://<server_ip>:8083` | admin | см. файл |
| **Grafana** | `http://<server_ip>:3000` | admin | admin |
| **Prometheus** | `http://<server_ip>:9090` | - | - |
| **Loki** | `http://<server_ip>:3100` | - | - |
| **Pushgateway** | `http://<server_ip>:9091` | - | - |

> **Пароль HestiaCP:** `/usr/local/hestia/data/users/admin/password.conf`  
> **⚠️ ВАЖНО:** Смените все пароли после установки!

---

## 🔒 Безопасность

### Firewall правила:
- **SSH:** Rate limiting (5/min)
- **HTTP/HTTPS:** Открыты для всех
- **HestiaCP:** Порт 8083
- **Мониторинг:** Только localhost (127.0.0.1)
- **Cloudflare:** Автоматическое добавление IP

### Защита от атак:
- **SYN flood:** 10/second burst 25
- **Port scanning:** 1/second
- **ICMP:** 1/second
- **Brute force:** Fail2Ban с расширенными правилами

---

## ⚙️ Требования

- **ОС:** Ubuntu 20.04+, Debian 10+
- **RAM:** Минимум 1 ГБ (рекомендуется 2+ ГБ)
- **Диск:** Минимум 10 ГБ свободного места
- **Права:** root (`sudo`)

---

## 📦 Структура проекта

```
tc-fast-setup/
├── script.sh      # Основной скрипт установки
├── 1.sh          # Улучшенная версия с современным firewall
├── 2.sh          # Настройка логов и GeoIP
├── fw.sh         # Управление firewall
├── config.sh     # Централизованная конфигурация
└── README.md     # Документация
```

---

## 🛠️ Управление

### Firewall (fw.sh)
```bash
./fw.sh status          # Статус firewall
./fw.sh stats           # Статистика
./fw.sh block IP        # Блокировка IP
./fw.sh unblock IP      # Разблокировка IP
./fw.sh cloudflare      # Обновление Cloudflare IP
```

### Конфигурация (config.sh)
```bash
./config.sh validate    # Проверка настроек
./config.sh show        # Показать все настройки
./config.sh save file   # Сохранить конфигурацию
./config.sh load file   # Загрузить конфигурацию
```

---

## 🏁 После установки

### 1. Смена паролей
```bash
# HestiaCP
cat /usr/local/hestia/data/users/admin/password.conf

# Grafana
# Войдите в веб-интерфейс и смените пароль
```

### 2. Настройка мониторинга
- Импортируйте дашборды в Grafana
- Настройте алерты
- Добавьте дополнительные источники данных

### 3. Обновления
```bash
# Автоматические обновления
apt update && apt upgrade -y

# Обновление конфигурации
./config.sh save backup.conf
```

---

## 📝 FAQ

**Q: Какой firewall используется?**  
A: Автоматически выбирается nftables (современный) или iptables (fallback)

**Q: Как изменить настройки?**  
A: Отредактируйте `config.sh` или используйте `./config.sh save/load`

**Q: Как заблокировать IP?**  
A: `sudo ./fw.sh block 192.168.1.100`

**Q: Порты не открыты?**  
A: Проверьте firewall облачного провайдера и правила в `fw.sh status`

**Q: Логи не собираются?**  
A: Проверьте статус Promtail: `systemctl status promtail`

---

## 🧑‍💻 Автор

- **TrafficConnect**

---

## 🤝 Лицензия

Используйте и модифицируйте свободно под свои нужды!  
Если будут предложения по улучшению — создавайте PR или пишите в Issues.

---

## 📈 Статистика исправлений

| Файл | Статус | Исправления |
|------|--------|-------------|
| `1.sh` | ✅ **ИСПРАВЛЕН** | Кодировка, синтаксис, firewall |
| `script.sh` | ✅ **ОБНОВЛЕН** | Современный firewall |
| `2.sh` | ✅ **УЛУЧШЕН** | Обработка ошибок |
| `fw.sh` | ✅ **УЛУЧШЕН** | Проверки зависимостей |
| `config.sh` | ✅ **НОВЫЙ** | Централизованная конфигурация |

**Удачной автоматизации!** 🚀
=======
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

- **ОС:** Ubuntu 20.04/22.04, Debian 11/12, CentOS 8/Rocky Linux 8
- **Права:** root
- **Интернет:** активное подключение
- **Место:** минимум 10GB свободного места
- **RAM:** минимум 2GB

### Установка

#### 🚀 Способ 1: Быстрая установка (рекомендуется)

```bash
# Загрузка и запуск в одну команду
curl -sSL https://raw.githubusercontent.com/Traffic-Connect/tc_fast_setup/main/quick_install.sh | sudo bash
```

#### 📦 Способ 2: Ручная установка

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

### 📋 Что устанавливается

- **HestiaCP** - панель управления сервером (порт 8083)
- **Nginx** - веб-сервер (порт 80, 443)
- **MySQL** - база данных (порт 3306)
- **PHP-FPM** - обработчик PHP
- **Fail2ban** - защита от атак
- **iptables** - файрвол
- **Grafana** - мониторинг (порт 3000)
- **Prometheus** - метрики (порт 9090)
- **Node Exporter** - системные метрики (порт 9100)
- **Loki** - логи (порт 3100)
- **Веб-шаблоны** - оптимизированные конфигурации

### ⏱️ Время установки

- **Полная установка:** 15-30 минут
- **Зависит от:** скорости интернета и производительности сервера
- **Процесс:** полностью автоматический с подробным логированием

### 🔄 Процесс установки

1. **Проверка системы** - совместимость и требования
2. **Инициализация** - создание директорий и настройка логирования
3. **Установка HestiaCP** - основная панель управления
4. **Настройка безопасности** - fail2ban, iptables, SSH
5. **Установка мониторинга** - Grafana, Prometheus, Loki
6. **Установка шаблонов** - веб-конфигурации
7. **Финальная настройка** - валидация и сохранение данных

### 📄 Результат установки

После установки вы получите:
- **Файл с учетными данными:** `/root/traffic_connect_credentials.txt`
- **Логи установки:** `/var/log/traffic_connect/`
- **Конфигурации:** `/etc/traffic_connect/`
- **Бэкапы:** `/var/backup/traffic_connect/`

## 🧪 Тестирование на сервере

### Подготовка сервера

1. **Создайте новый сервер** с Ubuntu 20.04/22.04 или Debian 11/12
2. **Подключитесь по SSH** с правами root
3. **Убедитесь в стабильном интернет-соединении**

### Быстрое тестирование

```bash
# Способ 1: Прямая загрузка и установка
curl -sSL https://raw.githubusercontent.com/Traffic-Connect/tc_fast_setup/main/quick_install.sh | sudo bash

# Способ 2: Скачивание и запуск
wget https://raw.githubusercontent.com/Traffic-Connect/tc_fast_setup/main/quick_install.sh
chmod +x quick_install.sh
sudo ./quick_install.sh
```

### Проверка установки

После установки проверьте:

```bash
# Статус основных служб
systemctl status admin nginx mysql grafana-server prometheus

# Доступность веб-интерфейсов
curl -I http://localhost:8083  # HestiaCP
curl -I http://localhost:3000  # Grafana
curl -I http://localhost:9090  # Prometheus

# Просмотр учетных данных
cat /root/traffic_connect_credentials.txt

# Просмотр логов
tail -f /var/log/traffic_connect/install.log
```

### Возможные проблемы

- **Ошибка Composer:** автоматически исправляется скриптом
- **Требуется перезагрузка:** подтвердите перезагрузку для завершения установки HestiaCP
- **Проблемы с сетью:** проверьте доступность GitHub и интернет-соединение

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
>>>>>>> 950b0ca21c510bab3800966db3e166b3cf6adab6
