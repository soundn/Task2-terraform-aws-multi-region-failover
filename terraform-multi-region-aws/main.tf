terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

backend "s3" {
  bucket         = "my-ken-states"
  key            = "multi-region/terraform.tfstate"
  region         = "us-east-1"
  dynamodb_table = "your-terraform-state-lock-table-name"
  encrypt        = true
}

provider "aws" {
  alias  = "primary"
  region = var.primary_region
}

provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
}

module "s3_replication" {
  source = "./modules/s3_replication"

  primary_region   = var.primary_region
  secondary_region = var.secondary_region

  providers = {
    aws.primary   = aws.primary
    aws.secondary = aws.secondary
  }
}

module "rds_failover" {
  source = "./modules/rds_failover"

  primary_region   = var.primary_region
  secondary_region = var.secondary_region
  db_name          = var.db_name
  db_username      = var.db_username
  db_password      = var.db_password

  providers = {
    aws.primary   = aws.primary
    aws.secondary = aws.secondary
  }
}

module "ec2_autoscaling" {
  source = "./modules/ec2_autoscaling"

  primary_region   = var.primary_region
  secondary_region = var.secondary_region
  instance_type    = var.instance_type
  min_size         = var.asg_min_size
  max_size         = var.asg_max_size

  providers = {
    aws.primary   = aws.primary
    aws.secondary = aws.secondary
  }
}

module "global_accelerator" {
  source = "./modules/global_accelerator"

  primary_region   = var.primary_region
  secondary_region = var.secondary_region

  primary_lb_arn   = module.ec2_autoscaling.primary_lb_arn
  secondary_lb_arn = module.ec2_autoscaling.secondary_lb_arn

  providers = {
    aws = aws.primary
  }
}

module "monitoring" {
  source = "./modules/monitoring"

  primary_region        = var.primary_region
  secondary_region      = var.secondary_region
  alert_email           = var.alert_email
  global_accelerator_id = module.global_accelerator.accelerator_id

  providers = {
    aws.primary   = aws.primary
    aws.secondary = aws.secondary
  }
}
