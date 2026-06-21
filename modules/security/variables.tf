variable "project_name" {
  description = "Name prefix for security groups."
  type        = string
}

variable "vpc_id" {
  description = "VPC the security groups belong to."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC. Used to restrict egress to internal traffic only where possible."
  type        = string
}

variable "db_port" {
  description = "Database port to open from the app tier to the DB tier."
  type        = number
  default     = 5432
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
