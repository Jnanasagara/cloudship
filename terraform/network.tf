# Define a separate network for CloudShip rather than modifying the default VPC.
resource "aws_vpc" "main" {
  cidr_block = var.vps_cidr

  # Enable AWS DNS resolution and instance DNS hostname support
  enable_dns_support   = true
  enable_dns_hostnames = true

  # The provider adds our Project, Environment and ManagedBy tags
  tags = {
    Name = "cloudship-dev-vpc"
  }
}

# Reserve a subnet for the EC2 instance and its eventual internet route.
resource "aws_subnet" "public" {
  vpc_id = aws_vpc.main.id

  # Extend the VPC's /16 by 8 bits, select subnet number 1
  cidr_block = cidrsubnet(var.vps_cidr, 8, 1)

  # Sort the discovered names and select one zone consistently
  availability_zone = sort(data.aws_availability_zones.available.names)[0]

  # Assign the EC2 instance's public IP explicitly later
  map_public_ip_on_launch = false

  tags = {
    Name = "cloudship-dev-public-subnet"
  }
}

# Attach an internet gateway to CloudShip's VPC
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "cloudship-dev-igw"
  }
}

# Create a dedicated route table for the public subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "cloudship-dev-public-routes"
  }
}

# Send IPv4 traffic without a more specific route toward the internet gateway
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

# Make our subnet use this route table
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}