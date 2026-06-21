output "load_balancer_url" {
  description = "Public URL of the application."
  value       = "http://${module.compute.alb_dns_name}"
}

output "load_balancer_dns" {
  description = "Raw ALB DNS name."
  value       = module.compute.alb_dns_name
}

output "database_endpoint" {
  description = "Database connection endpoint (host:port)."
  value       = module.database.db_endpoint
}

output "database_name" {
  description = "Initial database name."
  value       = module.database.db_name
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group."
  value       = module.compute.asg_name
}

output "cloudwatch_dashboard" {
  description = "CloudWatch dashboard name."
  value       = module.compute.dashboard_name
}

output "vpc_id" {
  description = "VPC ID."
  value       = module.network.vpc_id
}
