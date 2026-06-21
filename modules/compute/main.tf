# IAM role for EC2 instances: SSM access + CloudWatch Logs/Metrics.
resource "aws_iam_role" "instance" {
  name = "${var.project_name}-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.project_name}-instance-profile"
  role = aws_iam_role.instance.name
  tags = var.tags
}

# Latest Amazon Linux 2023 AMI, looked up at plan time so we never pin a stale image.
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = [var.ami_name_pattern]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---- Load balancer ----------------------------------------------------------
#trivy:ignore:AWS-0053 -- Public ALB is the intentional demo entrypoint.
resource "aws_lb" "this" {
  name                       = "${var.project_name}-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [var.alb_sg_id]
  subnets                    = var.public_subnet_ids
  drop_invalid_header_fields = true
  tags                       = merge(var.tags, { Name = "${var.project_name}-alb" })
}

resource "aws_lb_target_group" "this" {
  name        = "${var.project_name}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = var.health_check_path
    protocol            = "HTTP"
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    timeout             = var.health_check_timeout
    interval            = var.health_check_interval
    matcher             = var.health_check_matcher
  }

  tags = merge(var.tags, { Name = "${var.project_name}-tg" })
}

# HTTPS path (enable_https = true): :443 serves the app, :80 redirects to it.
resource "aws_lb_listener" "https" {
  count             = var.enable_https ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  lifecycle {
    precondition {
      condition     = length(var.acm_certificate_arn) > 0
      error_message = "acm_certificate_arn is required when enable_https = true."
    }
  }
}

resource "aws_lb_listener" "http_redirect" {
  count             = var.enable_https ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Plain-HTTP path (enable_https = false): :80 forwards straight to the instances.
# Zero-friction demo with no ACM certificate required.
#trivy:ignore:AWS-0054 -- Plain HTTP is the intentional zero-friction demo default; set enable_https=true for TLS.
resource "aws_lb_listener" "http_forward" {
  count             = var.enable_https ? 0 : 1
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

# ---- Launch template + Auto Scaling Group -----------------------------------
resource "aws_launch_template" "this" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.instance_type
  user_data     = base64encode(file("${path.module}/user_data.sh"))
  iam_instance_profile {
    name = aws_iam_instance_profile.instance.name
  }

  vpc_security_group_ids = [var.instance_sg_id]

  # Enforce IMDSv2 (token-based metadata) -- blocks the SSRF class of attacks.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.project_name}-instance" })
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "this" {
  name                      = "${var.project_name}-asg"
  vpc_zone_identifier       = var.private_subnet_ids
  target_group_arns         = [aws_lb_target_group.this.arn]
  health_check_type         = "ELB"
  health_check_grace_period = var.health_check_grace_period

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  # Replace instances one at a time when the launch template changes.
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = var.instance_refresh_min_healthy_percentage
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg"
    propagate_at_launch = true
  }
}

# Target-tracking scaling: AWS manages the CloudWatch alarms to hold average CPU
# at the target. Simpler and more robust than hand-rolled step scaling.
resource "aws_autoscaling_policy" "cpu" {
  name                   = "${var.project_name}-cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_target
  }
}

# ---- Monitoring (bonus) -----------------------------------------------------
# Alarm if the ALB sees sustained 5xx errors, and a dashboard for quick eyeballing.
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.project_name}-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = var.alb_5xx_alarm_threshold
  alarm_description   = "Target 5xx responses exceeded threshold."
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.this.arn_suffix
  }

  tags = var.tags
}

resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = "${var.project_name}-dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "ASG Average CPU"
          region  = data.aws_region.current.name
          metrics = [["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.this.name]]
          period  = 60
          stat    = "Average"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "ALB Request Count"
          region  = data.aws_region.current.name
          metrics = [["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.this.arn_suffix]]
          period  = 60
          stat    = "Sum"
        }
      }
    ]
  })
}

data "aws_region" "current" {}
