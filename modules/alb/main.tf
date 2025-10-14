# Application Load Balancer Module for Frontend Applications
# Requirements: 7.3, 8.1, 8.6

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Security Group for ALB
resource "aws_security_group" "alb_sg" {
  name_prefix = "${var.project_name}-${var.environment}-alb-"
  vpc_id      = var.vpc_id
  description = "Security group for Application Load Balancer"

  # HTTP from API Gateway
  ingress {
    description = "HTTP from API Gateway"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS from anywhere (for direct access if needed)
  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Health check port
  ingress {
    description = "Health check port"
    from_port   = var.health_check_port
    to_port     = var.health_check_port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # All outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-alb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Application Load Balancer
resource "aws_lb" "frontend_alb" {
  name               = "${var.project_name}-${var.environment}-frontend-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection       = var.enable_deletion_protection
  enable_cross_zone_load_balancing = true
  enable_http2                     = true
  idle_timeout                     = var.idle_timeout

  # Security enhancements
  drop_invalid_header_fields = true
  enable_waf_fail_open       = false

  # Access logs
  access_logs {
    bucket  = var.access_logs_bucket
    prefix  = "alb-logs"
    enabled = var.enable_access_logs
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-frontend-alb"
  })
}

# Target Groups for each frontend application
resource "aws_lb_target_group" "frontend_apps" {
  for_each = var.frontend_applications

  name     = "${var.project_name}-${var.environment}-${each.key}-tg"
  port     = each.value.port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  # Health check configuration
  health_check {
    enabled             = true
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    timeout             = var.health_check_timeout
    interval            = var.health_check_interval
    path                = each.value.health_check_path
    matcher             = "200,202"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  # Stickiness configuration
  stickiness {
    type            = "lb_cookie"
    cookie_duration = var.stickiness_duration
    enabled         = var.enable_stickiness
  }

  # Target group attributes
  target_type                   = "ip"
  deregistration_delay          = var.deregistration_delay
  slow_start                    = var.slow_start_duration
  load_balancing_algorithm_type = var.load_balancing_algorithm
  preserve_client_ip            = true
  proxy_protocol_v2             = false

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-${each.key}-tg"
    Application = each.key
  })

  lifecycle {
    create_before_destroy = true
  }
}

# HTTP Listener (redirect to HTTPS if certificate available, otherwise serve directly)
resource "aws_lb_listener" "frontend_http" {
  load_balancer_arn = aws_lb.frontend_alb.arn
  port              = "80"
  protocol          = "HTTP"

  dynamic "default_action" {
    for_each = var.certificate_arn != null ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = var.certificate_arn == null ? [1] : []
    content {
      type = "fixed-response"
      fixed_response {
        content_type = "text/plain"
        message_body = "Not Found"
        status_code  = "404"
      }
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-http-listener"
  })
}

# HTTPS Listener with certificate and security headers (only if certificate provided)
resource "aws_lb_listener" "frontend_https" {
  count = var.certificate_arn != null ? 1 : 0

  load_balancer_arn = aws_lb.frontend_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  # Default action - return 404 for unmatched paths with security headers
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-https-listener"
  })
}

# Security headers rule for all responses (only if HTTPS listener exists)
resource "aws_lb_listener_rule" "security_headers" {
  count = var.certificate_arn != null ? 1 : 0

  listener_arn = aws_lb_listener.frontend_https[0].arn
  priority     = 1

  action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/html"
      message_body = <<-EOF
        <!DOCTYPE html>
        <html>
        <head>
          <meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' https:; connect-src 'self' https:; media-src 'self' https:; object-src 'none'; frame-src 'none';">
          <meta http-equiv="X-Content-Type-Options" content="nosniff">
          <meta http-equiv="X-Frame-Options" content="DENY">
          <meta http-equiv="X-XSS-Protection" content="1; mode=block">
          <meta http-equiv="Strict-Transport-Security" content="max-age=31536000; includeSubDomains; preload">
          <meta http-equiv="Referrer-Policy" content="strict-origin-when-cross-origin">
          <meta http-equiv="Permissions-Policy" content="geolocation=(), microphone=(), camera=()">
        </head>
        <body>
          <h1>Service Unavailable</h1>
          <p>The requested service is currently unavailable.</p>
        </body>
        </html>
      EOF
      status_code  = "503"
    }
  }

  condition {
    path_pattern {
      values = ["/health-check-fail"]
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-security-headers-rule"
  })
}

