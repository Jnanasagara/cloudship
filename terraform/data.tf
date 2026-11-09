# Read the authenticated AWS identity without creating infrastructure.
# Later, IAM policies can reference its account ID without hardcoding it.

data "aws_caller_identity" "current" {}

# Discover available standard Availability Zones in our configured region
data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }
}

# Look up AWS's current standard Amazon Linux 2023 image for x86-64
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"

  # This public parameter contains an AMI ID, not an encrypted secret
  with_decryption = false
}