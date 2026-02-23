# ── GitHub Environments ──────────────────────────────────────────────────────
#
# "testing"    — auto-deploys on push to develop (no manual gate)
# "production" — requires manual approval before deploy

locals {
  # Repos that need both environments
  app_repos = {
    backend  = "iu-alumni-backend"
    frontend = "iu-alumni-frontend"
    mobile   = "iu-alumni-mobile"
    infra    = "iu-alumni-infra"
  }
}

# testing environment — no reviewers required
resource "github_repository_environment" "testing" {
  for_each    = local.app_repos
  repository  = each.value
  environment = "testing"
  depends_on  = [github_repository.repos]
}

# production environment — requires manual approval
resource "github_repository_environment" "production" {
  for_each    = local.app_repos
  repository  = each.value
  environment = "production"
  depends_on  = [github_repository.repos]

  reviewers {
    # Add GitHub user IDs of required approvers.
    # Find your user ID: https://api.github.com/users/{username}
    # users = [12345678]
    # teams = []
  }

  deployment_branch_policy {
    protected_branches     = true   # only allow deploys from protected branches
    custom_branch_policies = false
  }
}

# ── Shared secrets (SSH / deployment) — all app repos ────────────────────────

resource "github_actions_environment_secret" "testing_server_host" {
  for_each        = local.app_repos
  repository      = each.value
  environment     = github_repository_environment.testing[each.key].environment
  secret_name     = "SERVER_HOST"
  plaintext_value = var.testing_server_host
}

resource "github_actions_environment_secret" "production_server_host" {
  for_each        = local.app_repos
  repository      = each.value
  environment     = github_repository_environment.production[each.key].environment
  secret_name     = "SERVER_HOST"
  plaintext_value = var.production_server_host
}

resource "github_actions_environment_secret" "testing_server_user" {
  for_each        = local.app_repos
  repository      = each.value
  environment     = github_repository_environment.testing[each.key].environment
  secret_name     = "SERVER_USER"
  plaintext_value = var.testing_server_user
}

resource "github_actions_environment_secret" "production_server_user" {
  for_each        = local.app_repos
  repository      = each.value
  environment     = github_repository_environment.production[each.key].environment
  secret_name     = "SERVER_USER"
  plaintext_value = var.production_server_user
}

resource "github_actions_environment_secret" "testing_server_ssh_key" {
  for_each        = local.app_repos
  repository      = each.value
  environment     = github_repository_environment.testing[each.key].environment
  secret_name     = "SERVER_SSH_KEY"
  plaintext_value = var.testing_server_ssh_key
}

resource "github_actions_environment_secret" "production_server_ssh_key" {
  for_each        = local.app_repos
  repository      = each.value
  environment     = github_repository_environment.production[each.key].environment
  secret_name     = "SERVER_SSH_KEY"
  plaintext_value = var.production_server_ssh_key
}

# ── Infra-specific secrets (server configuration) ────────────────────────────

locals {
  infra_testing_secrets = {
    DOMAIN                = var.testing_domain
    CERTBOT_EMAIL         = var.testing_certbot_email
    POSTGRES_PASSWORD     = var.testing_postgres_password
    BACKEND_DB            = var.testing_backend_db
    SECRET_KEY            = var.testing_secret_key
    ADMIN_EMAIL           = var.testing_admin_email
    ADMIN_PASSWORD        = var.testing_admin_password
    EMAIL_HASH_SECRET     = var.testing_email_hash_secret
    MAIL_USERNAME         = var.testing_mail_username
    MAIL_PASSWORD         = var.testing_mail_password
    MAIL_FROM             = var.testing_mail_from
    MAIL_SERVER           = var.testing_mail_server
    MAIL_PORT             = var.testing_mail_port
    TELEGRAM_TOKEN        = var.testing_telegram_token
    ADMIN_CHAT_ID         = var.testing_admin_chat_id
    MINIO_ROOT_USER       = var.testing_minio_root_user
    MINIO_ROOT_PASSWORD   = var.testing_minio_root_password
    GRAFANA_USER          = var.testing_grafana_user
    GRAFANA_PASSWORD      = var.testing_grafana_password
  }

  infra_production_secrets = {
    DOMAIN                = var.production_domain
    CERTBOT_EMAIL         = var.production_certbot_email
    POSTGRES_PASSWORD     = var.production_postgres_password
    BACKEND_DB            = var.production_backend_db
    SECRET_KEY            = var.production_secret_key
    ADMIN_EMAIL           = var.production_admin_email
    ADMIN_PASSWORD        = var.production_admin_password
    EMAIL_HASH_SECRET     = var.production_email_hash_secret
    MAIL_USERNAME         = var.production_mail_username
    MAIL_PASSWORD         = var.production_mail_password
    MAIL_FROM             = var.production_mail_from
    MAIL_SERVER           = var.production_mail_server
    MAIL_PORT             = var.production_mail_port
    TELEGRAM_TOKEN        = var.production_telegram_token
    ADMIN_CHAT_ID         = var.production_admin_chat_id
    MINIO_ROOT_USER       = var.production_minio_root_user
    MINIO_ROOT_PASSWORD   = var.production_minio_root_password
    GRAFANA_USER          = var.production_grafana_user
    GRAFANA_PASSWORD      = var.production_grafana_password
  }
}

resource "github_actions_environment_secret" "infra_testing" {
  for_each        = local.infra_testing_secrets
  repository      = "iu-alumni-infra"
  environment     = github_repository_environment.testing["infra"].environment
  secret_name     = each.key
  plaintext_value = each.value
}

resource "github_actions_environment_secret" "infra_production" {
  for_each        = local.infra_production_secrets
  repository      = "iu-alumni-infra"
  environment     = github_repository_environment.production["infra"].environment
  secret_name     = each.key
  plaintext_value = each.value
}

# ── Mobile-specific: API_BASE_URL (baked into Flutter binary at build time) ──

resource "github_actions_environment_secret" "mobile_api_base_url_testing" {
  repository      = "iu-alumni-mobile"
  environment     = github_repository_environment.testing["mobile"].environment
  secret_name     = "API_BASE_URL"
  plaintext_value = var.testing_api_base_url
}

resource "github_actions_environment_secret" "mobile_api_base_url_production" {
  repository      = "iu-alumni-mobile"
  environment     = github_repository_environment.production["mobile"].environment
  secret_name     = "API_BASE_URL"
  plaintext_value = var.production_api_base_url
}
