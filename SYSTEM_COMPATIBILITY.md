# Системная совместимость Traffic Connect Server

## 🚨 Проблема: Установка на macOS

**Traffic Connect Server** предназначен исключительно для **Linux серверов** и не поддерживает установку на macOS или Windows.

### ❌ Неподдерживаемые системы:
- macOS (все версии)
- Windows (все версии)
- BSD системы

### ✅ Поддерживаемые системы:
- **Ubuntu 20.04/22.04** (рекомендуется)
- **Debian 11/12**
- **CentOS 8/Rocky Linux 8**

## 🔍 Анализ проблемы

### Почему установка зависает на macOS:

1. **Hestia Control Panel** - основной компонент системы, предназначен только для Linux
2. **systemd** - система управления службами, отсутствует в macOS
3. **apt package manager** - менеджер пакетов Debian/Ubuntu, недоступен в macOS
4. **Linux-специфичные команды** - `useradd`, `systemctl`, `apt install` и др.

### Конкретные проблемы в коде:

```bash
# Эти команды не работают на macOS:
systemctl start admin
apt install -y nginx
useradd -r hestiaweb
chown hestiaweb:hestiaweb /var/spool/cron/crontabs/hestiaweb
```

## 🛠️ Решения для разработки и тестирования

### 1. Docker контейнер (рекомендуется)

```bash
# Создание Ubuntu контейнера
docker run -it --name traffic-server \
  -p 8083:8083 -p 80:80 -p 443:443 \
  ubuntu:22.04 bash

# Внутри контейнера
apt update && apt install -y curl wget git
git clone https://github.com/Traffic-Connect/tc_fast_setup.git
cd tc_fast_setup
bash traffic_manager_new.sh
```

### 2. Виртуальная машина

**Рекомендуемые настройки:**
- **ОС:** Ubuntu 22.04 LTS
- **RAM:** 2-4 GB
- **Диск:** 20-40 GB
- **Процессоры:** 2-4 ядра

### 3. Облачный сервер (VPS)

**Популярные провайдеры:**
- DigitalOcean
- Linode
- Vultr
- Hetzner
- AWS EC2

## 🔧 Исправления в коде

### Добавлены проверки совместимости:

1. **В `traffic_manager_new.sh`:**
   ```bash
   check_system_compatibility() {
       if [[ "$OSTYPE" == "darwin"* ]]; then
           log_err "❌ Traffic Connect Server не поддерживается на macOS"
           return 1
       fi
   }
   ```

2. **В `hestia_install.sh`:**
   ```bash
   if [[ "$OSTYPE" == "darwin"* ]]; then
       log_err "❌ HestiaCP не поддерживается на macOS"
       return 1
   fi
   ```

## 📋 Чек-лист для правильной установки

- [ ] Используйте Linux сервер (Ubuntu/Debian)
- [ ] Убедитесь в наличии прав root
- [ ] Проверьте подключение к интернету
- [ ] Убедитесь в достаточном месте на диске (минимум 10GB)
- [ ] Проверьте доступность портов 80, 443, 8083

## 🚀 Быстрый старт на Linux сервере

```bash
# 1. Подключение к серверу
ssh root@your-server-ip

# 2. Клонирование репозитория
git clone https://github.com/Traffic-Connect/tc_fast_setup.git
cd tc_fast_setup

# 3. Запуск установки
bash traffic_manager_new.sh

# 4. Следование инструкциям установщика
```

## 📞 Поддержка

При возникновении проблем:
1. Проверьте совместимость системы
2. Убедитесь в выполнении всех требований
3. Проверьте логи установки
4. Обратитесь к документации проекта

---

**Важно:** Traffic Connect Server - это серверное решение для Linux, не предназначенное для настольных систем.
