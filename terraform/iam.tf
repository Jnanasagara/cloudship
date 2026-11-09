# Define an identity that the EC2 service can assume
resource "aws_iam_role" "ec2" {
  name_prefix = "cloudship-dev-ec2-"
  description = "Runtime role for CloudShip's EC2 instance"

  # Trust EC2 to obtain temporary credentials for this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Provide the attachment mechanism between EC2 and the IAM role
resource "aws_iam_instance_profile" "ec2" {
  name_prefix = "cloudship-dev-ec2-"
  role        = aws_iam_role.ec2.name
}

# Attach AWS's core policy for  the SSM agent running on EC2
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Grant log publishing only to streams within CloudShip's log group
resource "aws_iam_role_policy" "app_logs" {
  name = "cloudship-app-logs"
  role = aws_iam_role.ec2.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "PublishCloudShipLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        # Match log streams under this Terraform-managed group only
        Resource = "${aws_cloudwatch_log_group.app.arn}:log-stream:*"
      }
    ]
  })
}