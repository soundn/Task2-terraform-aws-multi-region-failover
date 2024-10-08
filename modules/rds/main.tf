resource "aws_db_instance" "this" {
  identifier           = var.db_name
  engine               = var.db_engine
  engine_version       = var.db_engine_version
  instance_class       = var.db_instance_class
  allocated_storage    = 20
  storage_type         = "gp2"
  multi_az             = var.multi_az
  db_name              = replace(var.db_name, "-", "_")
  username             = var.db_username
  password             = var.db_password
  skip_final_snapshot  = true
}

output "db_instance_id" {
  value = aws_db_instance.this.id
}

output "db_instance_endpoint" {
  value = aws_db_instance.this.endpoint
}
