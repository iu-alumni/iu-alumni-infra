#!/usr/bin/env bash
# scripts/deploy.sh - Deploy IU Alumni infrastructure stack
#
# Usage:
#   deploy.sh deploy    — Generate configs and deploy/update the stack
#   deploy.sh init-ssl  — Bootstrap SSL certs (called automatically by deploy if needed)
#
# Environment variables (loaded from $DEPLOY_DIR/.env if present):
#   DEPLOY_DIR     Base directory on the server (default: /home/deploy/iu-alumni)
#   DOMAIN         Primary domain (required)
#   CERTBOT_EMAIL  Email for Let's Encrypt notifications (required for SSL)

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

# ── Helpers ─────────────────────────────────────────────────────────────────

ensure_network() {
    if ! docker network ls --format '{{.Name}}' | grep -qx "$NETWORK_NAME"; then
        docker network create --driver overlay --attachable "$NETWORK_NAME"
        log "Created overlay network: $NETWORK_NAME"
    fi
}

# Generate all nginx configs from templates (replaces ${DOMAIN} placeholder)
generate_nginx_config() {
    mkdir -p "$NGINX_CONF_DIR"
    for tpl in app api mobile portainer grafana; do
        sed "s/\${DOMAIN}/$DOMAIN/g" \
            "$REPO_DIR/nginx/${tpl}.conf.template" \
            > "$NGINX_CONF_DIR/${tpl}.conf"
    done
    log "Nginx configs generated for domain: $DOMAIN"
}

# ── SSL bootstrap ────────────────────────────────────────────────────────────

init_ssl() {
    log "Bootstrapping SSL certificates for $DOMAIN and subdomains..."

    mkdir -p "$NGINX_CONF_DIR" "$CERTBOT_CONF_DIR" "$CERTBOT_WWW_DIR"

    ensure_network

    # Deploy nginx with HTTP-only init config so certbot ACME challenge can be served.
    # app-init.conf.template covers all subdomains in one server block.
    sed "s/\${DOMAIN}/$DOMAIN/g" "$REPO_DIR/nginx/app-init.conf.template" \
        > "$NGINX_CONF_DIR/init.conf"
    # Remove any stale HTTPS configs so nginx loads cleanly
    rm -f "$NGINX_CONF_DIR"/*.conf.bak
    for tpl in app api mobile portainer grafana; do
        rm -f "$NGINX_CONF_DIR/${tpl}.conf"
    done

    DEPLOY_DIR="$DEPLOY_DIR" docker stack deploy \
        -c "$REPO_DIR/docker/stack.yml" "$STACK_NAME" --with-registry-auth

    log "Waiting for nginx to start..."
    sleep 15

    # Request one certificate covering all public subdomains (SAN cert)
    docker run --rm \
        -v "$CERTBOT_CONF_DIR:/etc/letsencrypt" \
        -v "$CERTBOT_WWW_DIR:/var/www/certbot" \
        certbot/certbot certonly --webroot \
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

    # Switch to full HTTPS configs and reload nginx
    rm -f "$NGINX_CONF_DIR/init.conf"
    generate_nginx_config
    docker service update --force "${STACK_NAME}_nginx"
    log "Nginx reloaded with HTTPS configs"
}

# ── Main deploy ──────────────────────────────────────────────────────────────

deploy() {
    ensure_network

    if [ ! -d "$CERT_DIR" ]; then
        log "No SSL certificates found — running SSL init first..."
        init_ssl
    else
        generate_nginx_config
    fi

    # Deploy (or update) the full infrastructure stack
    DEPLOY_DIR="$DEPLOY_DIR" docker stack deploy \
        -c "$REPO_DIR/docker/stack.yml" "$STACK_NAME" --with-registry-auth

    log "Infrastructure stack deployed: $STACK_NAME"
}

# ── Entrypoint ───────────────────────────────────────────────────────────────

case "${1:-help}" in
    deploy)   deploy ;;
    init-ssl) init_ssl ;;
    *)
        echo "Usage: $0 {deploy|init-ssl}"
        exit 1
        ;;
esac
