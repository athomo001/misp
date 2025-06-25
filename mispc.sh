#!/bin/bash
# Instalación de MISP 2.5 para Ubuntu 24.04 LTS

# Verificar privilegios de root
if [ "$(id -u)" -ne 0 ]; then
    echo ""
    echo "╔═════════════════════════════════════════════════════════════════════════════╗"
    echo "║                               ¡ADVERTENCIA! - Rufian                        ║"
    echo "╟─────────────────────────────────────────────────────────────────────────────╢"
    echo "║  Este script requiere privilegios de administrador (root) para ejecutarse.  ║"
    echo "║                                                                             ║"
    echo "║  Por favor, ejecuta el script de una de las siguientes formas:              ║"
    echo "║    - iniciar sudo : sudo su                                                 ║"
    echo "║    - Usando sudo: bash mispc.sh                                             ║"
    echo "║                                                                             ║"
    echo "║  La instalación se detendrá para evitar errores de permisos.                ║"
    echo "╚═════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    exit 1
fi

# Esta guía está diseñada para ser una instalación sencilla de MISP en un servidor Ubuntu 24.04 LTS limpio.
# Ten en cuenta que aunque esto instala el software junto con todas sus dependencias, depende de ti asegurarlo adecuadamente.

# Esta guía toma prestado libremente de tres fuentes:
# - Las iteraciones anteriores de la guía oficial de instalación de MISP, que se puede encontrar en: https://misp.github.io/MISP
# - La guía de instalación automisp de @da667, que se puede encontrar en: https://github.com/da667/AutoMISP/blob/master/auto-MISP-ubuntu.sh
# - MISP-docker por @ostefano, que se puede encontrar en: https://github.com/MISP/MISP-docker
# ¡Gracias a Tony Robinson (@da667), Stefano Ortolani (@ostefano) y Steve Clement (@SteveClement) por su excelente trabajo!

# Este script de instalación asume que estás instalando como root, o como un usuario con acceso sudo.

#este script de instalación fue traducido por ATHAN
#se agregaron varias cosas  adicionales al scrip descargado  por misp

random_string() {
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1
}

# Configura las siguientes variables anticipadamente para tu entorno
## configuraciones requeridas - por favor cambia todas estas, no hacerlo resultará en una instalación que no funcionará o será altamente insegura
PASSWORD="$(random_string)"
MISP_DOMAIN='misp.local'
PATH_TO_SSL_CERT=''
INSTALL_SSDEEP='n' # s/n, si quieres instalar ssdeep, establécelo en 's', sin embargo, esto requerirá la instalación de make

# Validación del dominio MISP
if [ "$MISP_DOMAIN" = "misp.local" ]; then
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════════════╗"
    echo "║                               ¡ADVERTENCIA! - Rufian                       ║"
    echo "╟────────────────────────────────────────────────────────────────────────────╢"
    echo "║  Has dejado el dominio MISP con el valor predeterminado 'misp.local'.      ║"
    echo "║                                                                            ║"
    echo "║        aparte  porfa modifica el correo admin@admin.test                   ║"
    echo "║  Por favor, modifica la variable MISP_DOMAIN en el script con tu dominio   ║"
    echo "║  real o dirección IP antes de continuar.                                   ║"
    echo "║                                                                            ║"
    echo "║  La instalación se detendrá para evitar configuraciones incorrectas.       ║"
    echo "╚════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    exit 1
fi

## configuraciones opcionales
MISP_PATH='/var/www/MISP'
APACHE_USER='www-data'

### Configuraciones de la Base de Datos, si deseas usar un host, nombre, usuario o contraseña diferente de BD, por favor cámbialos aquí
DBHOST='localhost'
DBUSER_ADMIN='root'
DBPASSWORD_ADMIN='' # La configuración predeterminada en Ubuntu es una cuenta root sin contraseña, si la has cambiado, por favor configúrala aquí
DBNAME='misp'
DBPORT='3306'
DBUSER_MISP='misp'
DBPASSWORD_MISP="$(random_string)"

### Configuraciones de Supervisor
SUPERVISOR_USER='supervisor'
SUPERVISOR_PASSWORD="$(random_string)"

### Configuraciones de PHP
upload_max_filesize="50M"
post_max_size="50M"
max_execution_time="300"
memory_limit="2048M"

## GPG (GNU Privacy Guard)
GPG_EMAIL_ADDRESS="admin@admin.test"
GPG_PASSPHRASE="$(openssl rand -hex 32)"

### Solo necesario si no se proporciona un certificado SSL
OPENSSL_C='LU'
OPENSSL_ST='Luxembourg'
OPENSSL_L='Luxembourg'
OPENSSL_O='MISP'
OPENSSL_OU='MISP'
OPENSSL_CN=${MISP_DOMAIN}
OPENSSL_EMAILADDRESS='misp@'${MISP_DOMAIN}

# Algunas funciones auxiliares tomadas sin pudor del script de instalación automisp de @da667.

