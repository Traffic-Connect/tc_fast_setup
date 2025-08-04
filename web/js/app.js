// ============================================================================
// Traffic Connect Server Installation - GUI JavaScript
// ============================================================================

// Глобальные переменные
let currentStep = 1;
let installationInProgress = false;
let installationInterval = null;

// Инициализация приложения
document.addEventListener('DOMContentLoaded', function() {
    initializeApp();
});

function initializeApp() {
    // Загрузка информации о системе
    loadSystemInfo();
    
    // Загрузка статуса компонентов
    loadComponentStatus();
    
    // Загрузка настроек
    loadSettings();
    
    // Настройка обработчиков событий
    setupEventListeners();
    
    // Периодическое обновление статуса
    setInterval(updateServiceStatus, 30000); // Каждые 30 секунд
}

// Настройка обработчиков событий
function setupEventListeners() {
    // Навигация по вкладкам
    document.querySelectorAll('.nav-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            const tabName = this.getAttribute('data-tab');
            switchTab(tabName);
        });
    });
    
    // Обработчики для мастера установки
    document.getElementById('log-file-selector').addEventListener('change', function() {
        loadLogFile(this.value);
    });
}

// Переключение вкладок
function switchTab(tabName) {
    // Убираем активный класс со всех кнопок и контента
    document.querySelectorAll('.nav-btn').forEach(btn => btn.classList.remove('active'));
    document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));
    
    // Добавляем активный класс к выбранной вкладке
    document.querySelector(`[data-tab="${tabName}"]`).classList.add('active');
    document.getElementById(tabName).classList.add('active');
    
    // Специальные действия для вкладок
    if (tabName === 'monitoring') {
        updateServiceStatus();
    } else if (tabName === 'logs') {
        loadLogFile('install');
    }
}

// Загрузка информации о системе
async function loadSystemInfo() {
    try {
        const response = await fetch('/api/system-info');
        const data = await response.json();
        
        document.getElementById('os-info').textContent = data.os || 'Неизвестно';
        document.getElementById('arch-info').textContent = data.arch || 'Неизвестно';
        document.getElementById('disk-info').textContent = data.disk || 'Неизвестно';
        document.getElementById('internet-info').textContent = data.internet ? 'Доступен' : 'Недоступен';
    } catch (error) {
        console.error('Ошибка загрузки информации о системе:', error);
        // Заполняем заглушками для демонстрации
        document.getElementById('os-info').textContent = 'Ubuntu 22.04';
        document.getElementById('arch-info').textContent = 'x86_64';
        document.getElementById('disk-info').textContent = '15.2 GB свободно';
        document.getElementById('internet-info').textContent = 'Доступен';
    }
}

// Загрузка статуса компонентов
async function loadComponentStatus() {
    try {
        const response = await fetch('/api/component-status');
        const data = await response.json();
        
        updateComponentStatus(data);
    } catch (error) {
        console.error('Ошибка загрузки статуса компонентов:', error);
        // Заполняем заглушками для демонстрации
        const mockData = {
            hestia: 'not-installed',
            grafana: 'not-installed',
            prometheus: 'not-installed',
            loki: 'not-installed',
            fail2ban: 'not-installed'
        };
        updateComponentStatus(mockData);
    }
}

// Обновление статуса компонентов
function updateComponentStatus(data) {
    Object.keys(data).forEach(component => {
        const element = document.getElementById(`${component}-status`);
        if (element) {
            element.textContent = getStatusText(data[component]);
            element.className = `status ${data[component]}`;
        }
    });
}

// Получение текста статуса
function getStatusText(status) {
    const statusMap = {
        'installed': 'Установлен',
        'not-installed': 'Не установлен',
        'checking': 'Проверка...',
        'error': 'Ошибка'
    };
    return statusMap[status] || 'Неизвестно';
}

// Обновление статуса сервисов
async function updateServiceStatus() {
    try {
        const response = await fetch('/api/service-status');
        const data = await response.json();
        
        Object.keys(data).forEach(service => {
            const element = document.querySelector(`[data-service="${service}"]`);
            if (element) {
                element.textContent = getServiceStatusText(data[service]);
                element.className = `service-status-badge ${data[service]}`;
            }
        });
    } catch (error) {
        console.error('Ошибка обновления статуса сервисов:', error);
    }
}

