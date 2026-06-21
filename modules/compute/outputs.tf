output "alb_dns_name" {
  description = "Public DNS name of the load balancer."
  value       = aws_lb.this.dns_name
}

output "asg_name" {
  description = "Name of the Auto Scaling Group."
  value       = aws_autoscaling_group.this.name
}

output "dashboard_name" {
  description = "CloudWatch dashboard name."
  value       = aws_cloudwatch_dashboard.this.dashboard_name
}

# Test-support outputs exposing underlying resources.
output "autoscaling_group" {
  description = "Auto Scaling Group resource."
  value       = aws_autoscaling_group.this
}

output "load_balancer" {
  description = "Load balancer resource."
  value       = aws_lb.this
}

output "target_group" {
  description = "ALB target group resource."
  value       = aws_lb_target_group.this
}

output "lb_listener" {
  description = "ALB port-80 listener resource (redirect when HTTPS is on, forward when off)."
  value       = var.enable_https ? aws_lb_listener.http_redirect[0] : aws_lb_listener.http_forward[0]
}

output "lb_listener_https" {
  description = "ALB HTTPS listener resource (port 443), or null when enable_https = false."
  value       = var.enable_https ? aws_lb_listener.https[0] : null
}
