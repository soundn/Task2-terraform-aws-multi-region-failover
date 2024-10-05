# modules/ec2_autoscaling/main.tf

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

data "aws_ami" "amazon_linux_2" {
  for_each = local.regions

  provider    = aws[each.key]
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_vpc" "app" {
  for_each = local.regions

  provider = aws[each.key]
  cidr_block = each.key == "primary" ? "10.0.0.0/16" : "10.1.0.0/16"

  tags = {
    Name = "app-vpc-${each.value}"
  }
}

resource "aws_subnet" "app" {
  for_each = local.regions

  provider = aws[each.key]
  vpc_id     = aws_vpc.app[each.key].id
  cidr_block = each.key == "primary" ? "10.0.1.0/24" : "10.1.1.0/24"

  tags = {
    Name = "app-subnet-${each.value}"
  }
}

resource "aws_security_group" "app" {
  for_each = local.regions

  provider = aws[each.key]
  name        = "app-sg-${each.value}"
  description = "Security group for app servers"
  vpc_id      = aws_vpc.app[each.key].id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_launch_template" "app" {
  for_each = local.regions

  provider = aws[each.key]
  name     = "app-launch-template-${each.value}"

  image_id      = data.aws_ami.amazon_linux_2[each.key].id
  instance_type = var.instance_type

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.app[each.key].id]
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              echo "Hello from ${each.value} region" > index.html
              nohup python -m SimpleHTTPServer 80 &
              EOF
  )
}

resource "aws_autoscaling_group" "app" {
  for_each = local.regions

  provider = aws[each.key]
  name     = "app-asg-${each.value}"

  vpc_zone_identifier = [aws_subnet.app[each.key].id]
  target_group_arns   = [aws_lb_target_group.app[each.key].arn]

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.min_size

  launch_template {
    id      = aws_launch_template.app[each.key].id
    version = "$Latest"
  }
}

resource "aws_lb" "app" {
  for_each = local.regions

  provider = aws[each.key]
  name     = "app-lb-${each.value}"

  load_balancer_type = "application"
  subnets            = [aws_subnet.app[each.key].id]
  security_groups    = [aws_security_group.app[each.key].id]
}

resource "aws_lb_listener" "app" {
  for_each = local.regions

  provider = aws[each.key]

  load_balancer_arn = aws_lb.app[each.key].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app[each.key].arn
  }
}

resource "aws_lb_target_group" "app" {
  for_each = local.regions

  provider = aws[each.key]
  name     = "app-tg-${each.value}"

  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.app[each.key].id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 10
  }
}

output "primary_lb_arn" {
  value = aws_lb.app["primary"].arn
}

output "secondary_lb_arn" {
  value = aws_lb.app["secondary"].arn
}

variable "primary_region" {
  type = string
}

variable "secondary_region" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "min_size" {
  type = number
}

variable "max_size" {
  type = number
}