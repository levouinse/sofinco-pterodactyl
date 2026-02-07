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

RM_PANEL="${RM_PANEL:-true}"
RM_WINGS="${RM_WINGS:-true}"

# ---------- Uninstallation functions ---------- #

rm_panel_files() {
  output "Removing panel files..."
  rm -rf /var/www/pterodactyl /usr/local/bin/composer
  
  case "$OS" in
  ubuntu | debian)
    [ -L /etc/nginx/sites-enabled/pterodactyl.conf ] && unlink /etc/nginx/sites-enabled/pterodactyl.conf
    [ -f /etc/nginx/sites-available/pterodactyl.conf ] && rm -f /etc/nginx/sites-available/pterodactyl.conf
    [ ! -L /etc/nginx/sites-enabled/default ] && [ -f /etc/nginx/sites-available/default ] && ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
    ;;
  rocky | almalinux | fedora)
    [ -f /etc/nginx/conf.d/pterodactyl.conf ] && rm -f /etc/nginx/conf.d/pterodactyl.conf
    ;;
  arch | endeavouros | artix | gentoo | void | slackware)
    [ -f /etc/nginx/pterodactyl.conf ] && rm -f /etc/nginx/pterodactyl.conf
    ;;
  freebsd)
    [ -f /usr/local/etc/nginx/pterodactyl.conf ] && rm -f /usr/local/etc/nginx/pterodactyl.conf
    ;;
  esac
  
  case "$OS" in
  freebsd)
    service nginx restart 2>/dev/null || true
    ;;
  gentoo)
    rc-service nginx restart 2>/dev/null || true
    ;;
  void)
    sv restart nginx 2>/dev/null || true
    ;;
  slackware)
    /etc/rc.d/rc.nginx restart 2>/dev/null || true
    ;;
  artix)
    if command -v rc-service >/dev/null 2>&1; then
      rc-service nginx restart 2>/dev/null || true
    else
      sv restart nginx 2>/dev/null || true
    fi
    ;;
  *)
    systemctl restart nginx 2>/dev/null || true
    ;;
  esac
  
  success "Removed panel files."
}

rm_docker_containers() {
  output "Removing docker containers and images..."

  docker system prune -a -f

  success "Removed docker containers and images."
}

rm_wings_files() {
  output "Removing wings files..."

  case "$OS" in
  freebsd)
    service wings stop 2>/dev/null || true
    ;;
  gentoo)
    rc-service wings stop 2>/dev/null || true
    ;;
  void)
    sv down wings 2>/dev/null || true
    ;;
  slackware)
    /etc/rc.d/rc.wings stop 2>/dev/null || true
    ;;
  artix)
    if command -v rc-service >/dev/null 2>&1; then
      rc-service wings stop 2>/dev/null || true
    else
      sv down wings 2>/dev/null || true
    fi
    ;;
  *)
    systemctl disable --now wings 2>/dev/null || true
    ;;
  esac
  
  [ -f /etc/systemd/system/wings.service ] && rm -rf /etc/systemd/system/wings.service

  [ -d /etc/pterodactyl ] && rm -rf /etc/pterodactyl
  [ -f /usr/local/bin/wings ] && rm -rf /usr/local/bin/wings
  [ -d /var/lib/pterodactyl ] && rm -rf /var/lib/pterodactyl
  success "Removed wings files."
}

rm_services() {
  output "Removing services..."
  
  case "$OS" in
  freebsd)
    service pteroq stop 2>/dev/null || true
    ;;
  gentoo)
    rc-service pteroq stop 2>/dev/null || true
    ;;
  void)
    sv down pteroq 2>/dev/null || true
    ;;
  slackware)
    /etc/rc.d/rc.pteroq stop 2>/dev/null || true
    ;;
  artix)
    if command -v rc-service >/dev/null 2>&1; then
      rc-service pteroq stop 2>/dev/null || true
    else
      sv down pteroq 2>/dev/null || true
    fi
    ;;
  *)
    systemctl disable --now pteroq 2>/dev/null || true
    ;;
  esac
  
  rm -rf /etc/systemd/system/pteroq.service 2>/dev/null || true
  
  case "$OS" in
  debian | ubuntu)
    systemctl disable --now redis-server 2>/dev/null || true
    ;;
  rocky | almalinux | fedora)
    systemctl disable --now redis 2>/dev/null || true
    systemctl disable --now php-fpm 2>/dev/null || true
    rm -rf /etc/php-fpm.d/www-pterodactyl.conf 2>/dev/null || true
    ;;
  arch | endeavouros)
    systemctl disable --now redis 2>/dev/null || true
    systemctl disable --now php-fpm 2>/dev/null || true
    ;;
  artix)
    if command -v rc-service >/dev/null 2>&1; then
      rc-service redis stop 2>/dev/null || true
      rc-service php-fpm stop 2>/dev/null || true
    else
      sv down redis 2>/dev/null || true
      sv down php-fpm 2>/dev/null || true
    fi
    ;;
  gentoo)
    rc-service redis stop 2>/dev/null || true
    rc-service php-fpm stop 2>/dev/null || true
    ;;
  void)
    sv down redis 2>/dev/null || true
    sv down php-fpm 2>/dev/null || true
    ;;
  freebsd)
    service redis stop 2>/dev/null || true
    service php-fpm stop 2>/dev/null || true
    ;;
  slackware)
    /etc/rc.d/rc.redis stop 2>/dev/null || true
    /etc/rc.d/rc.php-fpm stop 2>/dev/null || true
    ;;
  esac
  
  success "Removed services."
}

