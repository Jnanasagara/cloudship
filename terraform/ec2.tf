# Define the application host inside our dedicated subnet
resource "aws_instance" "app" {
  ami           = data.aws_ssm_parameter.al2023_ami.value
  instance_type = var.instance_type

  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.app.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2.name

  # Render the bootstrap script with this deployment's settings
  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    aws_region     = var.aws_region
    log_group_name = aws_cloudwatch_log_group.app.name
  })

  # Bootstrap changes require a fresh instance because setup runs at first boot
  user_data_replace_on_change = true

  # Use a small encrypted root disk and remove it when the instance terminates
  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
    tags                  = local.common_tags
  }

  # Require token-based metadata access for host software using the instance role
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Limit CPU bursting to accrued credits rather than using Unlimited mode
  credit_specification {
    cpu_credits = "standard"
  }

  # Bootstrap needs working internet routing, HTTPS egress and IAM permissions
  depends_on = [
    aws_route.public_internet,
    aws_route_table_association.public,
    aws_vpc_security_group_egress_rule.https,
    aws_iam_role_policy_attachment.ssm,
    aws_iam_role_policy.app_logs
  ]

  tags = {
    Name = "cloudship-dev-app"
  }
}