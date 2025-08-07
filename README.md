# 🚀 Traffic Connect Fast Setup

Модульная система быстрой установки и настройки Traffic Control сервера.

## 🚨 ВАЖНО: Если видите ошибки установки

Если вы видите ошибки типа:
- `Username or Group allready exists`
- `install_monitoring_system: command not found`
- `setup_web_templates: command not found`

**Выполните на сервере:**
```bash
cd ~/tc_fast_setup
chmod +x force_update.sh
./force_update.sh
./install.sh
```

## 📁 Структура проекта

```
📦 tc_fast_setup
├── 📁 core/                          # 🧠 Ядро системы
│   ├── 📁 installers/                # 🚀 Установщики
│   │   └── 📄 main_install.sh        # Главный установщик
│   ├── 📁 configs/                   # ⚙️ Конфигурации
│   │   └── 📄 configuration.sh       # Основная конфигурация
│   └── 📁 utils/                     # 🛠️ Утилиты
│       └── 📄 common.sh              # Общие функции
├── 📁 web/                           # 🌐 Веб-компоненты
│   ├── 📁 templates/                 # 📝 Шаблоны конфигурации
│   │   ├── 📄 templates_install.sh   # Установка шаблонов
│   │   ├── 📄 tc-custom.tpl          # Пользовательский шаблон
│   │   ├── 📄 tc-nginx-apache.stpl   # Nginx+Apache (стандарт)
│   │   ├── 📄 tc-nginx-apache.tpl    # Nginx+Apache (основной)
│   │   ├── 📄 tc-nginx-only.stpl     # Только Nginx (стандарт)
│   │   ├── 📄 tc-nginx-only.tpl      # Только Nginx (основной)
│   │   ├── 📄 tc-nginx-only-mu.stpl  # Nginx мульти-юзер (стандарт)
│   │   └── 📄 tc-nginx-only-mu.tpl   # Nginx мульти-юзер (основной)
│   └── 📁 configs/                   # 🔧 Конфигурации веб
│       └── 📄 config.example.sh      # Пример конфигурации
├── 📁 system/                        # 🖥️ Системные компоненты
│   ├── 📁 security/                  # 🛡️ Безопасность
│   │   ├── 📄 security_install.sh    # Установка безопасности
│   │   ├── 📄 security_policy.sh     # Политика безопасности
│   │   └── 📄 security_examples.sh   # Примеры безопасности
│   ├── 📁 monitoring/                # 📊 Мониторинг
│   │   └── 📄 monitoring_install.sh  # Установка мониторинга
│   └── 📁 admin/                     # 👨‍💼 Администрирование
│       └── 📄 admin_install.sh       # Установка админ-панели
├── 📁 docs/                          # 📚 Документация
│   └── 📁 examples/                  # 💡 Примеры
│       └── 📄 test_security.sh       # Тест безопасности
├── 📄 install.sh                     # 🚀 Точка входа
├── 📄 force_update.sh                # 🔄 Принудительное обновление
├── 📄 show_credentials.sh            # 🔐 Данные для входа
└── 📄 QUICK_FIX.md                   # 🚨 Быстрое исправление
```

## 🚀 Быстрый старт

### Первая установка
```bash
git clone https://github.com/Traffic-Connect/tc_fast_setup.git
cd tc_fast_setup
chmod +x install.sh
./install.sh
```

### Если есть проблемы с установкой
```bash
cd ~/tc_fast_setup
chmod +x force_update.sh
./force_update.sh
./install.sh
```

### Тестирование безопасности
```bash
./docs/examples/test_security.sh
```

### Просмотр данных для входа
```bash
./show_credentials.sh
```

### Настройка конфигурации
```bash
./core/configs/configuration.sh
```

## 🎯 Основные компоненты

### 🧠 Ядро системы (`core/`)
- **installers/** - Установщики системы
- **configs/** - Основные конфигурации
- **utils/** - Общие утилиты и функции

### 🌐 Веб-компоненты (`web/`)
- **templates/** - Шаблоны конфигурации веб-серверов
- **configs/** - Конфигурации веб-сервисов

### 🖥️ Системные компоненты (`system/`)
- **security/** - Модули безопасности
- **monitoring/** - Система мониторинга
- **admin/** - Административная панель

### 📚 Документация (`docs/`)
- **examples/** - Примеры использования

## 📊 Статистика

- **Папок:** 10
- **Файлов:** 22
- **Скриптов:** 12
- **Шаблонов:** 7
- **Тестов:** 1

## 🔄 Логика организации

1. **Разделение по функциональности** - каждый тип компонентов в своей папке
2. **Модульность** - независимые модули в отдельных папках
3. **Безопасность** - все файлы безопасности в system/security/
4. **Веб-сервисы** - все веб-компоненты в web/
5. **Ядро системы** - основные компоненты в core/

## 📝 Лицензия

Проект распространяется под лицензией MIT.

## 🤝 Поддержка

Для получения поддержки обращайтесь к команде разработки Traffic Connect.