// Получение текста статуса сервиса
function getServiceStatusText(status) {
    const statusMap = {
        'running': 'Работает',
        'stopped': 'Остановлен',
        'checking': 'Проверка...',
        'error': 'Ошибка'
    };
    return statusMap[status] || 'Неизвестно';
}

// Загрузка настроек
function loadSettings() {
    const settings = JSON.parse(localStorage.getItem('installer-settings') || '{}');
    
    document.getElementById('verify-checksums').checked = settings.verifyChecksums !== false;
    document.getElementById('ssl-verify').checked = settings.sslVerify !== false;
    document.getElementById('parallel-install').checked = settings.parallelInstall || false;
    document.getElementById('curl-timeout').value = settings.curlTimeout || 300;
    document.getElementById('curl-retries').value = settings.curlRetries || 3;
    document.getElementById('curl-retry-delay').value = settings.curlRetryDelay || 5;
}

// Сохранение настроек
function saveSettings() {
    const settings = {
        verifyChecksums: document.getElementById('verify-checksums').checked,
        sslVerify: document.getElementById('ssl-verify').checked,
        parallelInstall: document.getElementById('parallel-install').checked,
        curlTimeout: parseInt(document.getElementById('curl-timeout').value),
        curlRetries: parseInt(document.getElementById('curl-retries').value),
        curlRetryDelay: parseInt(document.getElementById('curl-retry-delay').value)
    };
    
    localStorage.setItem('installer-settings', JSON.stringify(settings));
    showNotification('Настройки сохранены', 'success');
}

// Сброс настроек
function resetSettings() {
    localStorage.removeItem('installer-settings');
    loadSettings();
    showNotification('Настройки сброшены к умолчанию', 'info');
}

// Мастер установки
function nextStep() {
    if (currentStep < 4) {
        currentStep++;
        updateWizardStep();
    }
}

function prevStep() {
    if (currentStep > 1) {
        currentStep--;
        updateWizardStep();
    }
}

function updateWizardStep() {
    // Скрываем все шаги
    document.querySelectorAll('.wizard-step').forEach(step => {
        step.classList.remove('active');
    });
    
    // Показываем текущий шаг
    document.querySelector(`[data-step="${currentStep}"]`).classList.add('active');
    
    // Обновляем содержимое шага 3 (подтверждение)
    if (currentStep === 3) {
        updateConfirmationStep();
    }
}

function updateConfirmationStep() {
    const selectedComponents = [];
    const installationParams = [];
    
    // Собираем выбранные компоненты
    if (document.getElementById('install-hestia').checked) selectedComponents.push('Hestia Control Panel');
    if (document.getElementById('install-grafana').checked) selectedComponents.push('Grafana');
    if (document.getElementById('install-prometheus').checked) selectedComponents.push('Prometheus');
    if (document.getElementById('install-loki').checked) selectedComponents.push('Loki');
    if (document.getElementById('install-fail2ban').checked) selectedComponents.push('Fail2ban');
    if (document.getElementById('install-tools').checked) selectedComponents.push('Дополнительные инструменты');
    
    // Собираем параметры установки
    installationParams.push(`Пользователь Hestia CP: ${document.getElementById('hestia-user').value}`);
    installationParams.push(`Email администратора: ${document.getElementById('admin-email').value}`);
    installationParams.push(`Режим установки: ${document.getElementById('install-mode').value}`);
    
    // Обновляем списки
    updateList('selected-components', selectedComponents);
    updateList('installation-params', installationParams);
}

function updateList(elementId, items) {
    const element = document.getElementById(elementId);
    element.innerHTML = '';
    items.forEach(item => {
        const li = document.createElement('li');
        li.textContent = item;
        element.appendChild(li);
    });
}

// Запуск установки
async function startInstallation() {
    if (installationInProgress) return;
    
    installationInProgress = true;
    currentStep = 4;
    updateWizardStep();
    
    // Собираем параметры установки
    const installationData = {
        components: {
            hestia: document.getElementById('install-hestia').checked,
            grafana: document.getElementById('install-grafana').checked,
            prometheus: document.getElementById('install-prometheus').checked,
            loki: document.getElementById('install-loki').checked,
            fail2ban: document.getElementById('install-fail2ban').checked,
            tools: document.getElementById('install-tools').checked
        },
        params: {
            hestiaUser: document.getElementById('hestia-user').value,
            adminEmail: document.getElementById('admin-email').value,
            installMode: document.getElementById('install-mode').value
        }
    };
    
    try {
        const response = await fetch('/api/start-installation', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(installationData)
        });
        
        if (response.ok) {
            startInstallationProgress();
        } else {
            throw new Error('Ошибка запуска установки');
        }
    } catch (error) {
        console.error('Ошибка запуска установки:', error);
        showNotification('Ошибка запуска установки', 'error');
        installationInProgress = false;
    }
}

