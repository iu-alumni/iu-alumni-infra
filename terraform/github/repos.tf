# ── Repository definitions ───────────────────────────────────────────────────

# ── Repository definitions ───────────────────────────────────────────────────

locals {
  repos = {
    backend  = "iu-alumni-backend"
    frontend = "iu-alumni-frontend"
    mobile   = "iu-alumni-mobile"
    infra    = "iu-alumni-infra"
  }

  # CI check names (job names) that must pass before merging.
  # These match the job IDs in each repo's deploy.yml workflow.
  # Reusable workflows report checks as "{parent-job} / {called-job}".
  required_checks = {
    backend  = ["build-image", "deploy-testing / deploy"]
    frontend = ["build-image", "deploy-testing / deploy"]
    mobile   = ["build-testing", "deploy-testing / deploy"]
    infra    = ["deploy-testing / deploy"]
  }
}

# Import existing repositories so Terraform adopts them instead of trying to
# create them. Safe to re-run — import is a no-op if already in state.
import {
  to = github_repository.repos["backend"]
  id = "iu-alumni-backend"
}
import {
  to = github_repository.repos["frontend"]
  id = "iu-alumni-frontend"
}
import {
  to = github_repository.repos["mobile"]
  id = "iu-alumni-mobile"
}
import {
  to = github_repository.repos["infra"]
  id = "iu-alumni-infra"
}
# Common settings applied to every repo
resource "github_repository" "repos" {
  for_each = local.repos

  name                   = each.value
  visibility             = "public"
  has_issues             = true
  has_projects           = false
  has_wiki               = false
  allow_merge_commit     = false
  allow_squash_merge     = true
  allow_rebase_merge     = false
  squash_merge_commit_title   = "PR_TITLE"
  squash_merge_commit_message = "PR_BODY"
  delete_branch_on_merge = true

  # Prevent accidental deletion via Terraform
  lifecycle {
    prevent_destroy = true
    # Don't overwrite fields managed outside Terraform (description, topics, etc.)
    ignore_changes = [description, topics, homepage_url]
  }
}

# ── Branch protection — main ─────────────────────────────────────────────────

resource "github_branch_protection" "main" {
  for_each = local.repos

  repository_id = github_repository.repos[each.key].node_id
  pattern       = "main"

  required_status_checks {
    strict   = true
    contexts = local.required_checks[each.key]
  }

  required_pull_request_reviews {
    required_approving_review_count  = 0
    dismiss_stale_reviews            = true
    require_code_owner_reviews       = false
    require_last_push_approval       = false
  }

  enforce_admins                  = false
  allows_deletions                = false
  allows_force_pushes             = false
  require_conversation_resolution = true
}


