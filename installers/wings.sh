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

INSTALL_MARIADB="${INSTALL_MARIADB:-false}"

# firewall
CONFIGURE_FIREWALL="${CONFIGURE_FIREWALL:-false}"

# SSL (Let's Encrypt)
CONFIGURE_LETSENCRYPT="${CONFIGURE_LETSENCRYPT:-false}"
FQDN="${FQDN:-}"
EMAIL="${EMAIL:-}"

# Database host
CONFIGURE_DBHOST="${CONFIGURE_DBHOST:-false}"
CONFIGURE_DB_FIREWALL="${CONFIGURE_DB_FIREWALL:-false}"
MYSQL_DBHOST_HOST="${MYSQL_DBHOST_HOST:-127.0.0.1}"
MYSQL_DBHOST_USER="${MYSQL_DBHOST_USER:-pterodactyluser}"
MYSQL_DBHOST_PASSWORD="${MYSQL_DBHOST_PASSWORD:-}"

if [[ $CONFIGURE_DBHOST == true && -z "${MYSQL_DBHOST_PASSWORD}" ]]; then
  error "Mysql database host user password is required"
  exit 1
fi

# ----------- Installation functions ----------- #

enable_services() {
  [ "$INSTALL_MARIADB" == true ] && case "$OS" in
    freebsd)
      sysrc mysql_enable="YES"
      service mysql-server start
      ;;
    gentoo)
      rc-update add mysql default
      rc-service mysql start
      ;;
    void)
      ln -s /etc/sv/mysqld /var/service/ 2>/dev/null || true
      ;;
    slackware)
      chmod +x /etc/rc.d/rc.mysqld 2>/dev/null || true
      /etc/rc.d/rc.mysqld start 2>/dev/null || true
      ;;
    artix)
      if command -v rc-service >/dev/null 2>&1; then
        rc-update add mysql default
        rc-service mysql start
      else
        sv up mysqld
      fi
      ;;
    *)
      systemctl enable mariadb
      systemctl start mariadb
      ;;
  esac
  
  case "$OS" in
    freebsd)
      sysrc docker_enable="YES"
      service docker start
      ;;
    gentoo)
      rc-update add docker default
      rc-service docker start
      ;;
    void)
      ln -s /etc/sv/docker /var/service/ 2>/dev/null || true
      ;;
    slackware)
      chmod +x /etc/rc.d/rc.docker 2>/dev/null || true
      /etc/rc.d/rc.docker start 2>/dev/null || true
      ;;
    artix)
      if command -v rc-service >/dev/null 2>&1; then
        rc-update add docker default
        rc-service docker start
      else
        sv up docker
      fi
      ;;
    *)
      systemctl start docker
      systemctl enable docker
      ;;
  esac
}

dep_install() {
  output "Installing dependencies for $OS $OS_VER..."

  [ "$CONFIGURE_FIREWALL" == true ] && install_firewall && firewall_ports

  case "$OS" in
  ubuntu | debian)
    install_packages "ca-certificates gnupg lsb-release"

    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null
    ;;

  rocky | almalinux)
    install_packages "dnf-utils"
    dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo

    [ "$CONFIGURE_LETSENCRYPT" == true ] && install_packages "epel-release"

    install_packages "device-mapper-persistent-data lvm2"
    ;;
  
  fedora)
    install_packages "dnf-plugins-core"
    dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    
    [ "$CONFIGURE_LETSENCRYPT" == true ] && install_packages "certbot"
    ;;
  
  arch | endeavouros | artix)
    # Docker is in official repos
    output "Using official repositories for Docker"
    ;;
  
  gentoo)
    output "Installing Docker from Portage"
    ;;
  
  void)
    output "Installing Docker from XBPS"
    ;;
  
  freebsd)
    output "Installing Docker-compatible runtime for FreeBSD"
    ;;
  
  slackware)
    output "Installing Docker from SlackBuilds"
    ;;
  esac

  # Update the new repos
  update_repos

  # Install dependencies
  case "$OS" in
  ubuntu | debian | rocky | almalinux | fedora)
    install_packages "docker-ce docker-ce-cli containerd.io"
    ;;
  arch | endeavouros | artix)
    install_packages "docker"
    ;;
  gentoo)
    install_packages "app-containers/docker"
    ;;
  void)
    install_packages "docker"
    ;;
  freebsd)
    install_packages "docker"
    ;;
  slackware)
    install_packages "docker"
    ;;
  esac

  # Install mariadb if needed
  [ "$INSTALL_MARIADB" == true ] && case "$OS" in
    ubuntu | debian | rocky | almalinux | fedora)
      install_packages "mariadb-server"
      ;;
    arch | endeavouros | artix)
      install_packages "mariadb"
      ;;
    gentoo)
      install_packages "dev-db/mariadb"
      ;;
    void)
      install_packages "mariadb"
      ;;
    freebsd)
      install_packages "mariadb106-server"
      ;;
    slackware)
      install_packages "mariadb"
      ;;
  esac

  [ "$CONFIGURE_LETSENCRYPT" == true ] && install_packages "certbot"

  enable_services

  success "Dependencies installed!"
}

