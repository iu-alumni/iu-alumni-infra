variable "github_token" {
  description = "GitHub personal access token with repo + admin:org scopes"
  type        = string
  sensitive   = true
}

variable "github_org" {
  description = "GitHub organisation or username that owns the repositories"
  type        = string
}

# ── Per-environment secrets ──────────────────────────────────────────────────
# Testing environment

variable "testing_server_host" {
  type = string
  sensitive = true
}

variable "testing_server_user" { type = string }
variable "testing_server_ssh_key" {
  type = string
  sensitive = true
}

variable "testing_domain" { type = string }
variable "testing_certbot_email" { type = string }
variable "testing_postgres_password" {
  type = string
  sensitive = true
}

variable "testing_postgres_user" {
  type    = string
  default = "postgres"
}

variable "testing_backend_db" {
  type = string
  default = "alumni_db"
}

variable "testing_secret_key" {
  type = string
  sensitive = true
}

variable "testing_admin_email" { type = string }
variable "testing_admin_password" {
  type = string
  sensitive = true
}

variable "testing_email_hash_secret" {
  type = string
  sensitive = true
}

variable "testing_mail_username" { type = string }
variable "testing_mail_password" {
  type = string
  sensitive = true
}

variable "testing_mail_from" { type = string }
variable "testing_mail_server" {
  type = string
  default = "smtp.gmail.com"
}

variable "testing_mail_port" {
  type = string
  default = "587"
}

variable "testing_telegram_token" {
  type = string
  sensitive = true
}

variable "testing_admin_chat_id" { type = string }

variable "testing_grafana_user" {
  type = string
  default = "admin"
}

variable "testing_grafana_password" {
  type = string
  sensitive = true
}

variable "testing_api_base_url" { type = string }  # for mobile build

# Production environment

variable "production_server_host" {
  type = string
  sensitive = true
}

variable "production_server_user" { type = string }
variable "production_server_ssh_key" {
  type = string
  sensitive = true
}

variable "production_domain" { type = string }
variable "production_certbot_email" { type = string }
variable "production_postgres_password" {
  type = string
  sensitive = true
}

variable "production_postgres_user" {
  type = string
}

variable "production_backend_db" {
  type = string
  default = "alumni_db"
}

variable "production_secret_key" {
  type = string
  sensitive = true
}

variable "production_admin_email" { type = string }
variable "production_admin_password" {
  type = string
  sensitive = true
}

variable "production_email_hash_secret" {
  type = string
  sensitive = true
}

variable "production_mail_username" { type = string }
variable "production_mail_password" {
  type = string
  sensitive = true
}

variable "production_mail_from" { type = string }
variable "production_mail_server" {
  type = string
  default = "smtp.gmail.com"
}

variable "production_mail_port" {
  type = string
  default = "587"
}

variable "production_telegram_token" {
  type = string
  sensitive = true
}

variable "production_admin_chat_id" { type = string }

variable "production_grafana_user" {
  type = string
  default = "admin"
}

variable "production_grafana_password" {
  type = string
  sensitive = true
}

variable "production_api_base_url" { type = string }  # for mobile build
