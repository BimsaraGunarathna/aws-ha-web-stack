output "alb_sg_id" {
  description = "Security group ID for the load balancer."
  value       = aws_security_group.alb.id
}

output "instance_sg_id" {
  description = "Security group ID for the app instances."
  value       = aws_security_group.instance.id
}

output "database_sg_id" {
  description = "Security group ID for the database."
  value       = aws_security_group.database.id
}

# Test-support outputs exposing the underlying security group resources.
output "alb_security_group" {
  description = "ALB security group resource."
  value       = aws_security_group.alb
}

output "instance_security_group" {
  description = "Instance security group resource."
  value       = aws_security_group.instance
}

output "database_security_group" {
  description = "Database security group resource."
  value       = aws_security_group.database
}
