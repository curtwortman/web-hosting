# Web Hosting Project Documentation

Welcome to the **Web Hosting** project! This repository contains a premium‑styled static website and a provisioning script that sets up a dual‑web‑server stack (Nginx + Apache) on a clean VPS.

## Table of Contents
- [Overview](#overview)
- [Features](#features)
- [Setup & Installation](#setup--installation)
- [Deployment](#deployment)
- [Architecture](#architecture)
- [FAQ](#faq)
- [License](#license)

## Overview
The `web-hosting` directory holds:
- `index.html` – a modern, glass‑morphism landing page.
- `style.css` – dark‑mode, responsive styling.
- `setup.sh` – a Bash script that installs Nginx, Apache, configures a firewall, and copies the site to `/var/www/html`.

## Features
- **Premium UI** – vibrant colors, smooth micro‑animations, and a dark theme.
- **Dual‑Server Stack** – Nginx as the front‑end proxy (or standalone) and Apache for compatibility with `.htaccess`‑based apps.
- **Idempotent provisioning** – re‑run the script on a fresh VPS without side‑effects.
- **Ready for extension** – add PHP, databases, or custom virtual‑hosts.

## Setup & Installation
1. **Clone the repository**
   ```bash
   git clone https://github.com/curtwortman/web-hosting.git
   cd web-hosting
   ```
2. **Run the provisioning script** (requires sudo)
   ```bash
   sudo ./setup.sh
   ```
   This will:
   - Install `nginx`, `apache2`, `ufw`, `curl`.
   - Enable and start both services.
   - Open necessary firewall ports.
   - Sync the site files to `/var/www/html`.
   - Adjust ownership to `www‑data`.
3. **Verify**
   ```bash
   curl -I http://localhost
   ```
   You should receive a `200 OK` response displaying the landing page.

## Configuration
This project uses environment variables for configuration. A template file `sample.env` is provided in the root directory.

1. **Create a `.env` file**:
   ```bash
   cp sample.env .env
   ```
2. **Update the values**: Open `.env` and fill in the required credentials:
   - `GEMINI_API_KEY`: Your Google Gemini API key.
   - `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET`: OAuth2 credentials for Google login.
   - `FAMILY_EMAILS` / `ADMIN_EMAILS`: Authorized email addresses for access control.
   - `SECRET_KEY`: A secure random string for session signing.

## Deployment
- Both Nginx and Apache serve from the same document root (`/var/www/html`).
- If you need both running simultaneously, adjust Apache to listen on an alternative port (e.g., `8080`) and configure Nginx to proxy specific paths.
- Update `/etc/nginx/sites-enabled/default` or create custom site files under `/etc/nginx/sites-available/` as needed.

## Architecture
```
+-------------------+       +-------------------+       +-------------------+
|   Client Browser  | <---> |      Nginx        | <---> |    Apache          |
+-------------------+       +-------------------+       +-------------------+
        ^   |
        |   v
   HTTPS/HTTP (80/443)
```
- **Nginx**: Handles TLS termination, static asset caching, and can act as a reverse proxy.
- **Apache**: Provides compatibility for `.htaccess` rules, PHP‑FPM, or legacy applications.
- **Filesystem**: `/var/www/html` holds the shared static site files.

## FAQ
**Q:** Can I use only Nginx?
**A:** Yes – simply disable Apache (`sudo systemctl stop apache2 && sudo systemctl disable apache2`).

**Q:** How do I add a custom domain?
**A:** Create a new server block in `/etc/nginx/sites-available/yourdomain` and point `server_name` to your domain, then enable it with `ln -s ..../sites-available/yourdomain /etc/nginx/sites-enabled/` and reload Nginx.

## License
MIT © 2026 Curt Wortman
