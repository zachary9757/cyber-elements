#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/zachary9757/cyber-elements.git}"
SITE_DIR="${SITE_DIR:-/var/www/cyber-elements}"
SITE_NAME="${SITE_NAME:-cyber-elements}"
INCLUDE_WWW="${INCLUDE_WWW:-0}"
DOMAIN="${1:-}"
EMAIL="${2:-}"

usage() {
  cat <<USAGE
Usage:
  ./scripts/deploy-nginx.sh <domain> [email]

Examples:
  ./scripts/deploy-nginx.sh example.com
  ./scripts/deploy-nginx.sh example.com admin@example.com
  INCLUDE_WWW=1 ./scripts/deploy-nginx.sh example.com admin@example.com

Environment:
  REPO_URL      Git repository URL. Default: ${REPO_URL}
  SITE_DIR      Deployment directory. Default: ${SITE_DIR}
  SITE_NAME     Nginx site name. Default: ${SITE_NAME}
  INCLUDE_WWW   Set to 1 to also bind www.<domain>.
USAGE
}

if [[ -z "$DOMAIN" || "$DOMAIN" == "-h" || "$DOMAIN" == "--help" ]]; then
  usage
  exit 1
fi

if [[ "$DOMAIN" == www.* && "$INCLUDE_WWW" == "1" ]]; then
  echo "DOMAIN already starts with www.; set INCLUDE_WWW=0 or pass the apex domain."
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "This script targets Ubuntu/Debian servers with apt-get."
  exit 1
fi

SUDO=""
if [[ "${EUID}" -ne 0 ]]; then
  SUDO="sudo"
fi

SERVER_NAMES="$DOMAIN"
CERT_DOMAINS=(-d "$DOMAIN")
if [[ "$INCLUDE_WWW" == "1" ]]; then
  SERVER_NAMES="$DOMAIN www.$DOMAIN"
  CERT_DOMAINS+=(-d "www.$DOMAIN")
fi

SITE_PARENT="$(dirname "$SITE_DIR")"
NGINX_AVAILABLE="/etc/nginx/sites-available/${SITE_NAME}"
NGINX_ENABLED="/etc/nginx/sites-enabled/${SITE_NAME}"
CERT_PATH="/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
KEY_PATH="/etc/letsencrypt/live/${DOMAIN}/privkey.pem"

run_as_owner() {
  local owner="${SUDO_USER:-$USER}"
  if [[ "${EUID}" -eq 0 && "$owner" != "root" ]]; then
    sudo -u "$owner" "$@"
  else
    "$@"
  fi
}

write_http_config() {
  $SUDO tee "$NGINX_AVAILABLE" >/dev/null <<NGINX
server {
    listen 80;
    listen [::]:80;

    server_name ${SERVER_NAMES};
    root ${SITE_DIR};
    index index.html;

    access_log /var/log/nginx/${SITE_NAME}.access.log;
    error_log /var/log/nginx/${SITE_NAME}.error.log;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location ~* \.(css|js|svg|png|jpg|jpeg|webp|gif|ico|woff2?)$ {
        expires 30d;
        add_header Cache-Control "public, max-age=2592000, immutable";
        try_files \$uri =404;
    }
}
NGINX
}

write_https_config() {
  $SUDO tee "$NGINX_AVAILABLE" >/dev/null <<NGINX
server {
    listen 80;
    listen [::]:80;

    server_name ${SERVER_NAMES};

    location /.well-known/acme-challenge/ {
        root ${SITE_DIR};
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;

    server_name ${SERVER_NAMES};
    root ${SITE_DIR};
    index index.html;

    ssl_certificate ${CERT_PATH};
    ssl_certificate_key ${KEY_PATH};
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;

    access_log /var/log/nginx/${SITE_NAME}.access.log;
    error_log /var/log/nginx/${SITE_NAME}.error.log;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location ~* \.(css|js|svg|png|jpg|jpeg|webp|gif|ico|woff2?)$ {
        expires 30d;
        add_header Cache-Control "public, max-age=2592000, immutable";
        try_files \$uri =404;
    }
}
NGINX
}

echo "Installing required packages..."
$SUDO apt-get update
$SUDO apt-get install -y git nginx

if [[ -n "$EMAIL" ]]; then
  $SUDO apt-get install -y certbot
fi

echo "Preparing site directory: ${SITE_DIR}"
$SUDO mkdir -p "$SITE_PARENT"
if [[ "${EUID}" -ne 0 ]]; then
  $SUDO chown "$USER":"$(id -gn)" "$SITE_PARENT"
fi

if [[ -d "${SITE_DIR}/.git" ]]; then
  echo "Updating repository..."
  run_as_owner git -C "$SITE_DIR" pull --ff-only
else
  echo "Cloning repository..."
  run_as_owner git clone "$REPO_URL" "$SITE_DIR"
fi

echo "Writing Nginx HTTP config..."
write_http_config
$SUDO ln -sfn "$NGINX_AVAILABLE" "$NGINX_ENABLED"
$SUDO nginx -t
$SUDO systemctl reload nginx

if [[ -n "$EMAIL" ]]; then
  echo "Requesting TLS certificate..."
  $SUDO certbot certonly \
    --webroot \
    -w "$SITE_DIR" \
    --non-interactive \
    --agree-tos \
    --email "$EMAIL" \
    "${CERT_DOMAINS[@]}"

  echo "Writing Nginx HTTPS config..."
  write_https_config
  $SUDO nginx -t
  $SUDO systemctl reload nginx
else
  echo "Skipping HTTPS because no email was provided."
fi

echo "Deployment complete:"
if [[ -n "$EMAIL" ]]; then
  echo "  https://${DOMAIN}"
else
  echo "  http://${DOMAIN}"
fi
