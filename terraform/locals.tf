locals {
  common_tags = {
    Project     = "CloudShip"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

locals {
  # Exact GitHub OIDC identity permitted to request the deployment role.
  github_oidc_subject = "repo:Jnanasagara@152164967/cloudship@1436167206:ref:refs/heads/main"
}