logfile=/var/log/misp_install.log
mkfifo ${logfile}.pipe
tee < ${logfile}.pipe $logfile &
exec &> ${logfile}.pipe
rm ${logfile}.pipe

function install_packages ()
{
    install_params=("$@")
    for i in "${install_params[@]}";
    do
        sudo apt-get install -y "$i" &>> $logfile
        error_check "$i installation"
    done
}


function error_check
{
    if [ $? -eq 0 ]; then
        print_ok "$1 successfully completed."
    else
        print_error "$1 failed. Please check $logfile for more details."
    exit 1
    fi
}

function error_check_soft
{
    if [ $? -eq 0 ]; then
        print_ok "$1 successfully completed."
    else
        print_error "$1 failed. Please check $logfile for more details. This is not a blocking failure though, proceeding..."
    fi
}

function print_status ()
{
    echo -e "\x1B[01;34m[STATUS]\x1B[0m $1"
}

function print_ok ()
{
    echo -e "\x1B[01;32m[OK]\x1B[0m $1"
}

function print_error ()
{
    echo -e "\x1B[01;31m[ERROR]\x1B[0m $1"
}

function print_notification ()
{
	echo -e "\x1B[01;33m[NOTICE]\x1B[0m $1"
}

function os_version_check ()
{
    # Verificar si estamos en Ubuntu 24.04 como se espera:
    UBUNTU_VERSION=$(lsb_release -a | grep Release | grep -oP '[\d-]+.[\d-]+$')
    if [[ "$UBUNTU_VERSION" != "24.04" ]]; then
        print_error "This upgrade tool expects you to be running Ubuntu 24.04. If you are on a prior upgrade of Ubuntu, please make sure that you upgrade your distribution first, then execute this script again."
        exit 1
    fi
}


# Colores
# Nota: Los colores de la bandera chilena se definen más adelante

