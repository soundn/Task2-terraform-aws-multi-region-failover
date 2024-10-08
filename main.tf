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
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  providers = {
    aws = aws.primary
  }

  bucket = "${var.project_name}-primary-bucket"
  versioning = {
    enabled = true
  }
}

# S3 bucket in secondary region
module "secondary_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  providers = {
    aws = aws.secondary
  }

  bucket = "${var.project_name}-secondary-bucket"
  versioning = {
    enabled = true
  }
}

# IAM role for S3 replication
resource "aws_iam_role" "replication" {
  name = "${var.project_name}-s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for S3 replication
resource "aws_iam_policy" "replication" {
  name = "${var.project_name}-s3-replication-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          module.primary_s3_bucket.s3_bucket_arn
        ]
      },
      {
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Effect = "Allow"
        Resource = [
          "${module.primary_s3_bucket.s3_bucket_arn}/*"
        ]
      },
      {
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Effect   = "Allow"
        Resource = "${module.secondary_s3_bucket.s3_bucket_arn}/*"
      }
    ]
  })
}

# Attach the replication policy to the IAM role
resource "aws_iam_role_policy_attachment" "replication" {
  role       = aws_iam_role.replication.name
  policy_arn = aws_iam_policy.replication.arn
}

# Enable replication between S3 buckets
resource "aws_s3_bucket_replication_configuration" "replication" {
  provider = aws.primary
  role     = aws_iam_role.replication.arn
  bucket   = module.primary_s3_bucket.s3_bucket_id

  rule {
    id     = "replication-rule"
    status = "Enabled"

    destination {
      bucket        = module.secondary_s3_bucket.s3_bucket_arn
      storage_class = "STANDARD"
    }
  }
}

# RDS instance in primary region
# Update the primary RDS module configuration
module "primary_rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 5.0"

  providers = {
    aws = aws.primary
  }

  identifier           = "${var.project_name}-primary-db"
  engine               = "mysql"
  engine_version       = "5.7.38"
  family               = "mysql5.7" # Add this line
  major_engine_version = "5.7"      # Add this line
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  db_name              = replace("${var.project_name}primarydb", "-", "")
  username             = var.db_username
  password             = var.db_password
  multi_az             = true
  skip_final_snapshot  = true

  # Add these lines to create the option group and parameter group
  create_db_option_group    = true
  create_db_parameter_group = true

  # You might also need to specify the subnet group if you're using a VPC
  subnet_ids             = module.primary_vpc.private_subnets
  vpc_security_group_ids = [module.primary_rds_sg.security_group_id]
}

# Update the secondary RDS module configuration
module "secondary_rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 5.0"

  providers = {
    aws = aws.secondary
  }

  identifier           = "${var.project_name}-secondary-db"
  engine               = "mysql"
  engine_version       = "5.7.38"
  family               = "mysql5.7" # Add this line
  major_engine_version = "5.7"      # Add this line
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  db_name              = replace("${var.project_name}secondarydb", "-", "")
  username             = var.db_username
  password             = var.db_password
  multi_az             = true
  skip_final_snapshot  = true

  # Add these lines to create the option group and parameter group
  create_db_option_group    = true
  create_db_parameter_group = true

  # You might also need to specify the subnet group if you're using a VPC
  subnet_ids             = module.secondary_vpc.private_subnets
  vpc_security_group_ids = [module.secondary_rds_sg.security_group_id]
}

# Add security groups for RDS instances
module "primary_rds_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "${var.project_name}-primary-rds-sg"
  description = "Security group for primary RDS instance"
  vpc_id      = module.primary_vpc.vpc_id

  # ingress rule to allow traffic from the primary ASG security group
  ingress_with_source_security_group_id = [
    {
      rule                     = "mysql-tcp"
      source_security_group_id = module.primary_asg_sg.security_group_id
    }
  ]
}

module "secondary_rds_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "${var.project_name}-secondary-rds-sg"
  description = "Security group for secondary RDS instance"
  vpc_id      = module.secondary_vpc.vpc_id

  # ingress rule to allow traffic from the secondary ASG security group
  ingress_with_source_security_group_id = [
    {
      rule                     = "mysql-tcp"
      source_security_group_id = module.secondary_asg_sg.security_group_id
    }
  ]
}

# VPC in primary region
module "primary_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  providers = {
    aws = aws.primary
  }

  name = "${var.project_name}-primary-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.primary_region}a", "${var.primary_region}b", "${var.primary_region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}

# VPC in secondary region
module "secondary_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  providers = {
    aws = aws.secondary
  }

  name = "${var.project_name}-secondary-vpc"
  cidr = "10.1.0.0/16"

  azs             = ["${var.secondary_region}a", "${var.secondary_region}b", "${var.secondary_region}c"]
  private_subnets = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  public_subnets  = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}

