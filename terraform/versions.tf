terraform {
  #Allow patch updates within the Terraform 1.17 release series.
  required_version = "~> 1.17.0"

  required_providers {
    #Use HashiCorp's AWS plugin, allowing patch updates within 6.72.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.72.0"
    }
  }
}