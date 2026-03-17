# 🎮 Pterodactyl Auto-Install Script

> **Автоматическая установка Pterodactyl Panel & Wings** — всё в одном скрипте!

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ubuntu 24.04](https://img.shields.io/badge/Ubuntu-24.04-orange)](https://ubuntu.com/)
[![Bash](https://img.shields.io/badge/Bash-5.1+-green)](https://www.gnu.org/software/bash/)

---

## 📋 Описание

Этот скрипт полностью автоматизирует установку **Pterodactyl** — мощной панели управления игровыми серверами. Просто запустите скрипт и следуйте инструкциям!

### ✨ Возможности

✅ Автоматическая установка **Panel** и **Wings**  
✅ Настройка **Nginx** с поддержкой PHP 8.3  
✅ Конфигурация **MySQL** и **Redis**  
✅ Автоматическое получение **SSL сертификата** (Let's Encrypt)  
✅ Интерактивное меню выбора  
✅ Полное логирование процесса установки  

---

## 🚀 Быстрый Старт

### Требования

- **ОС**: Ubuntu 24.04 (рекомендуется)
- **Доступ**: Root или sudo права
- **Процессор**: 2+ ядра
- **Оперативная память**: 2+ GB
- **Место на диске**: 10+ GB

### Установка

1. **Скачайте скрипт**:
```bash
git clone https://github.com/yamekel-coder/Pterodactyl-auto-install.git
cd Pterodactyl-auto-install
```

2. **Сделайте скрипт исполняемым**:
```bash
chmod +x install.sh
```

3. **Запустите установку от root**:
```bash
sudo ./install.sh
```

4. **Следуйте инструкциям** и вводите запрашиваемые данные:
   - Домен панели
   - Email (для SSL сертификата)
   - Имя пользователя, имя, фамилия
   - Пароли

---

## 🎯 Варианты Установки

При запуске скрипта вы можете выбрать:

```
1) Установить Panel     → только веб-панель
2) Установить Wings     → только демон контейнеров  
3) Установить всё       → полная установка (рекомендуется)
```

---

## 📦 Что Устанавливается

### Для Panel:
- **Nginx** — веб-сервер
- **PHP 8.3** — язык программирования
- **MySQL** — база данных
- **Redis** — кеш
- **Composer** — менеджер пакетов PHP
- **Certbot** — автоматизация SSL сертификатов

### Для Wings:
- **Docker** — контейнеризация
- **Wings** — демон Pterodactyl

---

## ⚙️ Конфигурация

Все параметры можно настроить интерактивно во время установки:

```
Домен панели: panel.example.com
Email: admin@example.com
Username: admin
Имя: Иван
Фамилия: Иванов
Пароль: ****
Пароль БД: ****
```

---

## 📝 Логирование

Весь процесс установки записывается в файл install.log:

```bash
cat install.log
```

Это поможет вам отследить ошибки, если что-то пойдёт не так.

---

## 🔧 После Установки

1. **Откройте панель** в браузере:
   ```
   https://ваш-домен.com
   ```

2. **Войдите** с учётными данными, которые вы ввели

3. **Настройте Wings** (если вы его установили):
   - Скопируйте конфиг из панели
   - Поместите его в /etc/pterodactyl/config.yml

4. **Перезагрузите Wings**:
   ```bash
   systemctl restart wings
   ```

---

## ⚠️ Важно

- ⚠️ Используйте **strong пароли** для базы данных
- ⚠️ Установите **правильный домен** — SSL зависит от этог��
- ⚠️ Используйте **Ubuntu 24.04** для лучшей совместимости
- ⚠️ Скрипт требует **подключение к интернету**
- ⚠️ **Резервируйте данные** перед установкой

---

## 🆘 Troubleshooting

### Ошибка: "Запусти от root!"
```bash
sudo ./install.sh
```

### Ошибка: "502 Bad Gateway"
Проверьте PHP-FPM:
```bash
sudo systemctl status php8.3-fpm
```

### Ошибка: "Не могу получить SSL сертификат"
Убедитесь, что домен указан правильно и DNS настроен корректно.

### Более подробная информация
📖 [Официальная документация Pterodactyl](https://pterodactyl.io/panel/getting_started.html)

---

## 🤝 Внесение Вклада

Нашли баг? Хотите улучшить скрипт? 

1. Форкните репозиторий
2. Создайте ветку (git checkout -b feature/amazing-feature)
3. Коммитьте изменения (git commit -m 'Add amazing feature')
4. Пушьте в ветку (git push origin feature/amazing-feature)
5. Откройте Pull Request

---

## 📄 Лицензия

Проект лицензирован под **MIT License** — см. файл LICENSE для деталей.

---

## 💬 Поддержка

- 📧 Email: yamekel-coder@example.com
- 🐛 Issues: [GitHub Issues](https://github.com/yamekel-coder/Pterodactyl-auto-install/issues)
- 💬 Discussions: [GitHub Discussions](https://github.com/yamekel-coder/Pterodactyl-auto-install/discussions)

---

## 🙏 Спасибо

Спасибо за использование нашего скрипта! Если он вам помог, поставьте ⭐ звёздочку!

---

Сделано с ❤️ для сообщества Pterodactyl

[⬆ К началу](#pterodactyl-auto-install-script)