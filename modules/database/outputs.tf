output "db_endpoint" {
  description = "Connection endpoint (host:port) for the database."
  value       = aws_db_instance.this.endpoint
}

output "db_address" {
  description = "Hostname of the database."
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "Port the database listens on."
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Initial database name."
  value       = aws_db_instance.this.db_name
}

# Test-support output exposing the underlying DB instance resource.
output "db_instance" {
  description = "RDS instance resource."
  value       = aws_db_instance.this
}
