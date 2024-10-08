resource "aws_cloudwatch_metric_alarm" "primary_rds_cpu" {
  alarm_name          = "${var.primary_rds_id}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors primary RDS cpu utilization"
  alarm_actions       = [var.sns_topic_arn]
  dimensions = {
    DBInstanceIdentifier = var.primary_rds_id
  }
}

resource "aws_cloudwatch_metric_alarm" "secondary_rds_cpu" {
  alarm_name          = "${var.secondary_rds_id}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors secondary RDS cpu utilization"
  alarm_actions       = [var.sns_topic_arn]
  dimensions = {
    DBInstanceIdentifier = var.secondary_rds_id
  }
}

resource "aws_cloudwatch_metric_alarm" "primary_asg_cpu" {
  alarm_name          = "${var.primary_asg_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors primary ASG cpu utilization"
  alarm_actions       = [var.sns_topic_arn]
  dimensions = {
    AutoScalingGroupName = var.primary_asg_name
  }
}

resource "aws_cloudwatch_metric_alarm" "secondary_asg_cpu" {
  alarm_name          = "${var.secondary_asg_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors secondary ASG cpu utilization"
  alarm_actions       = [var.sns_topic_arn]
  dimensions = {
    AutoScalingGroupName = var.secondary_asg_name
  }
}
