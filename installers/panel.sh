#!/bin/bash

set -e

######################################################################################
#                                                                                    #
# Project 'sofinco-pterodactyl'                                                      #
#                                                                                    #
# Copyright (C) 2026, Sofinco                    #
#                                                                                    #
#   This program is free software: you can redistribute it and/or modify             #
#   it under the terms of the GNU General Public License as published by             #
#   the Free Software Foundation, either version 3 of the License, or                #
#   (at your option) any later version.                                              #
#                                                                                    #
#   This program is distributed in the hope that it will be useful,                  #
#   but WITHOUT ANY WARRANTY; without even the implied warranty of                   #
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                    #
#   GNU General Public License for more details.                                     #
#                                                                                    #
#   You should have received a copy of the GNU General Public License                #
#   along with this program.  If not, see <https://www.gnu.org/licenses/>.           #
#                                                                                    #
# https://github.com/levouinse/sofinco-pterodactyl/blob/master/LICENSE              #
#                                                                                    #
# This script is not associated with the official Pterodactyl Project.               #
# https://github.com/levouinse/sofinco-pterodactyl                                   #
#                                                                                    #
######################################################################################

# Check if script is loaded, load if not or fail otherwise.
fn_exists() { declare -F "$1" >/dev/null; }
if ! fn_exists lib_loaded; then
  # shellcheck source=lib/lib.sh
  source /tmp/lib.sh || source <(curl -sSL "$GITHUB_BASE_URL/$GITHUB_SOURCE"/lib/lib.sh)
  ! fn_exists lib_loaded && echo "* ERROR: Could not load lib script" && exit 1
fi

# ------------------ Variables ----------------- #

# Domain name / IP
FQDN="${FQDN:-localhost}"

# Default MySQL credentials
MYSQL_DB="${MYSQL_DB:-panel}"
MYSQL_USER="${MYSQL_USER:-pterodactyl}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-$(gen_passwd 64)}"

# Environment
timezone="${timezone:-Europe/Stockholm}"

# Assume SSL, will fetch different config if true
ASSUME_SSL="${ASSUME_SSL:-false}"
CONFIGURE_LETSENCRYPT="${CONFIGURE_LETSENCRYPT:-false}"

# Firewall
CONFIGURE_FIREWALL="${CONFIGURE_FIREWALL:-false}"

# Must be assigned to work, no default values
email="${email:-}"
user_email="${user_email:-}"
user_username="${user_username:-}"
user_firstname="${user_firstname:-}"
user_lastname="${user_lastname:-}"
user_password="${user_password:-}"

missing=()

for var in email user_email user_username user_firstname user_lastname user_password; do
  if [[ -z "${!var}" ]]; then
    missing+=("$var")
  fi
done