# Función para centrar texto que preserva códigos de color ANSI
center() {
  local text="$1"
  # Calcular longitud visible del texto (sin contar códigos de color)
  local text_visible=$(echo -e "$text" | sed 's/\x1B\[[0-9;]*[JKmsu]//g')
  local width=$(tput cols)
  local padding=$(( (width - ${#text_visible}) / 2 ))
  printf "%*s%b\n" "$padding" "" "$text"
}

# Definir colores para la bandera chilena
RED='\033[1;31m'
WHITE='\033[1;37m'
BLUE='\033[1;34m'
NC='\033[0m'

# Banner (MISP en arte ASCII con color y banderas chilenas)
echo ""
center "${BLUE}███╗   ███╗██╗███████╗██████╗ ${NC}"
center "${BLUE}████╗ ████║██║██╔════╝██╔══██╗${NC}"
center "${BLUE}██╔████╔██║██║███████╗██████╔╝${NC}"
center "${BLUE}██║╚██╔╝██║██║╚════██║██╔═══╝ ${NC}"
center "${BLUE}██║ ╚═╝ ██║██║███████║██║     ${NC}"
center "${BLUE}╚═╝     ╚═╝╚═╝╚══════╝╚═╝     ${NC}"
echo ""
center "${WHITE} ██████╗██╗   ██╗${RED}██████╗ ███████╗███████╗${WHITE}██████╗ ███████╗ ██████╗${WHITE}██╗   ██╗██████╗ ██╗████████╗██╗   ██╗${NC}"
center "${WHITE}██╔════╝╚██╗ ██╔╝${RED}██╔══██╗██╔════╝██╔════╝${WHITE}██╔════╝██╔════╝██╔════╝${WHITE}██║   ██║██╔══██╗██║╚══██╔══╝╚██╗ ██╔╝${NC}"
center "${WHITE}██║      ╚████╔╝ ${RED}██████╔╝█████╗  █████╗  ${WHITE}███████╗█████╗  ██║     ${WHITE}██║   ██║██████╔╝██║   ██║    ╚████╔╝ ${NC}"
center "${WHITE}██║       ╚██╔╝  ${RED}██╔══██╗██╔══╝  ██╔══╝  ${WHITE}╚════██║██╔══╝  ██║     ${WHITE}██║   ██║██╔══██╗██║   ██║     ╚██╔╝  ${NC}"
center "${WHITE}╚██████╗   ██║   ${RED}██████╔╝███████╗███████╗${WHITE}███████║███████╗╚██████╗${WHITE}╚██████╔╝██║  ██║██║   ██║      ██║   ${NC}"
center "${WHITE}╚═════╝   ╚═╝   ${RED}╚═════╝ ╚══════╝╚══════╝${WHITE}╚══════╝╚══════╝ ╚═════╝${WHITE} ╚═════╝ ╚═╝  ╚═╝╚═╝   ╚═╝      ╚═╝   ${NC}"
echo ""
center "Configuración v2.5 en Ubuntu 24.04 LTS"
center "script Auspiciado por cybeersecurity - pongale color y tome cerveza o aguita"
echo ""
echo

# Animación tipo "Loading..."
center "Iniciando configuración..."
sleep 0.5
for i in {1..3}; do
  center "Cargando$(printf '%*s' "$i" | tr ' ' '.')"
  sleep 1
done
echo

os_version_check

save_settings() {
    echo "[$(date)] MISP installation

[MISP admin user]
- Admin Username: ${GPG_EMAIL_ADDRESS}
- Admin Password: ${PASSWORD}
- Admin API key: ${MISP_USER_KEY}

[MYSQL ADMIN]
- Username: ${DBUSER_ADMIN}
- Password: ${DBPASSWORD_ADMIN}

[MYSQL MISP]
- Username: ${DBUSER_MISP}
- Password: ${DBPASSWORD_MISP}

[MISP internal]
- Path: ${MISP_PATH}
- Apache user: ${APACHE_USER}
- GPG Email: ${GPG_EMAIL_ADDRESS}
- GPG Passphrase: ${GPG_PASSPHRASE}
- SUPERVISOR_USER: ${SUPERVISOR_USER}
- SUPERVISOR_PASSWORD: ${SUPERVISOR_PASSWORD}
" | tee /var/log/misp_settings.txt  &>> $logfile

    print_notification "Settings saved to /var/log/misp_settings.txt"
}

print_status "Updating base system..."
sudo apt-get update &>> $logfile
sudo apt-get upgrade -y &>> $logfile
error_check "Base system update"

print_status "Instalación de paquetes apt (git curl python3 python3-pip python3-virtualenv apache2 zip gcc sudo binutils openssl supervisor)..."
declare -a packages=( git curl python3 python3-pip python3-virtualenv apache2 zip gcc sudo binutils openssl supervisor );
install_packages ${packages[@]}
error_check "Instalación de dependencias básicas."

print_status "Instalandi MariaDB..."
declare -a packages=( mariadb-server mariadb-client );
install_packages ${packages[@]}
error_check "MariaDB instalación"


print_status "Instalación de PHP y la lista de extensiones necesarias..."
declare -a packages=( redis-server php8.3 php8.3-cli php8.3-dev php8.3-xml php8.3-mysql php8.3-opcache php8.3-readline php8.3-mbstring php8.3-zip \
  php8.3-intl php8.3-bcmath php8.3-gd php8.3-redis php8.3-gnupg php8.3-apcu libapache2-mod-php8.3 php8.3-curl );
install_packages ${packages[@]}
PHP_ETC_BASE=/etc/php/8.3
PHP_INI=${PHP_ETC_BASE}/apache2/php.ini
error_check "Instalación de PHP y extensiones necesarias."

# Instalar composer y las dependencias de composer de MISP

print_status "Installing composer..."

## hacer felices a pip y composer
sudo mkdir /var/www/.cache/
sudo chown -R ${APACHE_USER}:${APACHE_USER} /var/www/.cache/

curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php &>> $logfile
COMPOSER_HASH=`curl -sS https://composer.github.io/installer.sig`
php -r "if (hash_file('SHA384', '/tmp/composer-setup.php') === '$COMPOSER_HASH') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"  &>> $logfile
sudo php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer  &>> $logfile
error_check "Composer installation"

print_status "Configurando las configuraciones de PHP y MySQL..."
for key in upload_max_filesize post_max_size max_execution_time max_input_time memory_limit
do
    sudo sed -i "s/^\($key\).*/\1 = $(eval echo \${$key})/" $PHP_INI
done
sudo sed -i "s/^\(session.sid_length\).*/\1 = 32/" $PHP_INI
sudo sed -i "s/^\(session.use_strict_mode\).*/\1 = 1/" $PHP_INI
sudo sed -i "s/^\(session.save_handler\).*/\1 = redis/" $PHP_INI
sudo sed -i "/session.save_handler/a session.save_path = 'tcp:\/\/localhost:6379'/" $PHP_INI

MYCNF="/etc/mysql/mariadb.conf.d/50-server.cnf"
# Configuramos un tamaño de buffer pool de innodb del 50% de la memoria disponible

# Verificar los límites de memoria de cgroup, no confiar en /proc/meminfo en un contenedor LXC con límites de memoria no acotados
# Gracias a Sascha Rommelfangen (@rommelfs) por la pista
CGROUPMEMORYHIGHPATH="/sys/fs/cgroup/memory.high"
if [ -f $CGROUPMEMORYHIGHPATH ] && [[ "cat ${CGROUPMEMORYHIGHPATH}" == "max" ]]; then
    INNODBBUFFERPOOLSIZE='2048M'
else
    INNODBBUFFERPOOLSIZE=$(grep MemTotal /proc/meminfo | awk '{print int($2 / 2048)}')'M'
fi

sudo sed -i "/\[mariadb\]/a innodb_buffer_pool_size = ${INNODBBUFFERPOOLSIZE}" $MYCNF
sudo sed -i '/\[mariadb\]/a innodb_io_capacity = 1000' $MYCNF
sudo sed -i '/\[mariadb\]/a innodb_read_io_threads = 16' $MYCNF

sudo service apache2 restart
error_check "Apache restart"
sudo service mysql restart
error_check "MySQL restart"

print_ok "PHP and MySQL configurado..."

print_status "Instalando PECL extensiones..."

sudo pecl channel-update pecl.php.net &>> $logfile || echo "Continuing despite error in updating PECL channel"
sudo pecl install brotli &>> $logfile
error_check_soft "PECL brotli extension installation" || echo "Continuing despite error in installing PECL brotli extension"
sudo pecl install simdjson &>> $logfile
error_check_soft "PECL simdjson extension installation" || echo "Continuing despite error in installing PECL simdjson extension"
sudo pecl install zstd &>> $logfile
error_check_soft "PECL zstd extension installation" || echo "Continuing despite error in installing PECL zstd extension"

if [ $INSTALL_SSDEEP == "y" ]; then
    sudo apt install make -y &>> $logfile
    error_check "La instalación de make" || echo "Continuar a pesar del error en la instalación de make"

    git clone --recursive --depth=1 https://github.com/JakubOnderka/pecl-text-ssdeep.git /tmp/pecl-text-ssdeep
    error_check "Clonación de la extensión PHP8 SSDEEP de Jakub Onderka" || echo "Continuar a pesar del error al clonar la extensión SSDEEP"

    cd /tmp/pecl-text-ssdeep && phpize && ./configure && make && make install
    error_check "Compilación e instalación de la extensión PHP8 SSDEEP de Jakub Onderka" || echo "Continuar a pesar del error en la compilación e instalación de SSDEEP"
fi


print_status "Clonando MISP Papus!"
sudo git clone https://github.com/MISP/MISP.git ${MISP_PATH}  &>> $logfile
error_check "MISP Clonando"
cd ${MISP_PATH}
git fetch origin 2.5 &>> $logfile
error_check "Fetching 2.5 branch"
git checkout 2.5 &>> $logfile
error_check "Revisando 2.5 branch"

print_status "Clonando MISP submodulos..."
sudo git config --global --add safe.directory ${MISP_PATH}  &>> $logfile
sudo git -C ${MISP_PATH} submodule update --init --recursive &>> $logfile
error_check "MISP submodules cloning"
sudo git -C ${MISP_PATH} submodule foreach --recursive git config core.filemode false &>> $logfile
sudo chown -R ${APACHE_USER}:${APACHE_USER} ${MISP_PATH} &>> $logfile
sudo chown -R ${APACHE_USER}:${APACHE_USER} ${MISP_PATH}/.git &>> $logfile
print_ok "MISP's submodules cloned."

print_status "Instalando MISP composer dependencias..."
cd ${MISP_PATH}/app
sudo -u ${APACHE_USER} composer install --no-dev --no-interaction --prefer-dist &>> $logfile
error_check "MISP composer dependencias de instalacion"

print_status "Creando la DB and usuario de MISP así como importar el esquema básico MISP..."
DBUSER_ADMIN_STRING=''
if [ "$DBUSER_ADMIN" != 'root' ]; then
    DBUSER_ADMIN_STRING='-u '"${DBUSER_ADMIN}"
fi

DBPASSWORD_ADMIN_STRING=''
if [ ! -z "${DBPASSWORD_ADMIN}" ]; then
    DBPASSWORD_ADMIN_STRING='-p'"${DBPASSWORD_ADMIN}"
fi

DBUSER_MISP_STRING=''
if [ ! -z "${DBUSER_MISP}" ]; then
    DBUSER_MISP_STRING='-u '"${DBUSER_MISP}"
fi

DBPASSWORD_MISP_STRING=''
if [ ! -z "${DBPASSWORD_MISP}" ]; then
    DBPASSWORD_MISP_STRING='-p'"${DBPASSWORD_MISP}"
fi

DBHOST_STRING=''
if [ ! -z "$DBHOST" ] && [ "$DBHOST" != "localhost" ]; then
    DBHOST_STRING="-h ${DBHOST}"
fi

DBPORT_STRING=''
if [ "$DBPORT" != 3306 ]; then
    DBPORT_STRING='--port '"${DBPORT}"
fi
DBCONN_ADMIN_STRING="${DBPORT_STRING} ${DBHOST_STRING} ${DBUSER_ADMIN_STRING} ${DBPASSWORD_ADMIN_STRING}"
DBCONN_MISP_STRING="${DBPORT_STRING} ${DBHOST_STRING} ${DBUSER_MISP_STRING} ${DBPASSWORD_MISP_STRING}"

sudo mysql $DBCONN_ADMIN_STRING -e "CREATE DATABASE ${DBNAME};"  &>> $logfile
sudo mysql $DBCONN_ADMIN_STRING -e "CREATE USER '${DBUSER_MISP}'@'localhost' IDENTIFIED BY '${DBPASSWORD_MISP}';"  &>> $logfile
sudo mysql $DBCONN_ADMIN_STRING -e "GRANT USAGE ON *.* to '${DBUSER_MISP}'@'localhost';"  &>> $logfile
sudo mysql $DBCONN_ADMIN_STRING -e "GRANT ALL PRIVILEGES on ${DBNAME}.* to '${DBUSER_MISP}'@'localhost';"  &>> $logfile
sudo mysql $DBCONN_ADMIN_STRING -e "FLUSH PRIVILEGES;"  &>> $logfile
mysql $DBCONN_MISP_STRING $DBNAME < "${MISP_PATH}/INSTALL/MYSQL.sql"  &>> $logfile
error_check "MISP importación de esquema de base de datos"

print_status "Mover y configurar los archivos de configuración php de MISP.."

cd ${MISP_PATH}/app/Config
cp -a bootstrap.default.php bootstrap.php
cp -a database.default.php database.php
cp -a core.default.php core.php
cp -a config.default.php config.php
sed -i "s#3306#${DBPORT}#" database.php
sed -i "s#'host' => 'localhost'#'host' => '$DBHOST'#" database.php
sed -i "s#db login#$DBUSER_MISP#" database.php
sed -i "s#db password#$DBPASSWORD_MISP#" database.php
sed -i "s#'database' => 'misp'#'database' => '$DBNAME'#" database.php
sed -i "s#Rooraenietu8Eeyo<Qu2eeNfterd-dd+#$(random_string)#" config.php

print_ok "Archivos de configuración php de MISP movidos y configurados."

# Generar certificado ssl
if [ -z "${PATH_TO_SSL_CERT}" ]; then
    print_notification "Generating self-signed SSL certificate."
    sudo openssl req -newkey rsa:4096 -days 365 -nodes -x509 \
    -subj "/C=${OPENSSL_C}/ST=${OPENSSL_ST}/L=${OPENSSL_L}/O=${OPENSSL_O}/OU=${OPENSSL_OU}/CN=${OPENSSL_CN}/emailAddress=${OPENSSL_EMAILADDRESS}" \
    -keyout /etc/ssl/private/misp.local.key -out /etc/ssl/private/misp.local.crt &>> $logfile
    error_check "Self-signed SSL certificate generation"
else
    print_status "Usando el certificado SSL proporcionado."
fi

# Generar archivo misp-ssl.conf
print_status "Creación de un archivo de configuración de Apache para MISP..."

  echo "<VirtualHost _default_:80>
          ServerAdmin admin@$MISP_DOMAIN
          ServerName $MISP_DOMAIN

          Redirect permanent / https://$MISP_DOMAIN

          LogLevel warn
          ErrorLog /var/log/apache2/misp.local_error.log
          CustomLog /var/log/apache2/misp.local_access.log combined
          ServerSignature Off
  </VirtualHost>

  <VirtualHost _default_:443>
          ServerAdmin admin@$MISP_DOMAIN
          ServerName $MISP_DOMAIN
          DocumentRoot $MISP_PATH/app/webroot

          <Directory $MISP_PATH/app/webroot>
                  Options -Indexes
                  AllowOverride all
  		            Require all granted
                  Order allow,deny
                  allow from all
          </Directory>

          SSLEngine On
          SSLCertificateFile /etc/ssl/private/misp.local.crt
          SSLCertificateKeyFile /etc/ssl/private/misp.local.key

          LogLevel warn
          ErrorLog /var/log/apache2/misp.local_error.log
          CustomLog /var/log/apache2/misp.local_access.log combined
          ServerSignature Off
          Header set X-Content-Type-Options nosniff
          Header set X-Frame-Options DENY
  </VirtualHost>" | sudo tee /etc/apache2/sites-available/misp-ssl.conf  &>> $logfile

error_check "Creación del archivo de configuración de Apache"  &>> $logfile


print_status "Ejecutando actualizaciones de MISP"

sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.osuser" ${APACHE_USER} &>> $logfile
sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin runUpdates &>> $logfile
sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake User init | sudo tee /tmp/misp_user_key.txt  &>> $logfile
sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake User change_pw "${GPG_EMAIL_ADDRESS}" "${PASSWORD}" &>> $logfile
MISP_USER_KEY=`cat /tmp/misp_user_key.txt`
rm -f /tmp/misp_user_key.txt

print_ok "MISP updated."

print_status "Generando PGP key"
# La dirección de correo electrónico debe coincidir con la establecida en config.php
# configurada en el menú de configuración en el archivo de configuración del menú de administración

sudo -u ${APACHE_USER} gpg --homedir $MISP_PATH/.gnupg --quick-generate-key --batch --passphrase $GPG_PASSPHRASE ${GPG_EMAIL_ADDRESS} ed25519 sign never  &>> $logfile
error_check "PGP key generation"
# Exportar la clave pública al directorio raíz web
sudo -u ${APACHE_USER} gpg --homedir $MISP_PATH/.gnupg --export --armor ${GPG_EMAIL_ADDRESS} | sudo -u ${APACHE_USER} tee $MISP_PATH/app/webroot/gpg.asc  &>> $logfile
error_check "PGP key export"

print_status "Configuración del entorno Python para MISP"

# Crear un entorno virtual de python3
sudo -u ${APACHE_USER} virtualenv -p python3 ${MISP_PATH}/venv &>> $logfile
error_check "Python virtualenv creation"

cd ${MISP_PATH}
. ./venv/bin/activate &>> $logfile
error_check "Activación del entorno virtual de Python"

# instalar dependencias de python
${MISP_PATH}/venv/bin/pip install -r ${MISP_PATH}/requirements.txt  &>> $logfile
error_check "Instalación de dependencias de Python"

chown -R ${APACHE_USER}:${APACHE_USER} ${MISP_PATH}/venv

print_status "Configurando trabajadores en segundo plano"

sudo echo "
[inet_http_server]
port=127.0.0.1:9001
username=$SUPERVISOR_USER
password=$SUPERVISOR_PASSWORD" | sudo tee -a /etc/supervisor/supervisord.conf  &>> $logfile

sudo echo "[group:misp-workers]
programs=default,email,cache,prio,update

[program:default]
directory=$MISP_PATH
command=$MISP_PATH/app/Console/cake start_worker default
process_name=%(program_name)s_%(process_num)02d
numprocs=5
autostart=true
autorestart=true
redirect_stderr=false
stderr_logfile=$MISP_PATH/app/tmp/logs/misp-workers-errors.log
stdout_logfile=$MISP_PATH/app/tmp/logs/misp-workers.log
directory=$MISP_PATH
user=$APACHE_USER

[program:prio]
directory=$MISP_PATH
command=$MISP_PATH/app/Console/cake start_worker prio
process_name=%(program_name)s_%(process_num)02d
numprocs=5
autostart=true
autorestart=true
redirect_stderr=false
stderr_logfile=$MISP_PATH/app/tmp/logs/misp-workers-errors.log
stdout_logfile=$MISP_PATH/app/tmp/logs/misp-workers.log
directory=$MISP_PATH
user=$APACHE_USER

[program:email]
directory=$MISP_PATH
command=$MISP_PATH/app/Console/cake start_worker email
process_name=%(program_name)s_%(process_num)02d
numprocs=5
autostart=true
autorestart=true
redirect_stderr=false
stderr_logfile=$MISP_PATH/app/tmp/logs/misp-workers-errors.log
stdout_logfile=$MISP_PATH/app/tmp/logs/misp-workers.log
directory=$MISP_PATH
user=$APACHE_USER

[program:update]
directory=$MISP_PATH
command=$MISP_PATH/app/Console/cake start_worker update
process_name=%(program_name)s_%(process_num)02d
numprocs=1
autostart=true
autorestart=true
redirect_stderr=false
stderr_logfile=$MISP_PATH/app/tmp/logs/misp-workers-errors.log
stdout_logfile=$MISP_PATH/app/tmp/logs/misp-workers.log
directory=$MISP_PATH
user=$APACHE_USER

[program:cache]
directory=$MISP_PATH
command=$MISP_PATH/app/Console/cake start_worker cache
process_name=%(program_name)s_%(process_num)02d
numprocs=5
autostart=true
autorestart=true
redirect_stderr=false
stderr_logfile=$MISP_PATH/app/tmp/logs/misp-workers-errors.log
stdout_logfile=$MISP_PATH/app/tmp/logs/misp-workers.log
user=$APACHE_USER"  | sudo tee -a /etc/supervisor/conf.d/misp-workers.conf  &>> $logfile

sudo systemctl restart supervisor  &>> $logfile
error_check "Background workers setup"

# Configurar ajustes
  # La instalación predeterminada es Python >=3.6 en un entorno virtual, configurando en consecuencia
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.python_bin" "${MISP_PATH}/venv/bin/python" &>> $logfile

  # Ajustar tiempos de espera globales
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Session.autoRegenerate" 0 &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Session.timeout" 600 &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Session.cookieTimeout" 3600 &>> $logfile
 
  # Establecer el directorio temporal predeterminado
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.tmpdir" "${MISP_PATH}/app/tmp" &>> $logfile

  # Cambiar URL base, ya sea con este comando CLI o en la interfaz de usuario
  [[ ! -z ${MISP_DOMAIN} ]] && sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake admin setSetting MISP.baseurl "https://${MISP_DOMAIN}" &>> $logfile
  [[ ! -z ${MISP_DOMAIN} ]] && sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.external_baseurl" ${MISP_BASEURL} &>> $logfile

  # Habilitar GnuPG
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "GnuPG.email" "${GPG_EMAIL_ADDRESS}" &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "GnuPG.homedir" "${MISP_PATH}/.gnupg" &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "GnuPG.password" "${GPG_PASSPHRASE}" &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "GnuPG.obscure_subject" true &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "GnuPG.key_fetching_disabled" false &>> $logfile
  # FIXME: ¿qué pasa si no tenemos el binario gpg sino uno gpg2?
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "GnuPG.binary" "$(which gpg)" &>> $logfile

  # Habilitar la organización instaladora y ajustar algunas configuraciones
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.host_org_id" 1 &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.email" "${GPG_EMAIL_ADDRESS}" &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.disable_emailing" false &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.contact" "${GPG_EMAIL_ADDRESS}" &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.disablerestalert" true &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.showCorrelationsOnIndex" true &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.default_event_tag_collection" 0 &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.log_new_audit" 1 &>> $logfile

  # Configurar trabajadores en segundo plano
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "SimpleBackgroundJobs.enabled" 1 &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "SimpleBackgroundJobs.redis_host" '127.0.0.1' &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "SimpleBackgroundJobs.redis_port" 6379 &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "SimpleBackgroundJobs.redis_database" 13 &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "SimpleBackgroundJobs.redis_password" "" &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "SimpleBackgroundJobs.redis_namespace" "background_jobs" &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "SimpleBackgroundJobs.supervisor_host" "localhost" &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "SimpleBackgroundJobs.supervisor_port" 9001 &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "SimpleBackgroundJobs.supervisor_user" ${SUPERVISOR_USER} &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "SimpleBackgroundJobs.supervisor_password" ${SUPERVISOR_PASSWORD} &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "SimpleBackgroundJobs.redis_serializer" "JSON" &>> $logfile

  # Varias configuraciones del plugin de avistamientos
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Plugin.Sightings_policy" 0 &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Plugin.Sightings_anonymise" false &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Plugin.Sightings_anonymise_as" 1 &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Plugin.Sightings_range" 365 &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Plugin.Sightings_sighting_db_enable" false &>> $logfile

  # Configuraciones de ZeroMQ
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Plugin.ZeroMQ_enable" false &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Plugin.ZeroMQ_host" "127.0.0.1" &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Plugin.ZeroMQ_port" 50000 &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Plugin.ZeroMQ_redis_host" "localhost" &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Plugin.ZeroMQ_redis_port" 6379 &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Plugin.ZeroMQ_redis_database" 1 &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Plugin.ZeroMQ_redis_namespace" "mispq" &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Plugin.ZeroMQ_event_notifications_enable" false &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Plugin.ZeroMQ_object_notifications_enable" false &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Plugin.ZeroMQ_object_reference_notifications_enable" false &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Plugin.ZeroMQ_attribute_notifications_enable" false &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Plugin.ZeroMQ_sighting_notifications_enable" false &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Plugin.ZeroMQ_user_notifications_enable" false &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Plugin.ZeroMQ_organisation_notifications_enable" false &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Plugin.ZeroMQ_include_attachments" false &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Plugin.ZeroMQ_tag_notifications_enable" false &>> $logfile

  # Forzar valores predeterminados para que la configuración del servidor MISP tenga menos ROJOS
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.language" "eng" &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.proposals_block_attributes" false &>> $logfile

  # Bloque de Redis
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.redis_host" "127.0.0.1" &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.redis_port" 6379 &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.redis_database" 13 &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.redis_password" "" &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.redis_serializer" "JSON" &>> $logfile

  # Forzar valores predeterminados para que la configuración del servidor MISP tenga menos AMARILLOS
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.ssdeep_correlation_threshold" 40 &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.extended_alert_subject" false &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.default_event_threat_level" 4 &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.newUserText" "Dear new MISP user,\\n\\nWe would hereby like to welcome you to the \$org MISP community.\\n\\n Use the credentials below to log into MISP at \$misp, where you will be prompted to manually change your password to something of your own choice.\\n\\nUsername: \$username\\nPassword: \$password\\n\\nIf you have any questions, don't hesitate to contact us at: \$contact.\\n\\nBest regards,\\nYour \$org MISP support team" &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.passwordResetText" "Dear MISP user,\\n\\nA password reset has been triggered for your account. Use the below provided temporary password to log into MISP at \$misp, where you will be prompted to manually change your password to something of your own choice.\\n\\nUsername: \$username\\nYour temporary password: \$password\\n\\nIf you have any questions, don't hesitate to contact us at: \$contact.\\n\\nBest regards,\\nYour \$org MISP support team" &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.enableEventBlocklisting" true &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.enableOrgBlocklisting" true &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.log_client_ip" true &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.log_auth" false &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.log_user_ips" true &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.log_user_ips_authkeys" true &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.disableUserSelfManagement" false &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.disable_user_login_change" false &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.disable_user_password_change" false &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.disable_user_add" false &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.block_event_alert" false &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.block_event_alert_tag" "no-alerts=\"true\"" &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.block_old_event_alert" false &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.block_old_event_alert_age" "" &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.block_old_event_alert_by_date" "" &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.event_alert_republish_ban" true &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.event_alert_republish_ban_threshold" 5 &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.event_alert_republish_ban_refresh_on_retry" false &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.incoming_tags_disabled_by_default" false &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.attachments_dir" "${MISP_PATH}/app/files" &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.download_attachments_on_load" true &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.event_alert_metadata_only" false &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "MISP.terms_download" false &>> $logfile

  # Forzar valores predeterminados para que la configuración del servidor MISP tenga menos VERDES
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "debug" 0 &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Security.auth_enforced" false &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Security.log_each_individual_auth_fail" false &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Security.rest_client_baseurl" "" &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Security.advanced_authkeys" true &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Security.password_policy_length" 12 &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Security.password_policy_complexity" '/^((?=.*\\d)|(?=.*\\W+))(?![\\n])(?=.*[A-Z])(?=.*[a-z]).*$|.{16,}/' &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Security.self_registration_message" "If you would like to send us a registration request, please fill out the form below. Make sure you fill out as much information as possible in order to ease the task of the administrators." &>> $logfile

  # Satisfacer la auditoría de seguridad, #endurecimiento
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Security.disable_browser_cache" true &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Security.check_sec_fetch_site_header" true &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Security.csp_enforce" true &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Security.advanced_authkeys" true &>> $logfile
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Security.do_not_log_authkeys" true &>> $logfile

  # Satisfacer la auditoría de seguridad, #registro
  sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin setSetting "Security.username_in_response_header" true &>> $logfile

print_ok "Configuraciones configuradas."

print_status "Ingiriendo estructuras JSON"
sudo -u ${APACHE_USER} ${MISP_PATH}/app/Console/cake Admin updateJSON &>> $logfile
error_check "JSON structures ingestion"

  # Habilitar módulos, configuraciones y SSL predeterminado en Apache
  sudo a2dismod status &>> $logfile
  sudo a2enmod ssl &>> $logfile
  sudo a2enmod rewrite &>> $logfile
  sudo a2enmod headers &>> $logfile
  sudo a2dissite 000-default &>> $logfile
  sudo a2ensite default-ssl &>> $logfile

  # activar el nuevo host virtual
  sudo a2dissite default-ssl &>> $logfile
  sudo a2ensite misp-ssl &>> $logfile

  # Reiniciar apache
  sudo systemctl restart apache2 &>> $logfile
  error_check "Apache restart"

print_ok "Settings configured."

print_status "Finalizando la configuración de MISP..."
sudo chown -R ${APACHE_USER}:${APACHE_USER} ${MISP_PATH} &>> $logfile
sudo chown -R ${APACHE_USER}:${APACHE_USER} ${MISP_PATH}/.git &>> $logfile

save_settings

print_notification "═══════════════════════════════════════════════════════════════════════════════"
print_notification "                          INSTALACIÓN DE MISP COMPLETADA                      "
print_notification "═══════════════════════════════════════════════════════════════════════════════"
print_notification ""
print_notification "🌐 ACCESO A MISP:"
print_notification "   URL: https://${MISP_DOMAIN}"
print_notification "═══════════════════════════════════════════════════════════════════════════════"
print_notification "👤 CREDENCIALES DEL ADMINISTRADOR:"
print_notification "   Usuario: ${GPG_EMAIL_ADDRESS}"
print_notification "   Contraseña: ${PASSWORD}"
print_notification "   Longitud contraseña: ${#PASSWORD} caracteres"
print_notification "   API Key: ${MISP_USER_KEY}"
print_notification "═══════════════════════════════════════════════════════════════════════════════"
print_notification "🗄️  INFORMACIÓN DE BASE DE DATOS:"
print_notification "   Host: ${DBHOST}:${DBPORT}"
print_notification "   Base de datos: ${DBNAME}"
print_notification "   Usuario MISP: ${DBUSER_MISP}"
print_notification "   Contraseña MISP: ${DBPASSWORD_MISP}"
print_notification "   Usuario Admin: ${DBUSER_ADMIN}"
print_notification "   Contraseña Admin: ${DBPASSWORD_ADMIN}"
print_notification "═══════════════════════════════════════════════════════════════════════════════"
print_notification "🔐 INFORMACIÓN DE SEGURIDAD:"
print_notification "   Email GPG: ${GPG_EMAIL_ADDRESS}"
print_notification "   Frase de paso GPG: ${GPG_PASSPHRASE}"
print_notification "═══════════════════════════════════════════════════════════════════════════════"
print_notification "⚙️  SUPERVISOR (Workers en segundo plano):"
print_notification "   Usuario Supervisor: ${SUPERVISOR_USER}"
print_notification "   Contraseña Supervisor: ${SUPERVISOR_PASSWORD}"
print_notification "   Panel web: http://localhost:9001"
print_notification "═══════════════════════════════════════════════════════════════════════════════"
print_notification "📁 ARCHIVOS DE CONFIGURACIÓN:"
print_notification "   Instalación MISP: ${MISP_PATH}"
print_notification "   Log de instalación: ${logfile}"
print_notification "   Configuraciones guardadas: /var/log/misp_settings.txt"
print_notification ""
print_notification "═══════════════════════════════════════════════════════════════════════════════"
print_notification "¡Instalación completada exitosamente! 🎉"
print_notification "Recuerda cambiar las contraseñas por defecto después del primer acceso."
print_notification ""
print_notification "IMPORTANTE: Si la contraseña no funciona, revisa el archivo:"
print_notification "/var/log/misp_settings.txt para información detallada de depuración"
print_notification "También puedes revisar el log completo en: ${logfile}"
print_notification "═══════════════════════════════════════════════════════════════════════════════"
