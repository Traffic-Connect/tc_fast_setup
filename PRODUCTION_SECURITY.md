# 🛡️ ИНСТРУКЦИИ ПО БЕЗОПАСНОСТИ ДЛЯ ПРОДУКТИВНОЙ СРЕДЫ

## ⚠️ ВАЖНЫЕ МЕРЫ БЕЗОПАСНОСТИ

### 1. Пароли и аутентификация (согласно политике безопасности)
- ✅ Все пароли генерируются автоматически с высокой сложностью
- ✅ Минимальная длина пароля: 12 символов (рекомендуется: 18 символов)
- ✅ Максимальная длина пароля: 24 символа
- ✅ Обязательные символы: заглавные, строчные, цифры, специальные
- ✅ Запрещены общие пароли и последовательности
- ⚠️ **ОБЯЗАТЕЛЬНО**: Измените пароли после установки!

### 2. Сетевая безопасность
- ✅ SSH защищен от брутфорс атак (fail2ban)
- ✅ Административные порты доступны только с localhost
- ✅ HTTP/HTTPS порты открыты для веб-доступа
- ⚠️ **РЕКОМЕНДУЕТСЯ**: Настройте VPN для удаленного доступа

### 3. Файрвол (iptables)
- ✅ Базовые правила безопасности настроены
- ✅ Защита от SYN flood атак
- ✅ Ограничение подключений к SSH
- ⚠️ **ПРОВЕРЬТЕ**: Настройте правила под ваши IP адреса

### 4. Fail2ban
- ✅ SSH защита (3 попытки, бан на 1 час)
- ✅ Nginx HTTP аутентификация (3 попытки)
- ✅ Защита от ботов (2 попытки, бан на 2 часа)
- ✅ Rate limiting (3 попытки, бан на 1 час)

### 5. Файловая система
- ✅ Учетные данные сохраняются в защищенной директории
- ✅ Автоматическое удаление через 24 часа
- ✅ Безопасные права доступа (600 для файлов, 700 для директорий)

## 🔧 ДОПОЛНИТЕЛЬНЫЕ НАСТРОЙКИ

### SSH конфигурация (согласно политике безопасности)
```bash
# Настройка согласно политике безопасности TrafficConnect
# Root доступ по паролю, пользователи по ключам

# Проверить текущую конфигурацию
grep -E "(PermitRootLogin|PasswordAuthentication|PubkeyAuthentication)" /etc/ssh/sshd_config

# Root доступ должен быть включен (согласно политике)
# PermitRootLogin yes

# Аутентификация по паролю включена для root
# PasswordAuthentication yes

# Аутентификация по ключам включена для пользователей
# PubkeyAuthentication yes

# Группа ssh-users настроена для пользователей
# Match Group ssh-users
#     PasswordAuthentication no
#     PubkeyAuthentication yes

# Изменить порт SSH (опционально)
sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config

# Перезапустить SSH
systemctl restart sshd
```

### SSL/TLS сертификаты
```bash
# Установка Certbot
apt install certbot python3-certbot-nginx

# Получение сертификата
certbot --nginx -d your-domain.com

# Автоматическое обновление
echo "0 12 * * * /usr/bin/certbot renew --quiet" | crontab -
```

### Резервное копирование
```bash
# Создание скрипта резервного копирования
cat > /root/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/var/backup/traffic_connect"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

# Резервное копирование конфигураций
tar -czf "$BACKUP_DIR/config_$DATE.tar.gz" \
    /etc/nginx \
    /etc/fail2ban \
    /etc/grafana \
    /etc/prometheus \
    /etc/loki

# Резервное копирование данных
tar -czf "$BACKUP_DIR/data_$DATE.tar.gz" \
    /var/lib/grafana \
    /var/lib/prometheus \
    /var/lib/loki

# Удаление старых резервных копий (старше 30 дней)
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +30 -delete
EOF

chmod +x /root/backup.sh

# Добавление в cron (ежедневно в 2:00)
echo "0 2 * * * /root/backup.sh" | crontab -
```

## 📊 МОНИТОРИНГ БЕЗОПАСНОСТИ

### Проверка логов
```bash
# SSH попытки входа
grep "Failed password" /var/log/auth.log

# Fail2ban статус
fail2ban-client status

# Nginx ошибки
tail -f /var/log/nginx/error.log

# Системные логи
journalctl -f
```

### Автоматические проверки
```bash
# Создание скрипта проверки безопасности
cat > /root/security_check.sh << 'EOF'
#!/bin/bash
echo "=== ПРОВЕРКА БЕЗОПАСНОСТИ $(date) ==="

# Проверка SSH
echo "SSH статус:"
systemctl status ssh | grep Active

# Проверка fail2ban
echo "Fail2ban статус:"
fail2ban-client status

# Проверка файрвола
echo "UFW статус:"
ufw status

# Проверка обновлений
echo "Последнее обновление:"
stat -c %y /var/lib/apt/periodic/update-success-stamp 2>/dev/null || echo "Не найдено"

# Проверка открытых портов
echo "Открытые порты:"
netstat -tlnp | grep LISTEN
EOF

chmod +x /root/security_check.sh
```

## 🚨 АВАРИЙНЫЕ ПРОЦЕДУРЫ

### Блокировка подозрительной активности
```bash
# Блокировка IP адреса
iptables -A INPUT -s SUSPICIOUS_IP -j DROP

# Временная блокировка SSH
systemctl stop ssh

# Проверка и очистка логов
fail2ban-client reload
```

### Восстановление после атаки
```bash
# Анализ логов
grep "Failed password" /var/log/auth.log | tail -100

# Проверка подозрительных процессов
ps aux | grep -E "(crypto|miner|bot)"

# Проверка сетевых соединений
netstat -tulpn | grep ESTABLISHED

# Проверка измененных файлов
find /etc -mtime -1 -ls
```

## 📋 ЧЕКЛИСТ БЕЗОПАСНОСТИ (согласно политике безопасности)

- [ ] Изменены пароли по умолчанию
- [ ] Настроены SSL сертификаты
- [ ] Root доступ по SSH настроен согласно политике (пароль)
- [ ] Пользователи настроены согласно политике (ключи SSH)
- [ ] Созданы пользователи мониторинга: TrafficMetrics, TrafficMonitor, TrafficLogger, TrafficNode, TrafficPush, TrafficFail2Ban
- [ ] Настроена группа ssh-users
- [ ] Настроен файрвол для ваших IP
- [ ] Настроено резервное копирование
- [ ] Настроен мониторинг безопасности
- [ ] Регулярные обновления системы
- [ ] Проверка логов безопасности
- [ ] Документированы процедуры восстановления
- [ ] Все пароли соответствуют политике безопасности (12-24 символа, сложность)

## 📞 КОНТАКТЫ ДЛЯ ЧРЕЗВЫЧАЙНЫХ СИТУАЦИЙ

При обнаружении подозрительной активности:
1. Немедленно отключите внешний доступ
2. Сделайте резервную копию логов
3. Проанализируйте активность
4. При необходимости переустановите систему
5. Восстановите данные из резервной копии

---

**ВАЖНО**: Этот документ должен храниться в безопасном месте и быть доступен только администраторам системы.