if (( ${#missing[@]} > 0 )); then
  for m in "${missing[@]}"; do
    error "${m} is required"
  done
  exit 1
fi


# --------- Main installation functions -------- #

install_composer() {
  output "Installing composer.."
  curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
  success "Composer installed!"
}

ptdl_dl() {
  output "Downloading pterodactyl panel files .. "
  mkdir -p /var/www/pterodactyl
  cd /var/www/pterodactyl || exit

  curl -Lo panel.tar.gz "$PANEL_DL_URL"
  tar -xzvf panel.tar.gz
  chmod -R 755 storage/* bootstrap/cache/

  cp .env.example .env

  success "Downloaded pterodactyl panel files!"
}

install_composer_deps() {
  output "Installing composer dependencies.."
  case "$OS" in
    rocky | almalinux | fedora | arch | endeavouros | artix | gentoo | void | freebsd | slackware)
      export PATH=/usr/local/bin:$PATH
      ;;
  esac
  COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader
  success "Installed composer dependencies!"
}

# Configure environment
configure() {
  output "Configuring environment.."

  local app_url="http://$FQDN"
  [ "$ASSUME_SSL" == true ] && app_url="https://$FQDN"
  [ "$CONFIGURE_LETSENCRYPT" == true ] && app_url="https://$FQDN"

  # Generate encryption key
  php artisan key:generate --force

  # Fill in environment:setup automatically
  php artisan p:environment:setup \
    --author="$email" \
    --url="$app_url" \
    --timezone="$timezone" \
    --cache="redis" \
    --session="redis" \
    --queue="redis" \
    --redis-host="localhost" \
    --redis-pass="null" \
    --redis-port="6379" \
    --settings-ui=true

  # Fill in environment:database credentials automatically
  php artisan p:environment:database \
    --host="127.0.0.1" \
    --port="3306" \
    --database="$MYSQL_DB" \
    --username="$MYSQL_USER" \
    --password="$MYSQL_PASSWORD"

  # configures database
  php artisan migrate --seed --force

  # Create user account
  php artisan p:user:make \
    --email="$user_email" \
    --username="$user_username" \
    --name-first="$user_firstname" \
    --name-last="$user_lastname" \
    --password="$user_password" \
    --admin=1

  success "Configured environment!"
}

# set the correct folder permissions depending on OS and webserver
set_folder_permissions() {
  case "$OS" in
  debian | ubuntu)
    chown -R www-data:www-data ./*
    ;;
  rocky | almalinux | fedora)
    chown -R nginx:nginx ./*
    ;;
  arch | endeavouros | artix | gentoo | void | slackware)
    chown -R http:http ./* 2>/dev/null || chown -R nginx:nginx ./* 2>/dev/null || chown -R www-data:www-data ./* 2>/dev/null || chown -R www:www ./*
    ;;
  freebsd)
    chown -R www:www ./*
    ;;
  esac
}

insert_cronjob() {
  output "Installing cronjob.. "

  crontab -l | {
    cat
    output "* * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1"
  } | crontab -

  success "Cronjob installed!"
}

install_pteroq() {
  output "Installing pteroq service.."

  curl -o /etc/systemd/system/pteroq.service "$GITHUB_URL"/configs/pteroq.service

  case "$OS" in
  debian | ubuntu)
    sed -i -e "s@<user>@www-data@g" /etc/systemd/system/pteroq.service
    ;;
  rocky | almalinux | fedora)
    sed -i -e "s@<user>@nginx@g" /etc/systemd/system/pteroq.service
    ;;
  arch | endeavouros | artix | gentoo | void | slackware)
    sed -i -e "s@<user>@http@g" /etc/systemd/system/pteroq.service 2>/dev/null || sed -i -e "s@<user>@nginx@g" /etc/systemd/system/pteroq.service 2>/dev/null || sed -i -e "s@<user>@www-data@g" /etc/systemd/system/pteroq.service 2>/dev/null || sed -i -e "s@<user>@www@g" /etc/systemd/system/pteroq.service
    ;;
  freebsd)
    sed -i '' -e "s@<user>@www@g" /etc/systemd/system/pteroq.service
    ;;
  esac

  systemctl enable pteroq.service
  systemctl start pteroq

  success "Installed pteroq!"
}

# -------- OS specific install functions ------- #

enable_services() {
  case "$OS" in
  ubuntu | debian)
    systemctl enable redis-server
    systemctl start redis-server
    ;;
  rocky | almalinux | fedora)
    systemctl enable redis
    systemctl start redis
    ;;
  arch | endeavouros)
    systemctl enable redis
    systemctl start redis
    ;;
  artix)
    if command -v rc-service >/dev/null 2>&1; then
      rc-update add redis default
      rc-service redis start
    else
      sv up redis
    fi
    ;;
  gentoo)
    rc-update add redis default
    rc-service redis start
    ;;
  void)
    ln -s /etc/sv/redis /var/service/ 2>/dev/null || true
    ;;
  freebsd)
    sysrc redis_enable="YES"
    service redis start
    ;;
  slackware)
    chmod +x /etc/rc.d/rc.redis 2>/dev/null || true
    /etc/rc.d/rc.redis start 2>/dev/null || true
    ;;
  esac
  
  case "$OS" in
  freebsd)
    sysrc nginx_enable="YES"
    sysrc mysql_enable="YES"
    service mysql-server start
    ;;
  gentoo)
    rc-update add nginx default
    rc-update add mysql default
    rc-service mysql start
    ;;
  void)
    ln -s /etc/sv/nginx /var/service/ 2>/dev/null || true
    ln -s /etc/sv/mysqld /var/service/ 2>/dev/null || true
    ;;
  slackware)
    chmod +x /etc/rc.d/rc.nginx 2>/dev/null || true
    chmod +x /etc/rc.d/rc.mysqld 2>/dev/null || true
    /etc/rc.d/rc.mysqld start 2>/dev/null || true
    ;;
  artix)
    if command -v rc-service >/dev/null 2>&1; then
      rc-update add nginx default
      rc-update add mysql default
      rc-service mysql start
    else
      sv up nginx
      sv up mysqld
    fi
    ;;
  *)
    systemctl enable nginx
    systemctl enable mariadb
    systemctl start mariadb
    ;;
  esac
}

selinux_allow() {
  setsebool -P httpd_can_network_connect 1 || true # these commands can fail OK
  setsebool -P httpd_execmem 1 || true
  setsebool -P httpd_unified 1 || true
}

php_fpm_conf() {
  case "$OS" in
    rocky | almalinux | fedora)
      curl -o /etc/php-fpm.d/www-pterodactyl.conf "$GITHUB_URL"/configs/www-pterodactyl.conf
      systemctl enable php-fpm
      systemctl start php-fpm
      ;;
    arch | endeavouros)
      systemctl enable php-fpm
      systemctl start php-fpm
      ;;
    artix)
      if command -v rc-service >/dev/null 2>&1; then
        rc-update add php-fpm default
        rc-service php-fpm start
      else
        sv up php-fpm
      fi
      ;;
    gentoo)
      rc-update add php-fpm default
      rc-service php-fpm start
      ;;
    void)
      ln -s /etc/sv/php-fpm /var/service/ 2>/dev/null || true
      ;;
    freebsd)
      sysrc php_fpm_enable="YES"
      service php-fpm start
      ;;
    slackware)
      chmod +x /etc/rc.d/rc.php-fpm 2>/dev/null || true
      /etc/rc.d/rc.php-fpm start 2>/dev/null || true
      ;;
  esac
}

ubuntu_dep() {
  # Install deps for adding repos
  install_packages "software-properties-common apt-transport-https ca-certificates gnupg"

  # Add Ubuntu universe repo
  add-apt-repository universe -y

  # Add PPA for PHP (we need 8.3)
  LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
}

debian_dep() {
  # Install deps for adding repos
  install_packages "dirmngr ca-certificates apt-transport-https lsb-release"

  # Install PHP 8.3 using sury's repo
  curl -o /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
  echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list
}

alma_rocky_dep() {
  # SELinux tools
  install_packages "policycoreutils selinux-policy selinux-policy-targeted \
    setroubleshoot-server setools setools-console mcstrans"

  # add remi repo (php8.3)
  install_packages "epel-release http://rpms.remirepo.net/enterprise/remi-release-$OS_VER_MAJOR.rpm"
  dnf module enable -y php:remi-8.3
}

fedora_dep() {
  # add remi repo (php8.3)
  install_packages "https://rpms.remirepo.net/fedora/remi-release-$OS_VER_MAJOR.rpm"
  dnf module reset -y php
  dnf module enable -y php:remi-8.3
}

arch_dep() {
  # Arch uses rolling release, PHP 8.3 should be in repos
  output "Arch Linux detected, using official repositories"
}

gentoo_dep() {
  output "Gentoo detected, using Portage"
  # Gentoo uses USE flags and portage
}

void_dep() {
  output "Void Linux detected, using XBPS"
}

freebsd_dep() {
  output "FreeBSD detected, using pkg"
}

slackware_dep() {
  output "Slackware detected, using slackpkg"
}

dep_install() {
  output "Installing dependencies for $OS $OS_VER..."

  # Update repos before installing
  update_repos

  [ "$CONFIGURE_FIREWALL" == true ] && install_firewall && firewall_ports

  case "$OS" in
  ubuntu | debian)
    [ "$OS" == "ubuntu" ] && ubuntu_dep
    [ "$OS" == "debian" ] && debian_dep

    update_repos

    # Install dependencies
    install_packages "php8.3 php8.3-{cli,common,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip} \
      mariadb-common mariadb-server mariadb-client \
      nginx \
      redis-server \
      zip unzip tar \
      git cron"

    [ "$CONFIGURE_LETSENCRYPT" == true ] && install_packages "certbot python3-certbot-nginx"

    ;;
  rocky | almalinux)
    alma_rocky_dep

    # Install dependencies
    install_packages "php php-{common,fpm,cli,json,mysqlnd,mcrypt,gd,mbstring,pdo,zip,bcmath,dom,opcache,posix} \
      mariadb mariadb-server \
      nginx \
      redis \
      zip unzip tar \
      git cronie"

    [ "$CONFIGURE_LETSENCRYPT" == true ] && install_packages "certbot python3-certbot-nginx"

    # Allow nginx
    selinux_allow

    # Create config for php fpm
    php_fpm_conf
    ;;
  fedora)
    fedora_dep

    install_packages "php php-{common,fpm,cli,json,mysqlnd,gd,mbstring,pdo,zip,bcmath,xml,opcache,posix} \
      mariadb mariadb-server \
      nginx \
      redis \
      zip unzip tar \
      git cronie"

    [ "$CONFIGURE_LETSENCRYPT" == true ] && install_packages "certbot python3-certbot-nginx"

    php_fpm_conf
    ;;
  arch | endeavouros)
    arch_dep

    install_packages "php php-fpm php-gd php-redis \
      mariadb \
      nginx \
      redis \
      zip unzip tar \
      git cronie"

    [ "$CONFIGURE_LETSENCRYPT" == true ] && install_packages "certbot certbot-nginx"

    php_fpm_conf
    ;;
  artix)
    install_packages "php php-fpm php-gd php-redis \
      mariadb \
      nginx \
      redis \
      zip unzip tar \
      git cronie"

    [ "$CONFIGURE_LETSENCRYPT" == true ] && install_packages "certbot certbot-nginx"

    php_fpm_conf
    ;;
  gentoo)
    gentoo_dep

    install_packages "dev-lang/php dev-db/mariadb www-servers/nginx dev-db/redis net-misc/curl app-arch/unzip app-arch/tar dev-vcs/git sys-process/cronie"

    [ "$CONFIGURE_LETSENCRYPT" == true ] && install_packages "app-crypt/certbot app-crypt/certbot-nginx"

    php_fpm_conf
    ;;
  void)
    void_dep

    install_packages "php php-fpm php-gd php-mysql php-redis \
      mariadb \
      nginx \
      redis \
      zip unzip tar \
      git cronie"

    [ "$CONFIGURE_LETSENCRYPT" == true ] && install_packages "certbot python3-certbot-nginx"

    php_fpm_conf
    ;;
  freebsd)
    freebsd_dep

    install_packages "php83 php83-extensions \
      mariadb106-server \
      nginx \
      redis \
      zip unzip tar \
      git"

    [ "$CONFIGURE_LETSENCRYPT" == true ] && install_packages "py39-certbot py39-certbot-nginx"

    php_fpm_conf
    ;;
  slackware)
    slackware_dep

    install_packages "php mariadb nginx redis"

    output "Note: Some packages may need to be installed from SlackBuilds.org"

    php_fpm_conf
    ;;
  esac

  enable_services

  success "Dependencies installed!"
}

# --------------- Other functions -------------- #

firewall_ports() {
  output "Opening ports: 22 (SSH), 80 (HTTP) and 443 (HTTPS)"

  firewall_allow_ports "22 80 443"

  success "Firewall ports opened!"
}

letsencrypt() {
  FAILED=false

  output "Configuring Let's Encrypt..."

  # Obtain certificate
  certbot --nginx --redirect --no-eff-email --email "$email" -d "$FQDN" || FAILED=true

  # Check if it succeded
  if [ ! -d "/etc/letsencrypt/live/$FQDN/" ] || [ "$FAILED" == true ]; then
    warning "The process of obtaining a Let's Encrypt certificate failed!"
    echo -n "* Still assume SSL? (y/N): "
    read -r CONFIGURE_SSL

    if [[ "$CONFIGURE_SSL" =~ [Yy] ]]; then
      ASSUME_SSL=true
      CONFIGURE_LETSENCRYPT=false
      configure_nginx
    else
      ASSUME_SSL=false
      CONFIGURE_LETSENCRYPT=false
    fi
  else
    success "The process of obtaining a Let's Encrypt certificate succeeded!"
  fi
}

# ------ Webserver configuration functions ----- #

configure_nginx() {
  output "Configuring nginx .."

  if [ "$ASSUME_SSL" == true ] && [ "$CONFIGURE_LETSENCRYPT" == false ]; then
    DL_FILE="nginx_ssl.conf"
  else
    DL_FILE="nginx.conf"
  fi

  case "$OS" in
  ubuntu | debian)
    PHP_SOCKET="/run/php/php8.3-fpm.sock"
    CONFIG_PATH_AVAIL="/etc/nginx/sites-available"
    CONFIG_PATH_ENABL="/etc/nginx/sites-enabled"
    ;;
  rocky | almalinux | fedora)
    PHP_SOCKET="/var/run/php-fpm/pterodactyl.sock"
    CONFIG_PATH_AVAIL="/etc/nginx/conf.d"
    CONFIG_PATH_ENABL="$CONFIG_PATH_AVAIL"
    ;;
  arch | endeavouros | artix)
    PHP_SOCKET="/run/php-fpm/php-fpm.sock"
    CONFIG_PATH_AVAIL="/etc/nginx"
    CONFIG_PATH_ENABL="$CONFIG_PATH_AVAIL"
    ;;
  gentoo | void)
    PHP_SOCKET="/run/php-fpm.sock"
    CONFIG_PATH_AVAIL="/etc/nginx"
    CONFIG_PATH_ENABL="$CONFIG_PATH_AVAIL"
    ;;
  freebsd)
    PHP_SOCKET="/var/run/php-fpm.sock"
    CONFIG_PATH_AVAIL="/usr/local/etc/nginx"
    CONFIG_PATH_ENABL="$CONFIG_PATH_AVAIL"
    ;;
  slackware)
    PHP_SOCKET="/var/run/php-fpm.sock"
    CONFIG_PATH_AVAIL="/etc/nginx"
    CONFIG_PATH_ENABL="$CONFIG_PATH_AVAIL"
    ;;
  esac

  rm -rf "$CONFIG_PATH_ENABL"/default 2>/dev/null || true

  curl -o "$CONFIG_PATH_AVAIL"/pterodactyl.conf "$GITHUB_URL"/configs/$DL_FILE

  sed -i -e "s@<domain>@${FQDN}@g" "$CONFIG_PATH_AVAIL"/pterodactyl.conf

  case "$OS" in
  freebsd)
    sed -i '' -e "s@<php_socket>@${PHP_SOCKET}@g" "$CONFIG_PATH_AVAIL"/pterodactyl.conf
    ;;
  *)
    sed -i -e "s@<php_socket>@${PHP_SOCKET}@g" "$CONFIG_PATH_AVAIL"/pterodactyl.conf
    ;;
  esac

  case "$OS" in
  ubuntu | debian)
    ln -sf "$CONFIG_PATH_AVAIL"/pterodactyl.conf "$CONFIG_PATH_ENABL"/pterodactyl.conf
    ;;
  esac

  if [ "$ASSUME_SSL" == false ] && [ "$CONFIGURE_LETSENCRYPT" == false ]; then
    case "$OS" in
    freebsd)
      service nginx restart
      ;;
    gentoo)
      rc-service nginx restart
      ;;
    void)
      sv restart nginx
      ;;
    slackware)
      /etc/rc.d/rc.nginx restart
      ;;
    *)
      systemctl restart nginx
      ;;
    esac
  fi

  success "Nginx configured!"
}

# --------------- Main functions --------------- #

perform_install() {
  output "Starting installation.. this might take a while!"
  dep_install
  install_composer
  ptdl_dl
  install_composer_deps
  create_db_user "$MYSQL_USER" "$MYSQL_PASSWORD"
  create_db "$MYSQL_DB" "$MYSQL_USER"
  configure
  set_folder_permissions
  insert_cronjob
  install_pteroq
  configure_nginx
  [ "$CONFIGURE_LETSENCRYPT" == true ] && letsencrypt

  return 0
}

# ------------------- Install ------------------ #

perform_install
