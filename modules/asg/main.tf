resource "aws_launch_template" "this" {
  name_prefix   = "${var.asg_name}-launch-template"
  image_id      = var.ami_id
  instance_type = var.instance_type

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.this.id]
  }
}

resource "aws_autoscaling_group" "this" {
  name                = var.asg_name
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  target_group_arns   = [aws_lb_target_group.this.arn]
  vpc_zone_identifier = var.subnet_ids

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }
}

resource "aws_lb" "this" {
  name               = "${var.asg_name}-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.this.id]
  subnets            = var.subnet_ids
}

resource "aws_lb_target_group" "this" {
  name     = "${var.asg_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
}

resource "aws_security_group" "this" {
  name        = "${var.asg_name}-sg"
  description = "Security group for ASG instances"
  vpc_id      = var.vpc_id

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

output "asg_name" {
  value = aws_autoscaling_group.this.name
}

output "asg_arn" {
  value = aws_autoscaling_group.this.arn
}