ptdl_dl() {
  echo "* Downloading Pterodactyl Wings.. "

  mkdir -p /etc/pterodactyl
  curl -L -o /usr/local/bin/wings "$WINGS_DL_BASE_URL$ARCH"

  chmod u+x /usr/local/bin/wings

  success "Pterodactyl Wings downloaded successfully"
}

systemd_file() {
  output "Installing systemd service.."

  curl -o /etc/systemd/system/wings.service "$GITHUB_URL"/configs/wings.service
  systemctl daemon-reload
  systemctl enable wings

  success "Installed systemd service!"
}

firewall_ports() {
  output "Opening port 22 (SSH), 8080 (Wings Port), 2022 (Wings SFTP Port)"

  [ "$CONFIGURE_LETSENCRYPT" == true ] && firewall_allow_ports "80 443"
  [ "$CONFIGURE_DB_FIREWALL" == true ] && firewall_allow_ports "3306"

  firewall_allow_ports "22"
  output "Allowed port 22"
  firewall_allow_ports "8080"
  output "Allowed port 8080"
  firewall_allow_ports "2022"
  output "Allowed port 2022"

  success "Firewall ports opened!"
}

letsencrypt() {
  FAILED=false

  output "Configuring LetsEncrypt.."

  # If user has nginx
  systemctl stop nginx || true

  # Obtain certificate
  certbot certonly --no-eff-email --email "$EMAIL" --standalone -d "$FQDN" || FAILED=true

  systemctl start nginx || true

  # Check if it succeded
  if [ ! -d "/etc/letsencrypt/live/$FQDN/" ] || [ "$FAILED" == true ]; then
    warning "The process of obtaining a Let's Encrypt certificate failed!"
  else
    success "The process of obtaining a Let's Encrypt certificate succeeded!"
  fi
}

configure_mysql() {
  output "Configuring MySQL.."

  create_db_user "$MYSQL_DBHOST_USER" "$MYSQL_DBHOST_PASSWORD" "$MYSQL_DBHOST_HOST"
  grant_all_privileges "*" "$MYSQL_DBHOST_USER" "$MYSQL_DBHOST_HOST"

  if [ "$MYSQL_DBHOST_HOST" != "127.0.0.1" ]; then
    echo "* Changing MySQL bind address.."

    case "$OS" in
    debian | ubuntu)
      sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mysql/mariadb.conf.d/50-server.cnf
      systemctl restart mariadb
      ;;
    rocky | almalinux | fedora)
      sed -i 's/^#bind-address=0.0.0.0$/bind-address=0.0.0.0/' /etc/my.cnf.d/mariadb-server.cnf
      systemctl restart mariadb
      ;;
    arch | endeavouros | artix)
      sed -i 's/^#bind-address = 127.0.0.1/bind-address = 0.0.0.0/' /etc/my.cnf.d/server.cnf 2>/dev/null || sed -i 's/^bind-address = 127.0.0.1/bind-address = 0.0.0.0/' /etc/mysql/my.cnf
      systemctl restart mariadb 2>/dev/null || rc-service mysql restart 2>/dev/null || sv restart mysqld
      ;;
    gentoo)
      sed -i 's/^bind-address.*$/bind-address = 0.0.0.0/' /etc/mysql/my.cnf
      rc-service mysql restart
      ;;
    void)
      sed -i 's/^bind-address.*$/bind-address = 0.0.0.0/' /etc/my.cnf
      sv restart mysqld
      ;;
    freebsd)
      echo 'bind-address = 0.0.0.0' >> /usr/local/etc/mysql/my.cnf
      service mysql-server restart
      ;;
    slackware)
      sed -i 's/^bind-address.*$/bind-address = 0.0.0.0/' /etc/my.cnf
      /etc/rc.d/rc.mysqld restart
      ;;
    esac
  fi

  success "MySQL configured!"
}

# --------------- Main functions --------------- #

perform_install() {
  output "Installing pterodactyl wings.."
  dep_install
  ptdl_dl
  systemd_file
  [ "$CONFIGURE_DBHOST" == true ] && configure_mysql
  [ "$CONFIGURE_LETSENCRYPT" == true ] && letsencrypt

  return 0
}

# ---------------- Installation ---------------- #

perform_install
