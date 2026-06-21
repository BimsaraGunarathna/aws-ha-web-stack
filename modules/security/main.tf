# Three-tier security model. Traffic flows strictly: internet -> ALB -> instances -> DB.
# Each tier only accepts traffic from the tier directly in front of it.

# Tier 1: ALB. Public HTTPS entrypoint (HTTP redirects to HTTPS).
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow inbound HTTP and HTTPS from the internet to the load balancer."
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from anywhere (redirects to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
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

  # dnf requires DNS (53) and package mirrors (80/443). Return traffic is stateful.
  #trivy:ignore:AWS-0104 -- DNS (UDP) to 0.0.0.0/0 is required for package repository resolution on first boot.
  egress {
    description = "DNS (UDP)"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #trivy:ignore:AWS-0104 -- DNS (TCP) to 0.0.0.0/0 is required for package repository resolution on first boot.
  egress {
    description = "DNS (TCP)"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #trivy:ignore:AWS-0104 -- HTTP to 0.0.0.0/0 is required for dnf package mirrors that do not support TLS.
  egress {
    description = "HTTP outbound (package mirrors)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #trivy:ignore:AWS-0104 -- HTTPS to 0.0.0.0/0 is required for AWS API calls and TLS package mirrors.
  egress {
    description = "HTTPS outbound (AWS APIs, TLS mirrors)"
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
