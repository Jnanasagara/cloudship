# Define the network-access boundary for the EC2 instance
resource "aws_security_group" "app" {
  name_prefix = "cloudship-dev-app-"
  description = "Client-restricted HTTP and outbound HTTPS"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "cloudship-dev-app"
  }
}

# Permit HTTP only from the explicitly configured client IPv4 address
resource "aws_vpc_security_group_ingress_rule" "http_from_client" {
  security_group_id = aws_security_group.app.id
  description       = "HTTP from the approved client"

  cidr_ipv4   = var.allowed_client_cidr
  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
}

# Permit HTTPS connections to package repositories, registries and AWS services
resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.app.id
  description       = "Outbound HTTPS for downloads and AWS services"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
}