function startInstallationProgress() {
    let progress = 0;
    const progressFill = document.getElementById('progress-fill');
    const progressText = document.getElementById('progress-text');
    const installationLog = document.getElementById('installation-log');
    
    installationInterval = setInterval(() => {
        progress += Math.random() * 10;
        if (progress > 100) progress = 100;
        
        progressFill.style.width = `${progress}%`;
        
        if (progress < 30) {
            progressText.textContent = 'Проверка системы...';
        } else if (progress < 60) {
            progressText.textContent = 'Установка компонентов...';
        } else if (progress < 90) {
            progressText.textContent = 'Настройка сервисов...';
        } else {
            progressText.textContent = 'Завершение установки...';
        }
        
        // Добавляем логи (демонстрация)
        const timestamp = new Date().toLocaleTimeString();
        installationLog.innerHTML += `[${timestamp}] ${progressText.textContent}\n`;
        installationLog.scrollTop = installationLog.scrollHeight;
        
        if (progress >= 100) {
            clearInterval(installationInterval);
            progressText.textContent = 'Установка завершена!';
            showNotification('Установка завершена успешно!', 'success');
            installationInProgress = false;
        }
    }, 1000);
}

function cancelInstallation() {
    if (installationInterval) {
        clearInterval(installationInterval);
    }
    
    installationInProgress = false;
    document.getElementById('progress-fill').style.width = '0%';
    document.getElementById('progress-text').textContent = 'Установка отменена';
    showNotification('Установка отменена', 'warning');
}

// Быстрые действия
function startFullInstallation() {
    switchTab('installation');
    // Автоматически выбираем все компоненты
    document.querySelectorAll('.component-selector input[type="checkbox"]').forEach(checkbox => {
        checkbox.checked = true;
    });
    nextStep();
    nextStep();
    startInstallation();
}

function startCustomInstallation() {
    switchTab('installation');
}

async function runTests() {
    showNotification('Запуск тестов...', 'info');
    
    try {
        const response = await fetch('/api/run-tests');
        const data = await response.json();
        
        if (data.success) {
            showNotification(`Тесты пройдены: ${data.passed}/${data.total}`, 'success');
        } else {
            showNotification(`Тесты провалены: ${data.failed}/${data.total}`, 'error');
        }
    } catch (error) {
        console.error('Ошибка запуска тестов:', error);
        showNotification('Ошибка запуска тестов', 'error');
    }
}

// Работа с логами
async function loadLogFile(logType) {
    const logContent = document.getElementById('log-content');
    logContent.innerHTML = '<pre>Загрузка лога...</pre>';
    
    try {
        const response = await fetch(`/api/logs/${logType}`);
        const data = await response.json();
        
        if (data.content) {
            logContent.innerHTML = `<pre>${data.content}</pre>`;
        } else {
            logContent.innerHTML = '<pre>Лог пуст или недоступен</pre>';
        }
    } catch (error) {
        console.error('Ошибка загрузки лога:', error);
        logContent.innerHTML = '<pre>Ошибка загрузки лога</pre>';
    }
}

function refreshLogs() {
    const logType = document.getElementById('log-file-selector').value;
    loadLogFile(logType);
}

// Уведомления
function showNotification(message, type = 'info') {
    const notifications = document.getElementById('notifications');
    const notification = document.createElement('div');
    notification.className = `notification ${type}`;
    notification.textContent = message;
    
    notifications.appendChild(notification);
    
    // Автоматическое удаление через 5 секунд
    setTimeout(() => {
        notification.remove();
    }, 5000);
}

// API заглушки для демонстрации
if (typeof fetch === 'undefined') {
    // Заглушка для fetch если не поддерживается
    window.fetch = function(url) {
        return new Promise((resolve) => {
            setTimeout(() => {
                resolve({
                    ok: true,
                    json: () => Promise.resolve({
                        os: 'Ubuntu 22.04',
                        arch: 'x86_64',
                        disk: '15.2 GB свободно',
                        internet: true
                    })
                });
            }, 100);
        });
    };
} 