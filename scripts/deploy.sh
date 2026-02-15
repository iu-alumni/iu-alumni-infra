#!/bin/bash
# ─────────────────────────────────────────────────────────────
# Deploy script for IU Alumni stack.
# Run on the server: ./deploy.sh [init|deploy|ssl-init|ssl-renew]
# ─────────────────────────────────────────────────────────────

set -euo pipefail

DEPLOY_DIR="/home/deploy/iu-alumni"
STACK_NAME="iu_alumni"

cd "$DEPLOY_DIR"

case "${1:-deploy}" in
  init)
    echo "=== Initializing Docker Swarm and network ==="
    docker swarm init 2>/dev/null || echo "Swarm already initialized"
    docker network create --driver overlay --attachable iu_alumni_network 2>/dev/null || echo "Network already exists"

    echo "=== Making init-databases.sh executable ==="
    chmod +x docker/init-databases.sh

    echo "=== Deploying stack ==="
    docker stack deploy -c docker/stack.yml "$STACK_NAME"
    echo "=== Done! Run './scripts/deploy.sh ssl-init' next to set up SSL ==="
    ;;

  deploy)
    echo "=== Deploying/updating stack ==="
    docker stack deploy -c docker/stack.yml "$STACK_NAME"
    echo "=== Done ==="
    ;;

  ssl-init)
    DOMAIN="${DOMAIN:?Set DOMAIN env var}"
    EMAIL="${EMAIL:?Set EMAIL env var}"

    echo "=== Setting up initial nginx config for certbot ==="
    sed "s/\${DOMAIN}/$DOMAIN/g" nginx/app-init.conf.template > nginx/conf.d/app.conf

    echo "=== Reloading nginx ==="
    docker exec "$(docker ps -q -f name=${STACK_NAME}_nginx)" nginx -s reload || true
    sleep 5

    echo "=== Requesting SSL certificate ==="
    docker exec "$(docker ps -q -f name=${STACK_NAME}_certbot)" \
      certbot certonly --webroot -w /var/www/certbot \
      -d "$DOMAIN" --email "$EMAIL" --agree-tos --no-eff-email

    echo "=== Switching to full HTTPS config ==="
    sed "s/\${DOMAIN}/$DOMAIN/g" nginx/app.conf.template > nginx/conf.d/app.conf

    echo "=== Reloading nginx ==="
    docker exec "$(docker ps -q -f name=${STACK_NAME}_nginx)" nginx -s reload

    echo "=== SSL setup complete for $DOMAIN ==="
    ;;

  ssl-renew)
    echo "=== Renewing SSL certificates ==="
    docker exec "$(docker ps -q -f name=${STACK_NAME}_certbot)" certbot renew
    docker exec "$(docker ps -q -f name=${STACK_NAME}_nginx)" nginx -s reload
    echo "=== Done ==="
    ;;

  *)
    echo "Usage: $0 [init|deploy|ssl-init|ssl-renew]"
    exit 1
    ;;
esac
