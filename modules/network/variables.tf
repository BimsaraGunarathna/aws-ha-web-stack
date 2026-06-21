variable "project_name" {
  description = "Name prefix applied to all networking resources."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "How many Availability Zones to spread subnets across (min 2 for ALB + RDS)."
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

variable "flow_log_retention_days" {
  description = "Retention period (days) for the VPC Flow Logs log group."
  type        = number
  default     = 365
}

variable "kms_deletion_window_days" {
  description = "Waiting period (days) before the Flow Logs KMS key is deleted."
  type        = number
  default     = 7
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
