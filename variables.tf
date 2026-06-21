variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Name prefix for all resources."
  type        = string
  default     = "flatrock-webapp"
}

variable "environment" {
  description = "Deployment environment (dev/staging/prod)."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of AZs to spread across (min 2)."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2
    error_message = "az_count must be at least 2: the ALB and RDS subnet group both require two AZs."
  }
}

# ---- Compute ----
variable "instance_type" {
  description = "EC2 instance type for the app tier."
  type        = string
  default     = "t3.micro"
}

variable "min_size" {
  description = "Minimum ASG instances."
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum ASG instances."
  type        = number
  default     = 4
}

variable "desired_capacity" {
  description = "Desired ASG instances."
  type        = number
  default     = 2
}

# ---- Database ----
variable "db_engine" {
  description = "Managed database engine."
  type        = string
  default     = "postgres"
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Initial database name."
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Database master username."
  type        = string
  default     = "appadmin"
}

variable "db_password" {
  description = "Database master password. Set via TF_VAR_db_password; never commit."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 8
    error_message = "db_password must be at least 8 characters."
  }
}

variable "db_multi_az" {
  description = "Run an RDS standby in a second AZ."
  type        = bool
  default     = false
}
