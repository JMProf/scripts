#!/bin/bash

# --- COLORES PARA EL LOG ---
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}### 1. Preparando el sistema e instalando dependencias...${NC}"
apt update
apt install -y apache2 mariadb-server git certbot python3-certbot-apache \
php libapache2-mod-php php-iconv php-mysqli php-mbstring php-curl \
php-gd php-intl php-xml php-soap php-zip php-tokenizer php-ctype

# --- PREGUNTAS AL USUARIO ---
echo -e "${GREEN}### CONFIGURACIÓN DE MOODLE ###${NC}"
read -p "Introduce tu dominio: " DOMAIN
read -p "Introduce tu email (para avisos de seguridad de SSL): " EMAIL
DB_PASS="Moodle_$(openssl rand -hex 4)" # Genera una clave aleatoria para la BD

DB_NAME="moodle"
DB_USER="moodleuser"
MOODLE_DATA="/var/moodledata"
MOODLE_PATH="/var/www/html/moodle"

echo -e "${GREEN}### 2. Configurando Base de Datos...${NC}"
mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NAME DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -e "FLUSH PRIVILEGES;"

echo -e "${GREEN}### 3. Descargando Moodle (4.5 Stable)...${NC}"
if [ ! -d "$MOODLE_PATH" ]; then
    git clone -b MOODLE_405_STABLE https://github.com/moodle/moodle.git "$MOODLE_PATH"
fi

echo -e "${GREEN}### 4. Ajustando permisos y directorios...${NC}"
mkdir -p "$MOODLE_DATA"
chown -R www-data:www-data "$MOODLE_DATA"
chmod -R 770 "$MOODLE_DATA"
chown -R www-data:www-data "$MOODLE_PATH"
chmod -R 755 "$MOODLE_PATH"

echo -e "${GREEN}### 5. Configurando Apache para acceso directo por IP/Dominio...${NC}"
sed -i 's|DocumentRoot /var/www/html|DocumentRoot /var/www/html/moodle|' /etc/apache2/sites-available/000-default.conf

cat <<EOF > /etc/apache2/conf-available/moodle.conf
<Directory /var/www/html/moodle>
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>
EOF

a2enconf moodle
systemctl restart apache2

echo -e "${GREEN}### 6. Instalando Certificado SSL (Let's Encrypt)...${NC}"
# Esto intentará obtener el certificado y configurar la redirección HTTPS automáticamente
certbot --apache -d $DOMAIN --non-interactive --agree-tos -m $EMAIL --redirect

echo -e "${GREEN}### 7. Optimizando PHP para Moodle...${NC}"
sed -i 's/memory_limit = .*/memory_limit = 256M/' /etc/php/*/apache2/php.ini
sed -i 's/max_execution_time = .*/max_execution_time = 300/' /etc/php/*/apache2/php.ini
systemctl restart apache2

echo "---------------------------------------------------------"
echo -e "${GREEN} ¡INSTALACIÓN COMPLETADA!${NC}"
echo "---------------------------------------------------------"
echo " URL: https://$DOMAIN"
echo " Base de Datos: $DB_NAME"
echo " Usuario BD: $DB_USER"
echo " Password BD: $DB_PASS"
echo " Dir. Datos: $MOODLE_DATA"
echo "---------------------------------------------------------"
echo " IMPORTANTE: Cuando termines el asistente web, recuerda revisar"
echo " que en config.php la URL sea https://$DOMAIN"
echo "---------------------------------------------------------"
