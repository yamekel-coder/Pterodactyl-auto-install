#!/bin/bash

# Цветовые коды для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Функции для вывода
output() {
    echo -e "${CYAN}$1${NC}"
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

error() {
    echo -e "${RED}✗ $1${NC}"
}

header() {
    echo -e "${PURPLE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${PURPLE}════════════════════════════════════════════════════════════════${NC}"
}

# Версии
PANEL="latest"
WINGS="latest"

# Проверка прав root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Пожалуйста, запустите скрипт с правами root (sudo)"
        exit 1
    fi
}

# Определение ОС
detect_os() {
    if [ -r /etc/os-release ]; then
        . /etc/os-release
        OS="$ID"
        OS_VERSION="$VERSION_ID"
    else
        error "Не удалось определить операционную систему"
        exit 1
    fi

    success "Обнаружена ОС: $OS $OS_VERSION"
}

# Проверка архитектуры
check_architecture() {
    ARCH=$(uname -m)
    if [ "$ARCH" != "x86_64" ]; then
        error "Неподдерживаемая архитектура: $ARCH. Требуется x86_64"
        exit 1
    fi
    success "Архитектура: $ARCH"
}

# Проверка совместимости
check_compatibility() {
    case $OS in
        ubuntu)
            if [[ ! "$OS_VERSION" =~ ^(20\.04|22\.04|24\.04)$ ]]; then
                error "Поддерживаются только Ubuntu 20.04, 22.04, 24.04"
                exit 1
            fi
            ;;
        debian)
            if [[ ! "$OS_VERSION" =~ ^(10|11|12)$ ]]; then
                error "Поддерживаются только Debian 10, 11, 12"
                exit 1
            fi
            ;;
        fedora)
            if [ "$OS_VERSION" != "35" ]; then
                error "Поддерживается только Fedora 35"
                exit 1
            fi
            ;;
        centos|rhel|rocky|almalinux)
            MAJOR_VERSION=$(echo $OS_VERSION | cut -d. -f1)
            if [[ ! "$MAJOR_VERSION" =~ ^(7|8|9)$ ]]; then
                error "Поддерживаются только версии 7, 8, 9"
                exit 1
            fi
            ;;
        *)
            error "Неподдерживаемая ОС: $OS"
            exit 1
            ;;
    esac
    success "ОС совместима с Pterodactyl"
}

# Меню установки
show_menu() {
    header "COOKIEDEV PTERODACTYL INSTALLER v1.0"
    echo -e "${YELLOW}Выберите действие:${NC}"
    echo "1) 📦 Установить панель"
    echo "2) 🚀 Установить Wings"
    echo "3) 🔧 Установить панель + Wings"
    echo "4) 📋 Обновить панель"
    echo "5) 🔄 Обновить Wings"
    echo "6) ⚡ Обновить всё"
    echo "7) 🗄️ Установить phpMyAdmin"
    echo "8) 🔑 Сброс пароля root MariaDB"
    echo "9) 🔐 Сброс пароля базы данных"
    echo "0) ❌ Выход"
    echo ""
    read -p "Ваш выбор [0-9]: " choice
}

# Ввод домена и email
get_domain_info() {
    header "КОНФИГУРАЦИЯ ДОМЕНА"
    
    read -p "Введите email администратора: " email
    if [ -z "$email" ]; then
        error "Email не может быть пустым"
        get_domain_info
        return
    fi
    
    read -p "Введите домен (например: panel.example.com): " FQDN
    if [ -z "$FQDN" ]; then
        error "Домен не может быть пустым"
        get_domain_info
        return
    fi
    
    success "Домен: $FQDN"
    success "Email: $email"
}