# Listener Rules for path-based routing (only if HTTPS listener exists)
resource "aws_lb_listener_rule" "frontend_routing" {
  for_each = var.certificate_arn != null ? var.frontend_applications : {}

  listener_arn = aws_lb_listener.frontend_https[0].arn
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_apps[each.key].arn
  }

  condition {
    path_pattern {
      values = ["/${each.key}/*"]
    }
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-${each.key}-rule"
    Application = each.key
  })
}

# Additional listener rules for root paths (only if HTTPS listener exists)
resource "aws_lb_listener_rule" "frontend_root_routing" {
  for_each = var.certificate_arn != null ? var.frontend_applications : {}

  listener_arn = aws_lb_listener.frontend_https[0].arn
  priority     = each.value.priority + 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_apps[each.key].arn
  }

  condition {
    path_pattern {
      values = ["/${each.key}"]
    }
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-${each.key}-root-rule"
    Application = each.key
  })
}

# HTTP Listener Rules for development (when no certificate is provided)
resource "aws_lb_listener_rule" "frontend_http_routing" {
  for_each = var.certificate_arn == null ? var.frontend_applications : {}

  listener_arn = aws_lb_listener.frontend_http.arn
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_apps[each.key].arn
  }

  condition {
    path_pattern {
      values = ["/${each.key}/*"]
    }
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-${each.key}-http-rule"
    Application = each.key
  })
}

# HTTP Listener Rules for root paths (development mode)
resource "aws_lb_listener_rule" "frontend_http_root_routing" {
  for_each = var.certificate_arn == null ? var.frontend_applications : {}

  listener_arn = aws_lb_listener.frontend_http.arn
  priority     = each.value.priority + 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_apps[each.key].arn
  }

  condition {
    path_pattern {
      values = ["/${each.key}"]
    }
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-${each.key}-http-root-rule"
    Application = each.key
  })
}

# Default route to viewer portal for root path
resource "aws_lb_listener_rule" "default_to_viewer" {
  listener_arn = var.certificate_arn != null ? aws_lb_listener.frontend_https[0].arn : aws_lb_listener.frontend_http.arn
  priority     = 1000 # Low priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_apps["viewer-portal"].arn
  }

  condition {
    path_pattern {
      values = ["/"]
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-default-to-viewer"
  })
}

# CloudWatch Log Group for ALB access logs (if using CloudWatch instead of S3)
resource "aws_cloudwatch_log_group" "alb_logs" {
  count = var.enable_cloudwatch_logs ? 1 : 0

  name              = "/aws/alb/${var.project_name}-${var.environment}-frontend"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-alb-logs"
  })
}

# CloudWatch Alarms for ALB monitoring
resource "aws_cloudwatch_metric_alarm" "alb_target_response_time" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-alb-high-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = var.response_time_threshold
  alarm_description   = "This metric monitors ALB target response time"
  alarm_actions       = var.sns_topic_arns
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.frontend_alb.arn_suffix
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-alb-response-time-alarm"
  })
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-alb-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = var.unhealthy_host_threshold
  alarm_description   = "This metric monitors ALB unhealthy host count"
  alarm_actions       = var.sns_topic_arns
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.frontend_alb.arn_suffix
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-alb-unhealthy-hosts-alarm"
  })
}

resource "aws_cloudwatch_metric_alarm" "alb_http_5xx_errors" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.http_5xx_threshold
  alarm_description   = "This metric monitors ALB 5XX errors"
  alarm_actions       = var.sns_topic_arns
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.frontend_alb.arn_suffix
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-alb-5xx-errors-alarm"
  })
}

# WAF Web ACL Association (optional)
resource "aws_wafv2_web_acl_association" "alb_waf" {
  count = var.waf_web_acl_arn != null ? 1 : 0

  resource_arn = aws_lb.frontend_alb.arn
  web_acl_arn  = var.waf_web_acl_arn
}