# Three-tier security model. Traffic flows strictly: internet -> ALB -> instances -> DB.
# Each tier only accepts traffic from the tier directly in front of it.

# Tier 1: ALB. Public HTTP entrypoint.
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow inbound HTTP from the internet to the load balancer."
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Forward HTTP to instances inside the VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(var.tags, { Name = "${var.project_name}-alb-sg" })
}

# Tier 2: app instances. Only accept HTTP from the ALB security group (not the internet).
resource "aws_security_group" "instance" {
  name        = "${var.project_name}-instance-sg"
  description = "Allow inbound HTTP only from the ALB."
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from ALB only"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # HTTPS only: dnf updates, AWS API calls. Return traffic is stateful.
  #trivy:ignore:AWS-0104 -- Egress is restricted to TCP/443 (HTTPS) only; 0.0.0.0/0 is required for dynamic package mirrors and AWS endpoints.
  egress {
    description = "HTTPS outbound (package installs, AWS APIs)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.project_name}-instance-sg" })
}

# Tier 3: database. Only accept the DB port from the instance security group.
resource "aws_security_group" "database" {
  name        = "${var.project_name}-db-sg"
  description = "Allow inbound DB traffic only from app instances."
  vpc_id      = var.vpc_id

  ingress {
    description     = "DB port from instances only"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.instance.id]
  }

  # DB instances only need to talk to AWS services inside the VPC (backups, monitoring).
  egress {
    description = "VPC-internal outbound only"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(var.tags, { Name = "${var.project_name}-db-sg" })
}
