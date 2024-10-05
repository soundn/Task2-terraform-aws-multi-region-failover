resource "aws_globalaccelerator_accelerator" "app" {
  name            = "app-accelerator"
  ip_address_type = "IPV4"
  enabled         = true
}

resource "aws_globalaccelerator_listener" "app" {
  accelerator_arn = aws_globalaccelerator_accelerator.app.id
  client_affinity = "SOURCE_IP"
  protocol        = "TCP"

  port_range {
    from_port = 80
    to_port   = 80
  }
}

resource "aws_globalaccelerator_endpoint_group" "primary" {
  listener_arn = aws_globalaccelerator_listener.app.id
  
  endpoint_configuration {
    endpoint_id = var.primary_lb_arn
    weight      = 100
  }

  health_check_path         = "/"
  health_check_port         = 80
  health_check_protocol     = "HTTP"
  threshold_count           = 3
  traffic_dial_percentage   = 100
}

resource "aws_globalaccelerator_endpoint_group" "secondary" {
  listener_arn = aws_globalaccelerator_listener.app.id
  
  endpoint_configuration {
    endpoint_id = var.secondary_lb_arn
    weight      = 100
  }

  health_check_path         = "/"
  health_check_port         = 80
  health_check_protocol     = "HTTP"
  threshold_count           = 3
  traffic_dial_percentage   = 0
}