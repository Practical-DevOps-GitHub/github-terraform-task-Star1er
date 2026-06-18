terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "github" {
  token = var.github_token
  owner = var.github_owner
}

variable "github_token" {
  type        = string
  sensitive   = true
  description = "GitHub token with permissions to manage repository settings, secrets, branches and deploy keys."
}

variable "github_owner" {
  type        = string
  description = "GitHub username or organization owner."

  default = "Star1er"
}

variable "repository" {
  type        = string
  description = "Target GitHub repository name."

  default = "github-terraform-task-Star1er"
}

variable "pat" {
  type        = string
  sensitive   = true
  description = "Personal Access Token that will be saved as GitHub Actions secret PAT."
}

variable "deploy_key" {
  type        = string
  sensitive   = true
  description = "Public SSH deploy key."
}

variable "discord_webhook_url" {
  type        = string
  sensitive   = true
  description = "Discord webhook URL for pull request notifications."
}

data "github_repository" "target" {
  full_name = "${var.github_owner}/${var.repository}"
}

resource "github_repository_collaborator" "softservedata" {
  repository = var.repository
  username   = "softservedata"
  permission = "push"
}

resource "github_branch" "develop" {
  repository    = var.repository
  branch        = "develop"
  source_branch = "main"
}

resource "github_repository_file" "codeowners" {
  repository          = var.repository
  branch              = "main"
  file                = ".github/CODEOWNERS"
  content             = "* @softservedata\n"
  commit_message      = "Add CODEOWNERS"
  overwrite_on_create = true
}

resource "github_repository_file" "pull_request_template" {
  repository = var.repository
  branch     = "main"
  file       = ".github/pull_request_template.md"

  content = <<-EOT
  ## Describe your changes

  ## Issue ticket number and link

  ## Checklist before requesting a review

  - [ ] I have performed a self-review of my code
  - [ ] If it is a core feature, I have added thorough tests
  - [ ] Do we need to implement analytics?
  - [ ] Will this be part of a product update? If yes, please write one phrase about this update
  EOT

  commit_message      = "Add pull request template"
  overwrite_on_create = true
}

resource "github_branch_default" "develop" {
  repository = var.repository
  branch     = github_branch.develop.branch
}

resource "github_branch_protection" "main" {
  repository_id = data.github_repository.target.node_id
  pattern       = "main"

  enforce_admins = false

  allows_deletions    = false
  allows_force_pushes = false

  required_pull_request_reviews {
    required_approving_review_count = 0
    require_code_owner_reviews      = true
  }

  depends_on = [
    github_repository_file.codeowners
  ]
}

resource "github_branch_protection" "develop" {
  repository_id = data.github_repository.target.node_id
  pattern       = "develop"

  enforce_admins = false

  allows_deletions    = false
  allows_force_pushes = false

  required_pull_request_reviews {
    required_approving_review_count = 2
    require_code_owner_reviews      = false
  }

  depends_on = [
    github_branch.develop
  ]
}

resource "github_actions_secret" "pat" {
  repository  = var.repository
  secret_name = "PAT"
  value       = var.pat
}

resource "github_repository_deploy_key" "deploy_key" {
  repository = var.repository
  title      = "DEPLOY_KEY"
  key        = var.deploy_key
  read_only  = true
}

resource "github_repository_webhook" "discord_pull_request" {
  repository = var.repository

  configuration {
    url          = var.discord_webhook_url
    content_type = "json"
    insecure_ssl = false
  }

  active = true
  events = [
    "pull_request"
  ]
}
resource "github_actions_secret" "terraform" {
  repository  = var.repository
  secret_name = "TERRAFORM"
  value       = file("${path.module}/main.tf")
}
