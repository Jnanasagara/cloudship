variable "aws_region" {
  description = "AWS region assigned to the existing project."
  type        = string
  default     = "ap-southeast-2"

  # Prevent accidentally targetting a region this AWS project does not support
  validation {
    condition     = var.aws_region == "ap-southeast-2"
    error_message = "This AWS project required ap-southeast-2 (Sydney)."
  }
}

variable "aws_profile" {
  description = "Local AWS CLI profile used to authenticate Terraform."
  type        = string
  default     = "cloudship"
}

variable "vps_cidr" {
  description = "IPv4 address range for CloudShip's dedicated VPC"
  type        = string
  default     = "10.42.0.0/16"
  nullable    = false

  # Require a valid IPv4 /16 range for our planned subnet layout
  validation {
    condition     = can(cidrnetmask(var.vps_cidr)) && endswith(var.vps_cidr, "/16")
    error_message = "vpc_cidr must be a valid IPv4 CIDR with a /16 prefix."
  }
}

variable "allowed_client_cidr" {
  description = "Public IPv4 address permitted to access HTTP, expressed as /32"
  type        = string
  nullable    = false

  # Require one explicit IPv4 address, reject broad network ranges
  validation {
    condition     = can(cidrnetmask(var.allowed_client_cidr)) && endswith(var.allowed_client_cidr, "/32")
    error_message = "allowed_client_cidr must be a valid IPv4 address with a /32 prefix."
  }
}

variable "instance_type" {
  description = "Small x86 EC2 instance type for the CloudShip demonstration"
  type        = string
  default     = "t3.micro"
  nullable    = false

  # Keep instance choices compatible with our AMI and deliberately small.
  validation {
    condition     = contains(["t3.micro", "t3.small"], var.instance_type)
    error_message = "Choose t3.micro or t3.small for this demonstration."
  }
}