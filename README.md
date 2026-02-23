# IU Alumni — Deployment Guide

This is the single source of truth for deploying the full application cluster.

## Architecture

```txt
Internet
  │
  ▼
nginx (ports 80/443)
  ├── {DOMAIN}               → frontend:3000    (Nuxt 3 SSR)
  ├── api.{DOMAIN}           → backend:8080     (FastAPI)
  ├── mobile.{DOMAIN}        → mobile:80        (Flutter web)
  ├── portainer.{DOMAIN}     → portainer:9000   (Docker UI)
  └── grafana.{DOMAIN}       → grafana:3000     (Dashboards)

Internal only (no public route):
  postgres:5432   prometheus
```

All services share a Docker Swarm overlay network (`iu_alumni_network`).
nginx resolves service names via Docker DNS at request time — it starts even if app services are not yet deployed.

## Environments

| Environment | Branch  | GitHub Environment |
|-------------|---------|--------------------|
| Testing     | develop | `testing`          |
| Production  | main    | `production`       |

---

## Initial Deployment (First Time)

### Prerequisites

- A Linux server (Ubuntu 22.04+) accessible via SSH
- DNS A-records pointing all 6 subdomains to the server IP:
  - `{DOMAIN}`, `api.{DOMAIN}`, `mobile.{DOMAIN}`
  - `portainer.{DOMAIN}`, `grafana.{DOMAIN}`
