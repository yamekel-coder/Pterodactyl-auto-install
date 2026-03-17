#!/bin/bash

# === ЦВЕТА ===
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

# === ЛОГИ ===
exec > >(tee -i install.log)
exec 2>&1

clear
echo -e "${GREEN}"
echo "======================================"
echo "   YourStudio Pterodactyl Installer"
echo "======================================"
echo -e "${RESET}"

# === ПРОВЕРКИ ===
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Запусти от root!${RESET}"
   exit 1
fi

OS=$(lsb_release -rs)
if [[ "$OS" != "24.04" ]]; then
    echo -e "${YELLOW}Рекомендуется Ubuntu 24.04${RESET}"
fi

# === МЕНЮ ===
echo "Выбери действие:"
echo "1) Установить Panel"
echo "2) Установить Wings"
echo "3) Установить всё"
read -p "Введите цифру: " OPTION

# === ВВОД ДАННЫХ ===
read -p "Домен панели: " PANEL_DOMAIN
read -p "Email: " EMAIL
read -p "Username: " USERNAME
read -p "Имя: " FIRST_NAME
read -p "Фамилия: " LAST_NAME
read -s -p "Пароль: " PASSWORD; echo
read -s -p "Пароль БД: " DB_PASS; echo

# === ФУНКЦИЯ УСТАНОВКИ PANEL ===
install_panel() {
    echo -e "${GREEN}Установка Panel...${RESET}"

    apt update && apt upgrade -y

    apt install -y software-properties-common curl apt-transport-https ca-certificates gnupg lsb-release

    add-apt-repository ppa:ondrej/php -y
    apt update

    apt install -y nginx mysql-server redis-server \
    php8.3 php8.3-cli php8.3-gd php8.3-mysql php8.3-mbstring php8.3-tokenizer php8.3-bcmath php8.3-xml php8.3-fpm php8.3-curl php8.3-zip unzip git

    # MYSQL
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DB_PASS}';"
    mysql -u root -p${DB_PASS} -e "CREATE DATABASE panel;"
    mysql -u root -p${DB_PASS} -e "CREATE USER 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';"
    mysql -u root -p${DB_PASS} -e "GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1';"
    mysql -u root -p${DB_PASS} -e "FLUSH PRIVILEGES;"

    # PANEL
    mkdir -p /var/www/pterodactyl
    cd /var/www/pterodactyl

    curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz

    chmod -R 755 storage/* bootstrap/cache/

    curl -sS https://getcomposer.org/installer | php
    mv composer.phar /usr/local/bin/composer

    cp .env.example .env
    composer install --no-dev --optimize-autoloader

    php artisan key:generate --force

    php artisan p:environment:setup <<EOF
${EMAIL}
https://${PANEL_DOMAIN}
UTC
redis
yes
EOF

    php artisan p:environment:database <<EOF
127.0.0.1
3306
panel
pterodactyl
${DB_PASS}
EOF

    php artisan migrate --seed --force

    php artisan p:user:make <<EOF
yes
${EMAIL}
${USERNAME}
${FIRST_NAME}
${LAST_NAME}
${PASSWORD}
EOF

    chown -R www-data:www-data /var/www/pterodactyl/*

    # NGINX
    cat <<EOL > /etc/nginx/sites-available/pterodactyl
server {
    listen 80;
    server_name ${PANEL_DOMAIN};

    root /var/www/pterodactyl/public;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
    }
}
EOL

    ln -s /etc/nginx/sites-available/pterodactyl /etc/nginx/sites-enabled/
systemctl restart nginx

    # SSL
    apt install -y certbot python3-certbot-nginx
    certbot --nginx -d ${PANEL_DOMAIN} --non-interactive --agree-tos -m ${EMAIL}

    echo -e "${GREEN}Panel установлен!${RESET}"
}

# === WINGS ===
install_wings() {
    echo -e "${GREEN}Установка Wings...${RESET}"

    apt install -y docker.io curl

    systemctl enable docker
    systemctl start docker

    mkdir -p /etc/pterodactyl
    cd /etc/pterodactyl

    curl -L -o wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
    chmod +x wings

    echo -e "${YELLOW}Скопируй конфиг Wings из панели!${RESET}"
}

# === ВЫБОР ===
case $OPTION in
    1) install_panel ;;
    2) install_wings ;;
    3) install_panel; install_wings ;;
    *) echo -e "${RED}Неверный выбор${RESET}" ;;
esac

echo ""
echo -e "${GREEN}УСТАНОВКА ЗАВЕРШЕНА${RESET}"
echo "Логи: install.log"