rm_cron() {
  output "Removing cron jobs..."
  crontab -l | grep -vF "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1" | crontab -
  success "Removed cron jobs."
}

rm_database() {
  output "Removing database..."
  valid_db=$(mariadb -u root -e "SELECT schema_name FROM information_schema.schemata;" 2>/dev/null | grep -v -E -- 'schema_name|information_schema|performance_schema|mysql')
  if [[ -z "$valid_db" ]]; then
    warning "No valid databases found."
    return
  fi

  warning "Be careful! This database will be deleted!"
  if [[ "$valid_db" == *"panel"* ]]; then
    echo -n "* Database called panel has been detected. Is it the pterodactyl database? (y/N): "
    read -r is_panel
    if [[ "$is_panel" =~ [Yy] ]]; then
      DATABASE=panel
    else
      print_list "$valid_db"
    fi
  else
    print_list "$valid_db"
  fi

  while [ -z "$DATABASE" ] || [[ "$valid_db" != *"$DATABASE"* ]]; do
    echo -n "* Choose the panel database (to skip don't input anything): "
    read -r database_input
    if [[ -n "$database_input" ]]; then
      if [[ "$valid_db" == *"$database_input"* ]]; then
        DATABASE="$database_input"
      else
        warning "Invalid database name. Try again."
      fi
    else
      break
    fi
  done

  if [[ -n "$DATABASE" ]]; then
    mariadb -u root -e "DROP DATABASE $DATABASE;" 2>/dev/null || warning "Failed to drop database $DATABASE."
  else
    output "No database selected, skipping removal."
  fi

  # Exclude usernames User and root (Hope no one uses username User)
  output "Removing database user..."
  valid_users=$(mariadb -u root -e "SELECT user FROM mysql.user;" 2>/dev/null | grep -v -E -- 'user|root')
  if [[ -z "$valid_users" ]]; then
    warning "No valid database users found."
    return
  fi

  warning "Be careful! This user will be deleted!"
  if [[ "$valid_users" == *"pterodactyl"* ]]; then
    echo -n "* User called pterodactyl has been detected. Is it the pterodactyl user? (y/N): "
    read -r is_user
    if [[ "$is_user" =~ [Yy] ]]; then
      DB_USER=pterodactyl
    else
      print_list "$valid_users"
    fi
  else
    print_list "$valid_users"
  fi

  while [ -z "$DB_USER" ] || [[ "$valid_users" != *"$DB_USER"* ]]; do
    echo -n "* Choose the panel user (to skip don't input anything): "
    read -r user_input
    if [[ -n "$user_input" ]]; then
      if [[ "$valid_users" == *"$user_input"* ]]; then
        DB_USER=$user_input
      else
        warning "Invalid username. Try again."
      fi
    else
      break
    fi
  done

  if [[ -n "$DB_USER" ]]; then
    mariadb -u root -e "DROP USER '$DB_USER'@'127.0.0.1';" 2>/dev/null || warning "Failed to drop user $DB_USER."
  else
    output "No user selected, skipping removal."
  fi

  mariadb -u root -e "FLUSH PRIVILEGES;" 2>/dev/null
  success "Removed database and database user (if selected)."
}


# --------------- Main functions --------------- #

perform_uninstall() {
  [ "$RM_PANEL" == true ] && rm_panel_files
  [ "$RM_PANEL" == true ] && rm_cron
  [ "$RM_PANEL" == true ] && rm_database
  [ "$RM_PANEL" == true ] && rm_services
  [ "$RM_WINGS" == true ] && rm_docker_containers
  [ "$RM_WINGS" == true ] && rm_wings_files

  return 0
}

# ------------------ Uninstall ----------------- #

perform_uninstall
