terraform {
  required_version = ">= 1.5"  # import blocks require 1.5+

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "github" {
  token = var.github_token
  owner = var.github_org
}
