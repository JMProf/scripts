#!/bin/bash

# --- COLORES ---
GREEN='\033[0;32m'
NC='\033[0m'

# Comprobar si es root
if [ "$EUID" -ne 0 ]; then 
  echo "Por favor, ejecuta el script como root (sudo)."
  exit
fi

echo -e "${GREEN}### 1. INSTALANDO PAQUETES Y PHP...${NC}"

apt update
apt install -y apache2 mariadb-server git certbot python3-certbot-apache \
php libapache2-mod-php php-iconv php-mysqli php-mbstring php-curl \
php-gd php-intl php-xml php-soap php-zip php-tokenizer php-ctype

# --- PREGUNTAS ---
echo -e "${GREEN}### CONFIGURACIÓN DE RED ###${NC}"

read -p "¿Vas a utilizar un dominio para esta instalación? (s/n): " USAR_DOMINIO

if [ "$USAR_DOMINIO" = "s" ]; then
    read -p "Introduce tu dominio (ej: aula.miweb.com): " DOMAIN
    read -p "¿Quieres configurar SSL con Certbot? (s/n): " QUERER_SSL
    if [ "$QUERER_SSL" = "s" ]; then
        read -p "Introduce tu email para el SSL: " EMAIL
        FINAL_URL="https://$DOMAIN"
    else
        FINAL_URL="http://$DOMAIN"
    fi
else
    echo "Se han detectado las siguientes direcciones IP:"
    mapfile -t IPS < <(hostname -I | tr ' ' '\n' | grep -v '^$')
    
    for i in "${!IPS[@]}"; do
        echo "$((i+1))) ${IPS[$i]}"
    done

    while true; do
        read -p "Selecciona la opción de IP que quieres usar: " OPCION_IP
        if [[ "$OPCION_IP" -gt 0 && "$OPCION_IP" -le "${#IPS[@]}" ]]; then
            IP_ELEGIDA="${IPS[$((OPCION_IP-1))]}"
            break
        else
            echo "Opción no válida. Inténtalo de nuevo."
        fi
    done
    
    FINAL_URL="http://$IP_ELEGIDA"
    QUERER_SSL="n"
fi

# Pregunta de pre-configuración en español (s/n)
echo -e "\n${GREEN}### PREFERENCIAS DE INSTALACIÓN ###${NC}"
read -p "¿Quieres que el script cree el archivo de configuración automáticamente? (s/n): " AUTO_CONFIG

# --- VARIABLES DE ENTORNO ---
DB_PASS="Moodle$(openssl rand -hex 4)"
DB_NAME="moodle"
DB_USER="moodleuser"
MOODLE_DATA="/var/moodledata"
MOODLE_PATH="/var/www/html/moodle"
PHP_VER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')

echo -e "${GREEN}### 2. CONFIGURANDO BASE DE DATOS...${NC}"

mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NAME DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -e "FLUSH PRIVILEGES;"

echo -e "${GREEN}### 3. PREPARANDO DIRECTORIO DE DATOS Y PERMISOS...${NC}"

mkdir -p "$MOODLE_DATA"
chown -R www-data:www-data "$MOODLE_DATA"
chmod -R 770 "$MOODLE_DATA"

mkdir -p "$MOODLE_PATH"
chown -R www-data:www-data "$MOODLE_PATH"

echo -e "${GREEN}### 4. DESCARGANDO MOODLE EN DIRECTORIO PREPARADO...${NC}"

rm -rf "${MOODLE_PATH:?}"/*
git clone -b MOODLE_405_STABLE https://github.com/moodle/moodle.git "$MOODLE_PATH"

# --- LÓGICA DE PRE-CONFIGURACIÓN ---
if [ "$AUTO_CONFIG" = "s" ]; then
    echo -e "${GREEN}### 5. GENERANDO CONFIG.PHP AUTOMÁTICO...${NC}"
    cat <<EOF > "$MOODLE_PATH/config.php"
<?php
unset(\$CFG);
global \$CFG;
\$CFG = new stdClass();

\$CFG->dbtype    = 'mariadb';
\$CFG->dblibrary = 'native';
\$CFG->dbhost    = 'localhost';
\$CFG->dbname    = '$DB_NAME';
\$CFG->dbuser    = '$DB_USER';
\$CFG->dbpass    = '$DB_PASS';
\$CFG->prefix    = 'mdl_';
\$CFG->dboptions = array (
  'dbpersist' => 0,
  'dbport' => '',
  'dbsocket' => '',
  'dbcollation' => 'utf8mb4_unicode_ci',
);

\$CFG->wwwroot   = '$FINAL_URL';
\$CFG->dataroot  = '$MOODLE_DATA';
\$CFG->admin     = 'admin';

\$CFG->directorypermissions = 0770;

require_once(__DIR__ . '/lib/setup.php');
EOF
    chown www-data:www-data "$MOODLE_PATH/config.php"
    chmod 644 "$MOODLE_PATH/config.php"
else
    echo -e "${GREEN}### 5. SALTANDO PRE-CONFIGURACIÓN (Se usará el asistente web)...${NC}"
fi

echo -e "${GREEN}### 6. CONFIGURANDO APACHE Y PHP...${NC}"

sed -i "s|DocumentRoot /var/www/html|DocumentRoot $MOODLE_PATH|" /etc/apache2/sites-available/000-default.conf

cat <<EOF > /etc/apache2/conf-available/moodle.conf
<Directory $MOODLE_PATH>
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>
EOF

a2enconf moodle
sed -i 's/memory_limit = .*/memory_limit = 256M/' /etc/php/$PHP_VER/apache2/php.ini
sed -i 's/;max_input_vars = .*/max_input_vars = 5000/' /etc/php/$PHP_VER/apache2/php.ini

# Re-aplicar permisos globales
chown -R www-data:www-data "$MOODLE_PATH"
chmod -R 755 "$MOODLE_PATH"

systemctl restart apache2

if [ "$QUERER_SSL" = "s" ]; then
    echo -e "${GREEN}### 7. OBTENIENDO CERTIFICADO SSL...${NC}"
    certbot --apache -d $DOMAIN --non-interactive --agree-tos -m $EMAIL --redirect
fi

echo "---------------------------------------------------------"
echo -e "${GREEN} ¡PROCESO COMPLETADO!${NC}"
echo "---------------------------------------------------------"
echo " Accede a: $FINAL_URL"
echo "---------------------------------------------------------"
echo " DATOS PARA LA BASE DE DATOS:"
echo " Servidor:    localhost"
echo " Tipo de BD:  mariadb"
echo " Nombre BD:   $DB_NAME"
echo " Usuario BD:  $DB_USER"
echo " Contraseña BD: $DB_PASS"
echo " Dir. Datos:  $MOODLE_DATA"
echo "---------------------------------------------------------"
if [ "$AUTO_CONFIG" = "s" ]; then
    echo -e "${GREEN}INFO: Archivo config.php generado. Termina la instalación en la web.${NC}"
else
    echo -e "INFO: Deberás introducir los datos anteriores manualmente en la web."
fi
echo "---------------------------------------------------------"
