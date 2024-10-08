variable "primary_rds_id" {
  description = "ID of the primary RDS instance"
  type        = string
}

variable "secondary_rds_id" {
  description = "ID of the secondary RDS instance"
  type        = string
}

variable "primary_asg_name" {
  description = "Name of the primary Auto Scaling Group"
  type        = string
}

variable "secondary_asg_name" {
  description = "Name of the secondary Auto Scaling Group"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic for alarm notifications"
  type        = string
}