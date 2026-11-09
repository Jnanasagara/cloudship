provider "aws" {
  # Use the region and local credential profile defined in variable.tf
  region  = var.aws_region
  profile = var.aws_profile

  # Apply common tags tp resources that support provider default tags
  default_tags {
    tags = local.common_tags
  }
}