# Настройка репозиториев
setup_repositories() {
    header "НАСТРОЙКА РЕПОЗИТОРИЕВ"
    
    case $OS in
        ubuntu|debian)
            apt-get update
            apt-get install -y curl wget gnupg2 ca-certificates lsb-release ubuntu-keyring
            curl -fsSL https://packages.sury.org/php/apt.gpg | apt-key add -
            echo "deb https://packages.sury.org/php/ \
                \
                $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list
            curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash
            apt-get update
            ;;
        centos|rhel|rocky|almalinux|fedora)
            dnf install -y epel-release dnf-utils
            dnf install -y https://rpms.remirepo.net/enterprise/remi-release-${MAJOR_VERSION}.rpm
            dnf config-manager --set-enabled remi
            dnf update -y
            ;;
    esac
    success "Репозитории настроены"
}

# Установка зависимостей
install_dependencies() {
    header "УСТАНОВКА ЗАВИСИМОСТЕЙ"
    
    case $OS in
        ubuntu|debian)
            apt-get install -y \
                php8.2 php8.2-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip} \
                nginx tar unzip git redis-server mariadb-server \
                composer certbot python3-certbot-nginx fail2ban ufw
            systemctl enable --now redis-server php8.2-fpm mariadb nginx
            ;; 
        centos|rhel|rocky|almalinux|fedora)
            dnf module install -y nginx:mainline/common
            dnf module install -y php:remi-8.2/common
            dnf install -y redis mariadb-server git unzip tar composer \
                certbot python3-certbot-nginx fail2ban firewalld
            systemctl enable --now redis php-fpm mariadb nginx
            ;;
    esac
    
    systemctl enable --now cron
    success "Зависимости установлены"
}

