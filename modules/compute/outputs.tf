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
  description = "ALB HTTP redirect listener resource (port 80)."
  value       = aws_lb_listener.http_redirect
}

output "lb_listener_https" {
  description = "ALB HTTPS listener resource (port 443)."
  value       = aws_lb_listener.https
}
