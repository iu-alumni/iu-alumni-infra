#!/usr/bin/env bash
# scripts/deploy.sh - Deploy IU Alumni infrastructure stack
#
# Usage:
#   deploy.sh deploy    — Generate configs and deploy/update the stack
#   deploy.sh init-ssl  — Bootstrap SSL certs (also run automatically when needed)
#
# Environment variables (loaded from $DEPLOY_DIR/.env if present):
#   DEPLOY_DIR           Base directory on the server (default: /home/deploy/iu-alumni)
#   DOMAIN               Primary domain (required)
#   CERTBOT_EMAIL        Email for Let's Encrypt notifications (required when SETUP_CERTIFICATES=true)
#   SETUP_CERTIFICATES   true = obtain certs via certbot and serve HTTPS on this stack
#                        false = HTTP only (TLS terminated upstream by cloud provider)

set -euo pipefail

DEPLOY_DIR="${DEPLOY_DIR:-/home/deploy/iu-alumni}"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$DEPLOY_DIR/.env"
STACK_NAME="iu_alumni_infra"
NETWORK_NAME="iu_alumni_network"

# ── Load environment ────────────────────────────────────────────────────────
if [ -f "$ENV_FILE" ]; then
  # shellcheck source=/dev/null
  set -a && . "$ENV_FILE" && set +a
fi

DOMAIN="${DOMAIN:?DOMAIN must be set in $ENV_FILE}"
CERTBOT_EMAIL="${CERTBOT_EMAIL:-devops@${DOMAIN}}"

NGINX_CONF_DIR="$DEPLOY_DIR/nginx/conf.d"
CERTBOT_CONF_DIR="$DEPLOY_DIR/nginx/certbot/conf"
CERTBOT_WWW_DIR="$DEPLOY_DIR/nginx/certbot/www"
CERT_DIR="$CERTBOT_CONF_DIR/live/$DOMAIN"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

is_ssl_enabled() {
  case "${SETUP_CERTIFICATES:-false}" in
    true | True | TRUE | 1 | yes | Yes | YES) return 0 ;;
    *) return 1 ;;
  esac
}

# ── Helpers ─────────────────────────────────────────────────────────────────

ensure_network() {
  if ! docker network ls --format '{{.Name}}' | grep -qx "$NETWORK_NAME"; then
    docker network create --driver overlay --attachable "$NETWORK_NAME"
    log "Created overlay network: $NETWORK_NAME"
  fi
}

# Generate nginx configs from templates (cloud HTTP-only or local HTTPS).
generate_nginx_config() {
  mkdir -p "$NGINX_CONF_DIR"

  local suffix=""
  if is_ssl_enabled; then
    suffix=".ssl"
  fi

  for tpl in app api mobile portainer grafana; do
    local template="$REPO_DIR/nginx/${tpl}.conf${suffix}.template"
    if [ ! -f "$template" ]; then
      log "ERROR: missing nginx template: $template"
      exit 1
    fi
    sed "s/\${DOMAIN}/$DOMAIN/g" "$template" > "$NGINX_CONF_DIR/${tpl}.conf"
  done

  if is_ssl_enabled; then
    log "Nginx HTTPS configs generated for domain: $DOMAIN"
  else
    log "Nginx HTTP-only configs generated for domain: $DOMAIN (upstream TLS)"
  fi
}

# ── SSL bootstrap ────────────────────────────────────────────────────────────

reload_nginx_service() {
  log "Reloading nginx service to pick up config changes..."
  docker service update --force "${STACK_NAME}_nginx"
  log "Waiting for nginx to become ready..."
  sleep 20
}

verify_acme_webroot() {
  local probe="iu-alumni-acme-probe-$$"
  local probe_dir="$CERTBOT_WWW_DIR/.well-known/acme-challenge"
  mkdir -p "$probe_dir"
  echo "$probe" > "$probe_dir/$probe"

  local url="http://${DOMAIN}/.well-known/acme-challenge/${probe}"
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' "$url" || true)"

  rm -f "$probe_dir/$probe"

  if [ "$code" != "200" ]; then
    log "ERROR: ACME webroot check failed (HTTP $code for $url)"
    log "Let's Encrypt must reach port 80 on this server for /.well-known/acme-challenge/."
    log "If a cloud-provider reverse proxy terminates HTTP/HTTPS in front of this VM:"
    log "  - forward /.well-known/acme-challenge/* to this server unchanged, or"
    log "  - temporarily disable the proxy on port 80, or"
    log "  - run setup with setup_certificates=false and keep TLS at the provider."
    return 1
  fi

  log "ACME webroot check passed (HTTP 200 for $url)"
}

init_ssl() {
  log "Bootstrapping SSL certificates for $DOMAIN and subdomains..."

  mkdir -p "$NGINX_CONF_DIR" "$CERTBOT_CONF_DIR" "$CERTBOT_WWW_DIR"

  ensure_network

  # Deploy nginx with HTTP-only init config so certbot ACME challenge can be served.
  sed "s/\${DOMAIN}/$DOMAIN/g" "$REPO_DIR/nginx/app-init.conf.template" \
    > "$NGINX_CONF_DIR/init.conf"
  rm -f "$NGINX_CONF_DIR"/*.conf.bak
  for tpl in app api mobile portainer grafana; do
    rm -f "$NGINX_CONF_DIR/${tpl}.conf"
  done

  DEPLOY_DIR="$DEPLOY_DIR" docker stack deploy \
    -c "$REPO_DIR/docker/stack.yml" "$STACK_NAME" --with-registry-auth

  # stack deploy alone does not reload nginx when only mounted config files changed.
  reload_nginx_service
  verify_acme_webroot

  docker run --rm \
    -v "$CERTBOT_CONF_DIR:/etc/letsencrypt" \
    -v "$CERTBOT_WWW_DIR:/var/www/certbot" \
    certbot/certbot certonly --webroot --expand \
    --webroot-path /var/www/certbot \
    -d "$DOMAIN" \
    -d "admin.$DOMAIN" \
    -d "api.$DOMAIN" \
    -d "mobile.$DOMAIN" \
    -d "portainer.$DOMAIN" \
    -d "grafana.$DOMAIN" \
    --email "$CERTBOT_EMAIL" \
    --agree-tos --no-eff-email --non-interactive

  log "SSL certificate obtained"

  rm -f "$NGINX_CONF_DIR/init.conf"
  SETUP_CERTIFICATES=true generate_nginx_config
  reload_nginx_service
  log "Nginx reloaded with HTTPS configs"
}

# ── Main deploy ──────────────────────────────────────────────────────────────

deploy() {
  ensure_network

  if is_ssl_enabled; then
    if [ ! -d "$CERT_DIR" ]; then
      log "SETUP_CERTIFICATES=true and no cert found — running SSL init..."
      init_ssl
      return
    fi
    generate_nginx_config
  else
    generate_nginx_config
  fi

  DEPLOY_DIR="$DEPLOY_DIR" docker stack deploy \
    -c "$REPO_DIR/docker/stack.yml" "$STACK_NAME" --with-registry-auth

  log "Infrastructure stack deployed: $STACK_NAME"
}

# ── Entrypoint ───────────────────────────────────────────────────────────────

case "${1:-help}" in
  deploy) deploy ;;
  init-ssl) init_ssl ;;
  *)
    echo "Usage: $0 {deploy|init-ssl}"
    exit 1
    ;;
esac
