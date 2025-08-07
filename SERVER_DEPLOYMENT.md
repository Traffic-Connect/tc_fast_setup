# 🚀 ИНСТРУКЦИЯ ПО РАЗВЕРТЫВАНИЮ НА СЕРВЕРЕ

## 📋 ПОДГОТОВКА К УСТАНОВКЕ

### 1. Клонирование репозитория
```bash
# Клонируем обновленный репозиторий
git clone https://github.com/Traffic-Connect/tc_fast_setup.git
cd tc_fast_setup

# Проверяем последний коммит
git log --oneline -1
# Должен показать: 🔒 Полное соответствие политике безопасности TrafficConnect
```

### 2. Проверка файлов безопасности
```bash
# Проверяем наличие всех файлов безопасности
ls -la *.md | grep -E "(SECURITY|PRODUCTION)"
ls -la check_security.sh
ls -la system/security/security_policy.sh

# Проверяем, что примеры удалены
ls -la docs/examples/ 2>/dev/null || echo "✅ Директория examples удалена"
ls -la system/security/security_examples.sh 2>/dev/null || echo "✅ Файл security_examples.sh удален"
ls -la web/configs/config.example.sh 2>/dev/null || echo "✅ Файл config.example.sh удален"
```

## 🔧 УСТАНОВКА

### 1. Запуск установки
```bash
# Делаем скрипт исполняемым
chmod +x install.sh
chmod +x check_security.sh

# Запускаем установку
sudo bash install.sh
```

### 2. Ожидаемый результат установки
- ✅ Все пароли сгенерированы автоматически (18 символов)
- ✅ Созданы пользователи: TrafficAdmin, TrafficMetrics, TrafficMonitor, etc.
- ✅ SSH настроен: root по паролю, пользователи по ключам
- ✅ Все пароли отображены в конце установки
- ✅ Файлы с паролями сохранены в `/root/.traffic_connect/`

## 🔍 ПРОВЕРКА БЕЗОПАСНОСТИ

### 1. Запуск проверки безопасности
```bash
sudo bash check_security.sh
```

### 2. Ожидаемые результаты проверки
- ✅ SSH root доступ включен (согласно политике)
- ✅ SSH аутентификация по ключам включена
- ✅ Группа ssh-users настроена
- ✅ Все пользователи мониторинга созданы
- ✅ Общий балл безопасности: 80+/100

### 3. Проверка пользователей
```bash
# Проверяем созданных пользователей
for user in TrafficMetrics TrafficMonitor TrafficLogger TrafficNode TrafficPush TrafficFail2Ban; do
    id "$user" && echo "✅ $user существует" || echo "❌ $user не найден"
done

# Проверяем группу ssh-users
getent group ssh-users
```

## 🔐 ПРОВЕРКА ПАРОЛЕЙ

### 1. Проверка файлов с паролями
```bash
# Основной файл с паролями
cat /root/.traffic_connect/credentials.txt

# SSH доступ
cat /root/.traffic_connect/ssh_access.txt
```

### 2. Проверка соответствия политике
```bash
# Загружаем политику безопасности
source system/security/security_policy.sh

# Проверяем пароли (замените на реальные пароли)
validate_password_policy "ВАШ_ПАРОЛЬ_ЗДЕСЬ"
assess_password_strength "ВАШ_ПАРОЛЬ_ЗДЕСЬ"
```

## 🌐 ПРОВЕРКА СЕРВИСОВ

### 1. Проверка веб-сервисов
```bash
# Получаем IP сервера
SERVER_IP=$(hostname -I | awk '{print $1}')

# Проверяем доступность сервисов
echo "Проверка сервисов на $SERVER_IP:"
echo "Grafana: http://$SERVER_IP:3000"
echo "Prometheus: http://$SERVER_IP:9090"
echo "Loki: http://$SERVER_IP:3100"
echo "Админ панель: https://$SERVER_IP:8083"
```

### 2. Проверка SSH доступа
```bash
# Проверяем SSH конфигурацию
grep -E "(PermitRootLogin|PasswordAuthentication|Match Group)" /etc/ssh/sshd_config

# Проверяем статус SSH
systemctl status sshd
```

## 📊 ДОКУМЕНТАЦИЯ

### 1. Файлы документации
- `PRODUCTION_SECURITY.md` - Инструкции по безопасности
- `SECURITY_AUDIT_REPORT.md` - Отчет об аудите безопасности
- `SECURITY_POLICY_COMPLIANCE.md` - Отчет о соответствии политике
- `README.md` - Основная документация

### 2. Полезные команды
```bash
# Проверка статуса всех сервисов
systemctl status grafana-server prometheus loki nginx fail2ban

# Просмотр логов
journalctl -u grafana-server -f
journalctl -u prometheus -f
tail -f /var/log/nginx/error.log

# Проверка файрвола
ufw status
iptables -L
```

## ⚠️ ВАЖНЫЕ НАПОМИНАНИЯ

### 1. Безопасность
- ✅ Все пароли сгенерированы автоматически
- ✅ Файлы с паролями удалятся через 24 часа
- ⚠️ **ОБЯЗАТЕЛЬНО**: Измените пароли после первого входа
- ⚠️ **ОБЯЗАТЕЛЬНО**: Добавьте SSH ключи для пользователей

### 2. Мониторинг
- ✅ Все сервисы мониторинга настроены
- ✅ Пользователи созданы согласно политике безопасности
- ✅ Логины используют нестандартные имена

### 3. Резервное копирование
- Рекомендуется настроить автоматическое резервное копирование
- Сохраните пароли в безопасном месте
- Документируйте конфигурацию

## 🎯 КРИТЕРИИ УСПЕШНОЙ УСТАНОВКИ

Установка считается успешной, если:

1. ✅ Все сервисы запущены и доступны
2. ✅ Пользователи созданы согласно политике безопасности
3. ✅ SSH настроен правильно (root по паролю, пользователи по ключам)
4. ✅ Проверка безопасности показывает балл 80+/100
5. ✅ Все пароли соответствуют политике (12-24 символа)
6. ✅ Логины используют префикс "Traffic"

## 📞 ПОДДЕРЖКА

При возникновении проблем:

1. Проверьте логи: `journalctl -u [service-name] -f`
2. Запустите проверку безопасности: `sudo bash check_security.sh`
3. Проверьте документацию в файлах `.md`
4. Убедитесь, что все файлы загружены корректно

---

**Статус проекта:** Готов к продуктивной среде ✅  
**Последнее обновление:** $(date)  
**Версия:** Полное соответствие политике безопасности
