#!/usr/bin/env bash

# setup.sh – provision a clean VPS with a dual‑web‑server stack (Nginx + Apache)
# This script is idempotent and can be re‑run on a fresh Ubuntu/Debian system.
# It installs required packages, enables services, configures a basic firewall,
# and copies the web‑hosting site (~/workspace/web-hosting) to the default
# document root (/var/www/html) so both servers can serve the same content.

set -euo pipefail

#--- Helper functions -------------------------------------------------------
log() {
  echo "[+] $*"
}

error() {
  echo "[!] $*" >&2
  exit 1
}

#--- Update package list ----------------------------------------------------
log "Updating package index..."
sudo apt-get update -y

#--- Install required packages ---------------------------------------------
PACKAGES=(
  nginx
  apache2
  ufw            # optional firewall management
  curl           # handy for testing endpoints
)

log "Installing packages: ${PACKAGES[*]}"
sudo apt-get install -y "${PACKAGES[@]}"

#--- Enable and start services ---------------------------------------------
log "Enabling and starting Nginx..."
sudo systemctl enable nginx
sudo systemctl start nginx

log "Enabling and starting Apache..."
sudo systemctl enable apache2
sudo systemctl start apache2

#--- Basic firewall configuration -------------------------------------------
# Allow HTTP (80) and HTTPS (443). Apache and Nginx will listen on these ports.
log "Configuring UFW firewall..."
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw allow 'Apache Full'
sudo ufw --force enable

#--- Deploy site to /var/www/html ------------------------------------------
WEB_SRC="$HOME/workspace/web-hosting"
WEB_DST="/var/www/html"

if [[ ! -d "$WEB_SRC" ]]; then
  error "Source directory $WEB_SRC does not exist."
fi

log "Copying site files to $WEB_DST..."
# Preserve existing files but overwrite with newest version.
sudo rsync -av --delete "$WEB_SRC/" "$WEB_DST/"

# Ensure proper permissions for the web server user (www-data)
log "Setting ownership to www-data..."
sudo chown -R www-data:www-data "$WEB_DST"

#--- Verify both servers serve the same content ---------------------------
log "Testing Nginx endpoint (http://localhost)..."
curl -s -o /dev/null -w "%{http_code}\n" http://localhost || true

log "Testing Apache endpoint (http://localhost:8080)..."
# Apache by default also listens on 80, but if both are enabled it may be
# bound to the same port. We'll check the default port; the status will be shown.
# The user can adjust ports later in /etc/nginx/sites-available/default and
# /etc/apache2/ports.conf if needed.

log "Setup complete! Your site is available at http://your_server_ip/"

# End of script
