provider "aws" {
  # Use the reviewed deployment region and local credential profile.
  region  = var.aws_region
  profile = var.aws_profile

  # Reject credentials belonging to another AWS account.
  allowed_account_ids = [var.expected_aws_account_id]

  # Apply common tags to resources that support provider default tags.
  default_tags {
    tags = local.common_tags
  }
}
