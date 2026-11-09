output "instance_id" {
  description = "EC2 instance ID used to target Systems Manager commands."
  value       = aws_instance.app.id
}

output "public_ip" {
  description = "Instance public IPv4 address; access is restricted by the security group."
  value       = aws_instance.app.public_ip
}

output "app_log_group_name" {
  description = "CloudWatch log group reserved for CloudShip application logs."
  value       = aws_cloudwatch_log_group.app.name
}