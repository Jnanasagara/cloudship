# Store application log streams under a dedicated CloudSHip log group
resource "aws_cloudwatch_log_group" "app" {
  name = "/cloudship/dev/app"

  # Expire older events rather than retaining logs indefinitely
  retention_in_days = 7
}

# Detect sustained high CPU using EC2's basic five-minute monitoring.
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name        = "cloudship-dev-cpu-high"
  alarm_description = "Average CPU is at least 80% for two evaluation periods."

  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  datapoints_to_alarm = 2

  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 80

  # Missing measurements should not be interpreted as healthy measurements.
  treat_missing_data = "missing"

  dimensions = {
    InstanceId = aws_instance.app.id
  }
}

# Detect failed EC2 system or instance status checks.
resource "aws_cloudwatch_metric_alarm" "status_check_failed" {
  alarm_name        = "cloudship-dev-status-check-failed"
  alarm_description = "EC2 status checks fail for two evaluation periods."

  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  datapoints_to_alarm = 2

  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1

  treat_missing_data = "missing"

  dimensions = {
    InstanceId = aws_instance.app.id
  }
}