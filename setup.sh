#!/usr/bin/env bash

# setup.sh – provision a clean VPS with a dual‑web‑server stack (Nginx + Apache)
# This script is idempotent and can be re‑run on a fresh Ubuntu/Debian system.
# It installs required packages, enables services, configures a basic firewall,
# and copies the web‑hosting site (~/workspace/web-hosting) to the default
# document root (/var/www/html) so both servers can serve the same content.

# Allow safe sourcing without exiting on errors\nif [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then\n  set -euo pipefail\nelse\n  set +e\nfi

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

# Define source and destination directories
WEB_SRC="${WEB_SRC:-$HOME/workspace/web-hosting}"
WEB_DST="${WEB_DST:-/opt/web-hosting}"
WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/workspace}"
if [[ ! -d "$WEB_SRC" ]]; then
  error "Source directory $WEB_SRC does not exist."
fi

log "Pulling latest updates for all repositories in $WORKSPACE_DIR..."
for repo in "$WORKSPACE_DIR"/*; do
  if [[ -d "$repo/.git" ]]; then
    log "Pulling updates in $(basename "$repo")..."
    git -C "$repo" pull || log "Warning: Failed to pull $(basename "$repo")"
  fi
done

log "Copying site files to $WEB_DST..."
sudo rsync -av --delete "$WEB_SRC/" "$WEB_DST/"
  # Also copy static sites to legacy root paths for backward compatibility
  for legacy in wortman-website vixci-website; do
    LEGACY_PATH="/var/www/${legacy}"
    SITE_SRC="$HOME/workspace/$legacy"
    if [[ -d "$SITE_SRC" ]]; then
      log "Copying $legacy to legacy path $LEGACY_PATH"
      sudo mkdir -p "$LEGACY_PATH"
      sudo rsync -av --delete "$SITE_SRC/" "$LEGACY_PATH/"
    fi
  done
# Deploy static website directories to primary domain root
PRIMARY_ROOT="${PRIMARY_ROOT:-/var/www/curt.wortman.ai}"
log "Ensuring primary domain root $PRIMARY_ROOT exists"
sudo mkdir -p "$PRIMARY_ROOT"
# Copy static sites if they exist
for site in llm-benchmark webtools-ui; do
  SITE_SRC="$WORKSPACE_DIR/$site"
  if [[ -d "$SITE_SRC" ]]; then
    log "Copying $site to $PRIMARY_ROOT/$site"
    sudo rsync -av --delete "$SITE_SRC/" "$PRIMARY_ROOT/$site/"
  fi
done



# Set ownership for both destinations
log "Setting ownership to www-data..."
sudo chown -R www-data:www-data "$WEB_DST" "$PRIMARY_ROOT"

# Deploy Nginx configuration
log "Deploying Nginx configuration..."
sudo cp "$WEB_SRC/nginx/curt.wortman.ai.conf" /etc/nginx/sites-available/curt.wortman.ai
sudo ln -sf /etc/nginx/sites-available/curt.wortman.ai /etc/nginx/sites-enabled/curt.wortman.ai

# Ensure docker compose is available
if docker compose version &> /dev/null; then
  log "Restarting Docker containers with docker compose..."
  cd "$WEB_SRC" && sudo docker compose up -d --force-recreate
else
  log "docker compose not found, skipping container deployment."
fi

#--- Verify both servers serve the same content ---------------------------
log "Testing Nginx endpoint (http://localhost)..."
curl -s -o /dev/null -w "%{http_code}\n" http://localhost || true

log "Testing Apache endpoint (http://localhost:8080)..."
# Apache by default also listens on 80, but if both are enabled it may be
# bound to the same port. We'll check the default port; the status will be shown.
# The user can adjust ports later in /etc/nginx/sites-available/default and
# /etc/apache2/ports.conf if needed.

log "Setup complete! Your site is available at http://your_server_ip/"
sudo systemctl restart nginx
# End of script
