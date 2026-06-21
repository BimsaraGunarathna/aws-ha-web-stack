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

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs for security auditing."
  type        = bool
  default     = true
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

variable "cpu_target" {
  description = "Target average CPU percent for auto-scaling policy."
  type        = number
  default     = 50
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for the ALB HTTPS listener."
  type        = string
}

# ---- Database ----
variable "db_engine" {
  description = "Managed database engine."
  type        = string
  default     = "postgres"
}

variable "db_engine_version" {
  description = "Database engine version."
  type        = string
  default     = "16"
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB."
  type        = number
  default     = 20
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

variable "db_multi_az" {
  description = "Run an RDS standby in a second AZ."
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot on deletion (dev convenience vs safety)."
  type        = bool
  default     = true
}
