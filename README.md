# IU Alumni Infrastructure

Infrastructure configuration for the IU Alumni platform. Manages server provisioning, Docker stack deployment, nginx reverse proxy, monitoring, and CI/CD.

## Architecture

```
nginx (80/443) ─── reverse proxy + SSL (certbot)
├── /           → frontend:3000  (Nuxt 3 SSR)
├── /api/       → backend:8080   (FastAPI)
├── /bot/       → bot:3001       (Express.js - Telegram bot)
├── /minio/     → minio:9001     (MinIO Console)
├── /s3/        → minio:9000     (MinIO S3 API)
├── /portainer/ → portainer:9000 (Docker management)
└── /grafana/   → grafana:3000   (Dashboards)

postgres:5432    (shared instance: iu_alumni_db + bot_db)
loki:3100        (log aggregation)
promtail         (log shipping from containers)
certbot          (automatic SSL renewal)
```

## Environments

| Environment | Domain | Branch |
|-------------|--------|--------|
| Production  | `alumap-prod.escalopa.com` | `main` |
| Testing     | `alumap-test.escalopa.com` | `develop` |

## Quick Start

### 1. Provision servers (first time only)

```bash
cd ansible
ansible-playbook playbooks/setup-server.yml \
  -e "test_server_ip=X.X.X.X prod_server_ip=Y.Y.Y.Y server_user=deploy"
```

### 2. Configure environment

On each server:

```bash
cd /home/deploy/iu-alumni
cp docker/.env.example .env
# Edit .env with actual values
vim .env
```

### 3. Initial deployment

```bash
# Initialize swarm, network, deploy stack
./scripts/deploy.sh init

# Set up SSL (replace with your domain and email)
DOMAIN=alumap-prod.escalopa.com EMAIL=admin@innopolis.university ./scripts/deploy.sh ssl-init
```

### 4. Subsequent deployments

Automatic via GitHub Actions on push to `main`/`develop`, or manually:

```bash
./scripts/deploy.sh deploy
```

## Local Development

Start shared services (PostgreSQL + MinIO):

```bash
cd docker
docker compose -f docker-compose.dev.yml up -d
```

Then run each app separately:

```bash
# Backend
cd ../iu-alumni-backend
docker compose up

# Bot
cd ../iu-alumni-bot
docker compose up

# Frontend (native, not Docker)
cd ../iu-alumni-frontend
pnpm dev
```

## Secrets

### GitHub Repository Secrets (per app repo)

Required in **each** app repository's GitHub Settings > Secrets:

| Secret | Description | Repos |
|--------|-------------|-------|
| `TEST_SERVER_HOST` | Testing server IP address | backend, frontend, bot, infra |
| `PROD_SERVER_HOST` | Production server IP address | backend, frontend, bot, infra |
| `SERVER_USER` | SSH username for deployment | backend, frontend, bot, infra |
| `SERVER_SSH_KEY` | SSH private key for deployment | backend, frontend, bot, infra |

> `GITHUB_TOKEN` is automatically available for GHCR pushes.

#### Mobile-specific secrets (iu-alumni-mobile repo only)

| Secret | Description |
|--------|-------------|
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded release keystore file |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Key alias in keystore |
| `ANDROID_KEY_PASSWORD` | Key password |
| `API_BASE_URL` | Backend API URL (e.g. `https://alumap-prod.escalopa.com/api`) |
| `APP_METRICA_KEY` | Yandex AppMetrica key |
| `WEB_SALT` | Web salt for hashing |
| `RUSTORE_COMPANY_ID` | RuStore developer company ID |
| `RUSTORE_PRIVATE_KEY` | RSA private key (PEM) for RuStore API auth |
| `RUSTORE_KEY_ID` | RuStore API key ID |

To generate the keystore base64 secret:
```bash
base64 -i release.keystore | tr -d '\n'
```

### Server Environment Variables (.env)

Stored in `/home/deploy/iu-alumni/.env` on each server:

| Variable | Description | Where |
|----------|-------------|-------|
| **PostgreSQL** | | |
| `POSTGRES_USER` | DB superuser | Server |
| `POSTGRES_PASSWORD` | DB password | Server |
| `BACKEND_DB` | Backend database name | Server |
| `BOT_DB` | Bot database name | Server |
| **Backend** | | |
| `SECRET_KEY` | JWT signing secret | Server |
| `ADMIN_EMAIL` | Initial admin email | Server |
| `ADMIN_PASSWORD` | Initial admin password | Server |
| `CORS_ORIGINS` | Allowed CORS origins (comma-sep) | Server |
| `EMAIL_HASH_SECRET` | Email hashing secret | Server |
| `ENVIRONMENT` | `DEV` or `PROD` | Server |
| **Email (SMTP)** | | |
| `MAIL_USERNAME` | SMTP username | Server |
| `MAIL_PASSWORD` | SMTP password | Server |
| `MAIL_PORT` | SMTP port | Server |
| `MAIL_SERVER` | SMTP host | Server |
| `MAIL_FROM` | From email | Server |
| `MAIL_FROM_NAME` | From name | Server |
| **Telegram Bot** | | |
| `TELEGRAM_TOKEN` | Bot API token | Server |
| `ADMIN_CHAT_ID` | Admin group chat ID | Server |
| `MINI_APP_URL` | Telegram Mini App URL | Server |
| **MinIO** | | |
| `MINIO_ROOT_USER` | MinIO admin user | Server |
| `MINIO_ROOT_PASSWORD` | MinIO admin password | Server |
| **Grafana** | | |
| `GRAFANA_USER` | Grafana admin user | Server |
| `GRAFANA_PASSWORD` | Grafana admin password | Server |
| **Docker Images** | | |
| `FRONTEND_IMAGE` | Frontend Docker image | Server |
| `BACKEND_IMAGE` | Backend Docker image | Server |
| `BOT_IMAGE` | Bot Docker image | Server |
| `DOMAIN` | Server domain name | Server |

## Directory Structure

```
iu-alumni-infra/
├── ansible/
│   ├── ansible.cfg
│   ├── inventory.yml
│   └── playbooks/
│       ├── setup-server.yml      # Server provisioning
│       └── deploy-stack.yml      # Stack deployment
├── docker/
│   ├── stack.yml                 # Production Docker stack
│   ├── docker-compose.dev.yml    # Local dev services
│   ├── init-databases.sh         # PostgreSQL multi-DB init
│   └── .env.example              # Environment template
├── nginx/
│   ├── app.conf.template         # Full HTTPS nginx config
│   └── app-init.conf.template    # HTTP-only for SSL setup
├── loki/
│   └── loki-config.yml           # Loki log aggregation config
├── promtail/
│   └── promtail-config.yml       # Promtail log shipping config
├── scripts/
│   └── deploy.sh                 # Server deploy helper
└── .github/
    └── workflows/
        └── deploy.yml            # CI/CD for infra changes
```

## Setting Up Telegram Webhook

After deploying, set the Telegram webhook to point to your domain:

```bash
curl -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://alumap-prod.escalopa.com/bot/webhook"}'
```

## SSL Certificate Renewal

Certbot runs automatically in the stack and renews certificates. To manually renew:

```bash
./scripts/deploy.sh ssl-renew
```