# EC2 Auto Scaling Group in primary region
module "primary_asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 6.0"

  providers = {
    aws = aws.primary
  }

  name = "${var.project_name}-primary-asg"

  min_size                  = var.asg_min_size
  max_size                  = var.asg_max_size
  desired_capacity          = var.asg_desired_capacity
  wait_for_capacity_timeout = 0
  health_check_type         = "EC2"
  vpc_zone_identifier       = module.primary_vpc.private_subnets

  instance_type = var.ec2_instance_type
  image_id      = var.ec2_ami_id

  # This will create a launch template
  create_launch_template = true
  launch_template_name   = "${var.project_name}-primary-launch-template"

  # Security group for the instances
  security_groups = [module.primary_asg_sg.security_group_id]
}

# EC2 Auto Scaling Group in secondary region
module "secondary_asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 6.0"

  providers = {
    aws = aws.secondary
  }

  name = "${var.project_name}-secondary-asg"

  min_size                  = var.asg_min_size
  max_size                  = var.asg_max_size
  desired_capacity          = var.asg_desired_capacity
  wait_for_capacity_timeout = 0
  health_check_type         = "EC2"
  vpc_zone_identifier       = module.secondary_vpc.private_subnets

  instance_type = var.ec2_instance_type
  image_id      = var.ec2_ami_id

  # This will create a launch template
  create_launch_template = true
  launch_template_name   = "${var.project_name}-secondary-launch-template"

  # Security group for the instances
  security_groups = [module.secondary_asg_sg.security_group_id]
}

# Security group for primary ASG
module "primary_asg_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  providers = {
    aws = aws.primary
  }

  name        = "${var.project_name}-primary-asg-sg"
  description = "Security group for primary ASG"
  vpc_id      = module.primary_vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "https-443-tcp"]
  egress_rules        = ["all-all"]
}

# Security group for secondary ASG
module "secondary_asg_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  providers = {
    aws = aws.secondary
  }

  name        = "${var.project_name}-secondary-asg-sg"
  description = "Security group for secondary ASG"
  vpc_id      = module.secondary_vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "https-443-tcp"]
  egress_rules        = ["all-all"]
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
    endpoint_id = module.primary_asg.autoscaling_group_id
    weight      = 100
  }
}

resource "aws_globalaccelerator_endpoint_group" "secondary" {
  listener_arn          = aws_globalaccelerator_listener.this.id
  endpoint_group_region = var.secondary_region

  endpoint_configuration {
    endpoint_id = module.secondary_asg.autoscaling_group_id
    weight      = 0
  }
}

# CloudWatch alarms
resource "aws_cloudwatch_metric_alarm" "primary_rds_cpu" {
  provider = aws.primary

  alarm_name          = "${var.project_name}-primary-rds-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors primary RDS cpu utilization"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    DBInstanceIdentifier = module.primary_rds.db_instance_id
  }
}

# CloudWatch alarm for secondary RDS CPU utilization
resource "aws_cloudwatch_metric_alarm" "secondary_rds_cpu" {
  provider = aws.secondary

  alarm_name          = "${var.project_name}-secondary-rds-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors secondary RDS cpu utilization"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    DBInstanceIdentifier = module.secondary_rds.db_instance_id
  }
}

# CloudWatch alarm for primary ASG CPU utilization
resource "aws_cloudwatch_metric_alarm" "primary_asg_cpu" {
  provider = aws.primary

  alarm_name          = "${var.project_name}-primary-asg-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors primary ASG cpu utilization"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    AutoScalingGroupName = module.primary_asg.autoscaling_group_name
  }
}

# CloudWatch alarm for secondary ASG CPU utilization
resource "aws_cloudwatch_metric_alarm" "secondary_asg_cpu" {
  provider = aws.secondary

  alarm_name          = "${var.project_name}-secondary-asg-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors secondary ASG cpu utilization"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    AutoScalingGroupName = module.secondary_asg.autoscaling_group_name
  }
}

# The SNS topic for alarms should remain as is:
resource "aws_sns_topic" "alarms" {
  name = "${var.project_name}-alarms"
}

# Outputs
output "global_accelerator_dns_name" {
  value = aws_globalaccelerator_accelerator.this.dns_name
}

output "primary_s3_bucket" {
  value = module.primary_s3_bucket.s3_bucket_id
}

output "secondary_s3_bucket" {
  value = module.secondary_s3_bucket.s3_bucket_id
}

output "primary_rds_endpoint" {
  value = module.primary_rds.db_instance_endpoint
}

output "secondary_rds_endpoint" {
  value = module.secondary_rds.db_instance_endpoint
}