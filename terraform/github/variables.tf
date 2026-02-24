variable "github_token" {
  description = "GitHub personal access token with repo + admin:org scopes"
  type        = string
  sensitive   = true
}

variable "github_org" {
  description = "GitHub organisation or username that owns the repositories"
  type        = string
}

# ── Testing environment ──────────────────────────────────────────────────────

# Server
variable "testing_server_host"    {
  type = string
  sensitive = true
}
variable "testing_server_user"    { type = string }
variable "testing_server_ssh_key" {
  type = string
  sensitive = true
}

# Deployment
variable "testing_deploy_dir"  { type = string }
variable "testing_domain"      { type = string }
variable "testing_environment" { type = string }

# SSL
variable "testing_certbot_email" { type = string }

# PostgreSQL
variable "testing_postgres_user"     { type = string }
variable "testing_postgres_password" {
  type = string
  sensitive = true
}
variable "testing_postgres_db"        { type = string }

# Backend
variable "testing_secret_key"        {
  type = string
  sensitive = true
}
variable "testing_admin_email"       { type = string }
variable "testing_admin_password"    {
  type = string
  sensitive = true
}
variable "testing_email_hash_secret" {
  type = string
  sensitive = true
}

# Mail
variable "testing_mail_username"  { type = string }
variable "testing_mail_password"  {
  type = string
  sensitive = true
}
variable "testing_mail_from"      { type = string }
variable "testing_mail_from_name" { type = string }
variable "testing_mail_server"    { type = string }
variable "testing_mail_port"      { type = string }

# Telegram
variable "testing_telegram_token" {
  type = string
  sensitive = true
}
variable "testing_admin_chat_id"  { type = string }
variable "testing_mini_app_url"   { type = string }

# Grafana
variable "testing_grafana_user"     { type = string }
variable "testing_grafana_password" {
  type = string
  sensitive = true
}

# Mobile
variable "testing_api_base_url" { type = string }

# ── Production environment ───────────────────────────────────────────────────

# Server
variable "production_server_host"    {
  type = string
  sensitive = true
}
variable "production_server_user"    { type = string }
variable "production_server_ssh_key" {
  type = string
  sensitive = true
}

# Deployment
variable "production_deploy_dir"  { type = string }
variable "production_domain"      { type = string }
variable "production_environment" { type = string }

# SSL
variable "production_certbot_email" { type = string }

# PostgreSQL
variable "production_postgres_user"     { type = string }
variable "production_postgres_password" {
  type = string
  sensitive = true
}
variable "production_postgres_db"        { type = string }

# Backend
variable "production_secret_key"        {
  type = string
  sensitive = true
}
variable "production_admin_email"       { type = string }
variable "production_admin_password"    {
  type = string
  sensitive = true
}
variable "production_email_hash_secret" {
  type = string
  sensitive = true
}

# Mail
variable "production_mail_username"  { type = string }
variable "production_mail_password"  {
  type = string
  sensitive = true
}
variable "production_mail_from"      { type = string }
variable "production_mail_from_name" { type = string }
variable "production_mail_server"    { type = string }
variable "production_mail_port"      { type = string }

# Telegram
variable "production_telegram_token" {
  type = string
  sensitive = true
}
variable "production_admin_chat_id"  { type = string }
variable "production_mini_app_url"   { type = string }

# Grafana
variable "production_grafana_user"     { type = string }
variable "production_grafana_password" {
  type = string
  sensitive = true
}

# Mobile
variable "production_api_base_url" { type = string }