# Установка панели
install_panel() {
    header "УСТАНОВКА ПАНЕЛИ PTERODACTYL"
    
    # Генерация паролей
    DB_PASSWORD=$(openssl rand -base64 32)
    ADMIN_PASSWORD=$(openssl rand -base64 32)
    ROOT_PASSWORD=$(openssl rand -base64 32)
    
    # Настройка базы данных
    mysql -e "CREATE DATABASE IF NOT EXISTS panel;"
    mysql -e "CREATE USER IF NOT EXISTS 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '$DB_PASSWORD';"
    mysql -e "GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1';"
    mysql -e "CREATE USER IF NOT EXISTS 'admin'@'%' IDENTIFIED BY '$ADMIN_PASSWORD';"
    mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%';"
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$ROOT_PASSWORD';"
    mysql -e "DELETE FROM mysql.user WHERE User='';"
    mysql -e "DROP DATABASE IF EXISTS test;"
    mysql -e "FLUSH PRIVILEGES;"
    
    # Загрузка панели
    mkdir -p /var/www/pterodactyl
    cd /var/www/pterodactyl
    
    curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    tar -xzf panel.tar.gz
    chmod -R 755 storage/* bootstrap/cache/
    
    # Установка через composer
    cp .env.example .env
    composer install --no-dev --optimize-autoloader
    
    # Настройка окружения
    php artisan key:generate --force
    php artisan p:environment:setup \
        -n \
        --author="$email" \
        --url="https://$FQDN" \
        --timezone="Europe/Moscow" \
        --cache="redis" \
        --session="redis" \
        --queue="redis" \
        --redis-host="127.0.0.1" \
        --redis-port="6379"
    
    php artisan p:environment:database \
        --host="127.0.0.1" \
        --port="3306" \
        --database="panel" \
        --username="pterodactyl" \
        --password="$DB_PASSWORD"
    
    php artisan migrate --seed --force
    php artisan p:user:make --email="$email" --admin=1 --name="Admin" --password="$ADMIN_PASSWORD"
    
    # Настройка прав
    if [[ "$OS" =~ ^(ubuntu|debian)$ ]]; then
        chown -R www-data:www-data /var/www/pterodactyl
    else
        chown -R nginx:nginx /var/www/pterodactyl
    fi
    
    # Настройка планировщика
    (crontab -l 2>/dev/null; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1") | crontab -
    
    # Настройка воркера
    cat > /etc/systemd/system/pteroq.service << EOF
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
User=$([ "$OS" =~ ^(ubuntu|debian)$ ] && echo "www-data" || echo "nginx")
Group=$([ "$OS" =~ ^(ubuntu|debian)$ ] && echo "www-data" || echo "nginx")
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable --now pteroq.service
    
    success "Панель Pterodactyl установлена"
    
    # Сохранение паролей
    cat > /root/pterodactyl_credentials.txt << EOF
=== PTERODACTYL CREDENTIALS ===
Домен: https://$FQDN
Email администратора: $email
Пароль администратора: $ADMIN_PASSWORD

=== DATABASE CREDENTIALS ===
Root пароль: $ROOT_PASSWORD
Пользователь pterodactyl: $DB_PASSWORD
Пользователь admin: $ADMIN_PASSWORD
Хост: $(curl -s ifconfig.me)
Порт: 3306

=== WINGS ===
Конфигурация находится в /etc/pterodactyl
EOF
    
    success "Данные сохранены в /root/pterodactyl_credentials.txt"
}

# Настройка SSL
setup_ssl() {
    header "НАСТРОЙКА SSL СЕРТИФИКАТА"
    
    certbot --nginx --redirect --no-eff-email \
        --email "$email" --agree-tos -d "$FQDN" --non-interactive
    
    systemctl enable --now certbot.timer
    success "SSL сертификат установлен"
}

# Настройка Nginx
setup_nginx() {
    header "НАСТРОЙКА NGINX"
    
    if [[ "$OS" =~ ^(ubuntu|debian)$ ]]; then
        cat > /etc/nginx/sites-available/pterodactyl << EOF
server {
    listen 80;
    server_name $FQDN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $FQDN;
    
    root /var/www/pterodactyl/public;
    index index.php;
    
    ssl_certificate /etc/letsencrypt/live/$FQDN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$FQDN/privkey.pem;
    ssl_session_cache shared:SSL:10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    
    client_max_body_size 100m;
    
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    
    location ~ \.php\$ {
        fastcgi_split_path_info ^(.+\.php)(/.+\$);
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
    }
}
EOF
        ln -s /etc/nginx/sites-available/pterodactyl /etc/nginx/sites-enabled/
        rm -f /etc/nginx/sites-enabled/default
    else
        cat > /etc/nginx/conf.d/pterodactyl.conf << EOF
server {
    listen 80;
    server_name $FQDN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $FQDN;
    
    root /var/www/pterodactyl/public;
    index index.php;
    
    ssl_certificate /etc/letsencrypt/live/$FQDN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$FQDN/privkey.pem;
    ssl_session_cache shared:SSL:10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    
    client_max_body_size 100m;
    
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    
    location ~ \.php\$ {
        fastcgi_split_path_info ^(.+\.php)(/.+\$);
        fastcgi_pass unix:/var/run/php-fpm/pterodactyl.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
    }
}
EOF
    fi
    
    systemctl restart nginx
    success "Nginx настроен"
}

# Установка Wings
install_wings() {
    header "УСТАНОВКА WINGS"
    
    # Установка Docker
    curl -sSL https://get.docker.com/ | CHANNEL=stable bash
    systemctl enable --now docker
    
    # Установка Wings
    mkdir -p /etc/pterodactyl
    curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
    chmod u+x /usr/local/bin/wings
    
    # Создание сервиса
    cat > /etc/systemd/system/wings.service << EOF
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
ExecStart=/usr/local/bin/wings
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable wings
    
    success "Wings установлен"
    warn "Не забудьте настроить узел в панели и выполнить: systemctl start wings"
}

# Настройка брандмауэра
setup_firewall() {
    header "НАСТРОЙКА БРАНДМАУЭРА"
    
    case $OS in
        ubuntu|debian)
            ufw --force enable
            ufw default deny incoming
            ufw default allow outgoing
            ufw allow 22/tcp comment 'SSH'
            ufw allow 80/tcp comment 'HTTP'
            ufw allow 443/tcp comment 'HTTPS'
            ufw allow 8080/tcp comment 'Wings'
            ufw allow 2022/tcp comment 'Wings SFTP'
            ufw allow 3306/tcp comment 'MySQL'
            ;; 
        centos|rhel|rocky|almalinux|fedora)
            systemctl enable --now firewalld
            firewall-cmd --permanent --add-service=ssh
            firewall-cmd --permanent --add-service=http
            firewall-cmd --permanent --add-service=https
            firewall-cmd --permanent --add-port=8080/tcp
            firewall-cmd --permanent --add-port=2022/tcp
            firewall-cmd --permanent --add-port=3306/tcp
            firewall-cmd --permanent --zone=trusted --change-interface=docker0
            firewall-cmd --zone=trusted --add-masquerade --permanent
            firewall-cmd --reload
            ;;
    esac
    
    success "Брандмауэр настроен"
}

# Установка phpMyAdmin
install_phpmyadmin() {
    header "УСТАНОВКА PHPMYADMIN"
    
    cd /var/www/pterodactyl/public
    
    if [[ "$OS" =~ ^(ubuntu|debian)$ ]]; then
        apt-get install -y phpmyadmin
        ln -s /usr/share/phpmyadmin phpmyadmin
        chown -R www-data:www-data phpmyadmin
    else
        dnf install -y phpmyadmin
        ln -s /usr/share/phpMyAdmin phpmyadmin
        chown -R nginx:nginx phpmyadmin
        chcon -R -t httpd_sys_content_t /usr/share/phpMyAdmin
    fi
    
    success "phpMyAdmin доступен по адресу: https://$FQDN/phpmyadmin"
}

# Сброс пароля базы данных
reset_db_password() {
    header "СБРОС ПАРОЛЯ БАЗЫ ДАННЫХ"
    
    SERVER_IP=$(curl -s ifconfig.me)
    NEW_PASSWORD=$(openssl rand -base64 32)
    
    mysql -e "ALTER USER 'admin'@'%' IDENTIFIED BY '$NEW_PASSWORD';"
    mysql -e "FLUSH PRIVILEGES;"
    
    success "Новый пароль для пользователя 'admin': $NEW_PASSWORD"
    success "Хост: $SERVER_IP"
    success "Порт: 3306"
}

# Функция обновления Wings
upgrade_wings() {
    header "ОБНОВЛЕНИЕ WINGS"
    curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
    chmod u+x /usr/local/bin/wings
    systemctl restart wings
    success "Wings обновлен до последней версии"
}

# Главная функция
main() {
    clear
    header "PTERODACTYL AUTO INSTALLER"
    echo -e "${GREEN}Версия: 2.0${NC}"
    echo -e "${YELLOW}Автор: The_stas${NC}"
    echo ""
    
    check_root
    detect_os
    check_architecture
    check_compatibility
    
    show_menu
    
    case $choice in
        1)
            get_domain_info
            setup_repositories
            install_dependencies
            install_panel
            setup_ssl
            setup_nginx
            setup_firewall
            success "Установка панели завершена!"
            cat /root/pterodactyl_credentials.txt
            ;; 
        2)
            get_domain_info
            install_wings
            setup_ssl
            setup_firewall
            success "Установка Wings завершена!"
            ;; 
        3)
            get_domain_info
            setup_repositories
            install_dependencies
            install_panel
            setup_ssl
            setup_nginx
            install_wings
            setup_firewall
            success "Установка панели и Wings завершена!"
            cat /root/pterodactyl_credentials.txt
            ;; 
        4)
            cd /var/www/pterodactyl && php artisan p:upgrade
            success "Панель обновлена!"
            ;;
        5)
            upgrade_wings
            ;;
        6)
            cd /var/www/pterodactyl && php artisan p:upgrade
            upgrade_wings
            success "Все компоненты обновлены!"
            ;; 
        7)
            install_phpmyadmin
            ;; 
        8)
            warn "Запуск скрипта сброса пароля root MariaDB..."
            curl -sSL https://raw.githubusercontent.com/stashenko/mariadb.sh/master/mariadb.sh | bash
            ;; 
        9)
            reset_db_password
            ;; 
        0)
            exit 0
            ;; 
        *)
            error "Неверный выбор!"
            exit 1
            ;;
    esac
}

# Запуск
main "$@"