- GitHub repository secrets configured (see [Secrets Reference](#secrets-reference) below)

### Step 1 — Create SSH user on the server (one-time, manual)

```bash
# On the server as root:
adduser deploy
usermod -aG sudo deploy
mkdir -p /home/deploy/.ssh
echo "YOUR_PUBLIC_KEY" >> /home/deploy/.ssh/authorized_keys
chmod 700 /home/deploy/.ssh && chmod 600 /home/deploy/.ssh/authorized_keys
chown -R deploy:deploy /home/deploy/.ssh
```

### Step 2 — Provision server + deploy infrastructure

Trigger the **Setup Server** workflow in `iu-alumni-infra`:

```txt
GitHub → iu-alumni-infra → Actions → Setup Server → Run workflow
Select environment: testing  (or production)
```

This workflow will:

1. Run Ansible to install Docker, configure UFW/Fail2ban, set up directories
2. Write the `.env` file on the server from GitHub secrets (no manual editing needed)
3. Clone the infra repo on the server and run `deploy.sh`:
   - Creates the `iu_alumni_network` overlay network
   - Generates nginx configs from templates
   - Deploys the infra stack (nginx, postgres, portainer, grafana, loki, prometheus)
   - Bootstraps SSL certificates via Let's Encrypt (auto-detected on first run)

### Step 3 — Deploy application services

After the infra stack is running, push or trigger deploys for each app.
These can be done in any order (nginx routes activate as each service comes up):

```txt
# Option A: push to the target branch
git push origin develop   # deploys to testing
git push origin main      # deploys to production

# Option B: manually trigger each workflow
GitHub → {repo} → Actions → Deploy → Run workflow
```

Deploy each service:

- `iu-alumni-backend` → Deploy
- `iu-alumni-frontend` → Deploy
- `iu-alumni-mobile` → Deploy (builds a separate image per environment — see note below)

> **Mobile note:** The Flutter web app bakes `API_BASE_URL` into the binary at compile time.
> Two separate Docker images are built: one for testing (`sha-test` tag), one for production (`sha` tag).
> If you change the domain, you must retrigger a mobile deploy to rebuild with the new URL.

---

## Day-to-Day Deployment

| Action | How |
|--------|-----|
| Deploy backend | Push to `develop` or `main` |
| Deploy frontend | Push to `develop` or `main` |
| Deploy mobile | Push to `develop` or `main` in the mobile repo |
| Redeploy infra | Push changes to `ansible/` or `docker/` in this repo, or trigger manually |
| Update server config | Change a GitHub secret → re-run Setup Server workflow |

---

## Migrating to a New Server

No files need to change. Only update GitHub secrets:

1. Update `SERVER_HOST` (in the target environment: `testing` or `production`)
2. Point DNS to the new server IP
3. Run **Setup Server** workflow → everything is provisioned automatically

If the domain also changes, update `DOMAIN` and `API_BASE_URL` secrets, then redeploy all services.

---

## Secrets Reference

All secrets are set in **GitHub → Settings → Environments** (separate values per `testing` / `production`).

### Infrastructure & SSH (all repos)

| Secret | Description |
|--------|-------------|
| `SERVER_HOST` | Server IP or hostname |
| `SERVER_USER` | SSH username (e.g. `deploy`) |
| `SERVER_SSH_KEY` | SSH private key (PEM) |

### Server Configuration (iu-alumni-infra only)

Written to the server's `.env` by Ansible — no manual file editing needed.

| Secret | Description |
|--------|-------------|
| `DOMAIN` | Base domain, no scheme (e.g. `alumni.example.com`) |
| `CERTBOT_EMAIL` | Email for Let's Encrypt notifications |
| `POSTGRES_PASSWORD` | PostgreSQL superuser password |
| `BACKEND_DB` | Database name (default: `iu_alumni_db`) |
| `SECRET_KEY` | JWT signing secret |
| `ADMIN_EMAIL` | Initial admin account email |
| `ADMIN_PASSWORD` | Initial admin account password |
| `EMAIL_HASH_SECRET` | Secret for hashing emails |
| `MAIL_USERNAME` | SMTP username |
| `MAIL_PASSWORD` | SMTP password |
| `MAIL_FROM` | From address for outbound email |
| `MAIL_SERVER` | SMTP host (default: `smtp.gmail.com`) |
| `MAIL_PORT` | SMTP port (default: `587`) |
| `TELEGRAM_TOKEN` | Telegram bot token |
| `ADMIN_CHAT_ID` | Telegram admin group chat ID |
| `GRAFANA_USER` | Grafana admin username |
| `GRAFANA_PASSWORD` | Grafana admin password |

### Mobile (iu-alumni-mobile only)

| Secret | Description |
|--------|-------------|
| `API_BASE_URL` | Full API URL baked into Flutter binary (e.g. `https://api.alumni.example.com`) |

---

## Local Development

Start shared services (PostgreSQL):

```bash
cd docker
docker compose -f docker-compose.dev.yml up -d
```

Then run each app locally:

```bash
# Backend
cd iu-alumni-backend && docker compose up

# Frontend
cd iu-alumni-frontend && pnpm dev

# Mobile (web)
cd iu-alumni-mobile && flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
```

---

## Repository Structure

```txt
iu-alumni-infra/
├── ansible/
│   ├── ansible.cfg
│   ├── inventory.yml                   # dynamic — all values from CI/CD secrets
│   └── playbooks/
│       ├── setup-server.yml            # provisions server + writes .env
│       └── templates/
│           └── env.j2                  # .env template rendered from secrets
├── docker/
│   ├── stack.yml                       # infra Docker Swarm stack
│   ├── docker-compose.dev.yml          # local dev services
│   ├── init-databases.sh               # postgres multi-db init
│   └── .env.example                    # reference — actual .env written by Ansible
├── nginx/
│   ├── app.conf.template               # {DOMAIN} → frontend
│   ├── api.conf.template               # api.{DOMAIN} → backend
│   ├── mobile.conf.template            # mobile.{DOMAIN} → mobile
│   ├── portainer.conf.template         # portainer.{DOMAIN} → portainer
│   ├── grafana.conf.template           # grafana.{DOMAIN} → grafana
│   └── app-init.conf.template          # HTTP-only config for SSL bootstrap
├── scripts/
│   └── deploy.sh                       # orchestrates nginx + SSL + stack deploy
├── terraform/
│   └── github/                         # GitHub repo settings, branch protection, environments
└── .github/workflows/
    ├── setup-server.yml                # provision server (trigger manually or on ansible changes)
    ├── deploy.yml                      # redeploy infra stack
    └── deploy-app.yml                  # reusable workflow called by all app repos
```
