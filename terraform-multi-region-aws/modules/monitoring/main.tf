# modules/monitoring/main.tf

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.primary, aws.secondary]
    }
  }
}

locals {
  regions = {
    primary   = var.primary_region
    secondary = var.secondary_region
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_failover" {
  for_each = local.regions

  provider            = aws[each.key]
  alarm_name          = "rds-failover-${each.value}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FailoverTime"
  namespace           = "AWS/RDS"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "0"
  alarm_description   = "This metric monitors RDS failover events"
  alarm_actions       = [aws_sns_topic.alerts[each.key].arn]

  dimensions = {
    DBInstanceIdentifier = each.key == "primary" ? "primary-db" : "secondary-db"
  }
}

resource "aws_cloudwatch_metric_alarm" "asg_high_cpu" {
  for_each = local.regions

  provider            = aws[each.key]
  alarm_name          = "asg-high-cpu-${each.value}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors EC2 CPU utilization"
  alarm_actions       = [aws_sns_topic.alerts[each.key].arn]

  dimensions = {
    AutoScalingGroupName = "app-asg-${each.value}"
  }
}

resource "aws_sns_topic" "alerts" {
  for_each = local.regions

  provider = aws[each.key]
  name     = "infrastructure-alerts-${each.value}"
}

resource "aws_sns_topic_subscription" "email" {
  for_each = local.regions

  provider  = aws[each.key]
  topic_arn = aws_sns_topic.alerts[each.key].arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_log_group" "failover_logs" {
  for_each = local.regions

  provider = aws[each.key]
  name     = "/custom/failover-events-${each.value}"
}

resource "aws_cloudwatch_log_metric_filter" "failover_event" {
  for_each = local.regions

  provider        = aws[each.key]
  name            = "failover-event-${each.value}"
  pattern         = "failover"
  log_group_name  = aws_cloudwatch_log_group.failover_logs[each.key].name

  metric_transformation {
    name      = "FailoverEventCount"
    namespace = "CustomMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "failover_event" {
  for_each = local.regions

  provider            = aws[each.key]
  alarm_name          = "failover-event-${each.value}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FailoverEventCount"
  namespace           = "CustomMetrics"
  period              = "60"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors custom failover events"
  alarm_actions       = [aws_sns_topic.alerts[each.key].arn]
}

variable "primary_region" {
  type = string
}

variable "secondary_region" {
  type = string
}

variable "alert_email" {
  type = string
}

variable "global_accelerator_id" {
  type = string
}