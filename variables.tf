# variables.tf

variable "project_name" {
  description = "Name of the project, used as a prefix for resource names"
  type        = string
}

variable "primary_region" {
  description = "AWS region for primary deployment"
  type        = string
}

variable "secondary_region" {
  description = "AWS region for secondary (failover) deployment"
  type        = string
}

variable "asg_min_size" {
  description = "Minimum size of the Auto Scaling Group"
  type        = number
}

variable "asg_max_size" {
  description = "Maximum size of the Auto Scaling Group"
  type        = number
}

variable "asg_desired_capacity" {
  description = "Desired capacity of the Auto Scaling Group"
  type        = number
}

# Add more variables as needed for your modules
# For example:

variable "db_instance_class" {
  description = "The instance type of the RDS instance"
  type        = string
  default     = "db.t3.micro"
}

variable "db_engine" {
  description = "The database engine to use"
  type        = string
  default     = "mysql"
}

variable "db_engine_version" {
  description = "The engine version to use"
  type        = string
  default     = "5.7"
}

variable "ec2_instance_type" {
  description = "The instance type for EC2 instances in the ASG"
  type        = string
  default     = "t3.micro"
}