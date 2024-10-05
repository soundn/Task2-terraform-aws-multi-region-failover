resource "aws_db_instance" "primary" {
  provider                = aws.primary
  identifier              = "primary-db"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  username                = var.db_username
  password                = var.db_password
  db_name                 = var.db_name
  multi_az                = true
  backup_retention_period = 7
  skip_final_snapshot     = true
}

resource "aws_db_instance" "secondary" {
  provider                = aws.secondary
  identifier              = "secondary-db"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  username                = var.db_username
  password                = var.db_password
  db_name                 = var.db_name
  multi_az                = true
  backup_retention_period = 7
  skip_final_snapshot     = true
}

resource "aws_route53_record" "db" {
  provider = aws.primary
  zone_id  = aws_route53_zone.private.zone_id
  name     = "db.example.com"
  type     = "CNAME"
  ttl      = "300"
  records  = [aws_db_instance.primary.endpoint]

  failover_routing_policy {
    type = "PRIMARY"
  }

  set_identifier = "primary"

  health_check_id = aws_route53_health_check.primary.id
}

resource "aws_route53_record" "db_secondary" {
  provider = aws.secondary
  zone_id  = aws_route53_zone.private.zone_id
  name     = "db.example.com"
  type     = "CNAME"
  ttl      = "300"
  records  = [aws_db_instance.secondary.endpoint]

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier = "secondary"

  health_check_id = aws_route53_health_check.secondary.id
}

resource "aws_route53_zone" "private" {
  provider = aws.primary
  name     = "example.com"

  vpc {
    vpc_id = aws_vpc.primary.id
  }
}

resource "aws_route53_health_check" "primary" {
  provider          = aws.primary
  fqdn              = aws_db_instance.primary.endpoint
  port              = 3306
  type              = "TCP"
  resource_path     = "/"
  failure_threshold = "5"
  request_interval  = "30"
}

resource "aws_route53_health_check" "secondary" {
  provider          = aws.secondary
  fqdn              = aws_db_instance.secondary.endpoint
  port              = 3306
  type              = "TCP"
  resource_path     = "/"
  failure_threshold = "5"
  request_interval  = "30"
}