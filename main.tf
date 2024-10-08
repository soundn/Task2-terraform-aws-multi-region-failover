# main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Provider configuration for primary region
provider "aws" {
  alias  = "primary"
  region = var.primary_region
}

# Provider configuration for secondary region
provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
}

# S3 bucket in primary region
module "primary_s3_bucket" {
  source = "./modules/s3"
  providers = {
    aws = aws.primary
  }
  bucket_name = "${var.project_name}-primary-bucket"
}

# S3 bucket in secondary region
module "secondary_s3_bucket" {
  source = "./modules/s3"
  providers = {
    aws = aws.secondary
  }
  bucket_name = "${var.project_name}-secondary-bucket"
}

# Enable replication between S3 buckets
resource "aws_s3_bucket_replication_configuration" "replication" {
  provider = aws.primary
  role     = aws_iam_role.replication.arn
  bucket   = module.primary_s3_bucket.bucket_id

  rule {
    id     = "replication-rule"
    status = "Enabled"

    destination {
      bucket        = module.secondary_s3_bucket.bucket_arn
      storage_class = "STANDARD"
    }
  }
}

# RDS instance in primary region
module "primary_rds" {
  source = "./modules/rds"
  providers = {
    aws = aws.primary
  }
  db_name  = "${var.project_name}-primary-db"
  multi_az = true
}

# RDS instance in secondary region
module "secondary_rds" {
  source = "./modules/rds"
  providers = {
    aws = aws.secondary
  }
  db_name  = "${var.project_name}-secondary-db"
  multi_az = true
}

# EC2 Auto Scaling Group in primary region
module "primary_asg" {
  source = "./modules/asg"
  providers = {
    aws = aws.primary
  }
  asg_name         = "${var.project_name}-primary-asg"
  min_size         = var.asg_min_size
  max_size         = var.asg_max_size
  desired_capacity = var.asg_desired_capacity
}

# EC2 Auto Scaling Group in secondary region
module "secondary_asg" {
  source = "./modules/asg"
  providers = {
    aws = aws.secondary
  }
  asg_name         = "${var.project_name}-secondary-asg"
  min_size         = var.asg_min_size
  max_size         = var.asg_max_size
  desired_capacity = var.asg_desired_capacity
}

# AWS Global Accelerator
resource "aws_globalaccelerator_accelerator" "this" {
  name            = "${var.project_name}-global-accelerator"
  ip_address_type = "IPV4"
  enabled         = true
}

resource "aws_globalaccelerator_listener" "this" {
  accelerator_arn = aws_globalaccelerator_accelerator.this.id
  client_affinity = "SOURCE_IP"
  protocol        = "TCP"

  port_range {
    from_port = 80
    to_port   = 80
  }
}

resource "aws_globalaccelerator_endpoint_group" "primary" {
  listener_arn          = aws_globalaccelerator_listener.this.id
  endpoint_group_region = var.primary_region

  endpoint_configuration {
    endpoint_id = module.primary_asg.asg_arn
    weight      = 100
  }
}

resource "aws_globalaccelerator_endpoint_group" "secondary" {
  listener_arn          = aws_globalaccelerator_listener.this.id
  endpoint_group_region = var.secondary_region

  endpoint_configuration {
    endpoint_id = module.secondary_asg.asg_arn
    weight      = 0
  }
}

# CloudWatch alarms for failover monitoring
module "cloudwatch_alarms" {
  source             = "./modules/cloudwatch"
  primary_rds_id     = module.primary_rds.db_instance_id
  secondary_rds_id   = module.secondary_rds.db_instance_id
  primary_asg_name   = module.primary_asg.asg_name
  secondary_asg_name = module.secondary_asg.asg_name
}

# Outputs
output "global_accelerator_dns_name" {
  value = aws_globalaccelerator_accelerator.this.dns_name
}

output "primary_s3_bucket" {
  value = module.primary_s3_bucket.bucket_id
}

output "secondary_s3_bucket" {
  value = module.secondary_s3_bucket.bucket_id
}

output "primary_rds_endpoint" {
  value = module.primary_rds.db_instance_endpoint
}

output "secondary_rds_endpoint" {
  value = module.secondary_rds.db_instance_endpoint
}