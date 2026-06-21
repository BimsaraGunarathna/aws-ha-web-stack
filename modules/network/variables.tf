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

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
