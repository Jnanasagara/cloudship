# Register GitHub Actions as an OIDC identity provider in this AWS account.
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  # Accept tokens intended for AWS Security Token Service.
  client_id_list = ["sts.amazonaws.com"]

  tags = {
    Name = "cloudship-github-oidc"
  }
}

# Deployment identity for GitHub Actions; separate from our local Terraform access.
resource "aws_iam_role" "github_deploy" {
  name_prefix = "cloudship-dev-github-"
  description = "Deployment role for CloudShip workflows on main."

  # Require GitHub's provider, the AWS audience and our exact repository/branch.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = local.github_oidc_subject
          }
        }
      }
    ]
  })
}

# Allow deployment commands on the CloudShip instance and retrieval of results.
resource "aws_iam_role_policy" "github_deploy" {
  name = "cloudship-deploy-via-ssm"
  role = aws_iam_role.github_deploy.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RunCloudShipDeployment"
        Effect = "Allow"
        Action = "ssm:SendCommand"

        # Permit only this instance and AWS's shell-command document.
        Resource = [
          aws_instance.app.arn,
          "arn:aws:ssm:${var.aws_region}::document/AWS-RunShellScript"
        ]
      },
      {
        Sid    = "ReadCommandResults"
        Effect = "Allow"
        Action = "ssm:GetCommandInvocation"

        # This read action requires "*"; restrict requests to our region.
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      }
    ]
  })
}