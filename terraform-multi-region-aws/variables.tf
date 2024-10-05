# variables.tf

variable "primary_region" {
  description = "The primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "secondary_region" {
  description = "The secondary AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "db_name" {
  description = "The name of the database"
  type        = string
}

variable "db_username" {
  description = "The username for the database"
  type        = string
}

variable "db_password" {
  description = "The password for the database"
  type        = string
  sensitive   = true
}

variable "instance_type" {
  description = "The instance type for EC2 instances"
  type        = string
  default     = "t3.micro"
}

variable "asg_min_size" {
  description = "The minimum size of the auto scaling group"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "The maximum size of the auto scaling group"
  type        = number
  default     = 3
}

variable "alert_email" {
  description = "The email address to send alerts to"
  type        = string
}