variable "project_name" {
  description = "Name prefix for compute resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets for the ALB."
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnets for the instances."
  type        = list(string)
}

variable "alb_sg_id" {
  description = "Security group ID for the ALB."
  type        = string
}

variable "instance_sg_id" {
  description = "Security group ID for the instances."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "min_size" {
  description = "Minimum instances in the ASG."
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum instances in the ASG."
  type        = number
  default     = 4
}

variable "desired_capacity" {
  description = "Desired instances in the ASG."
  type        = number
  default     = 2
}

variable "cpu_target" {
  description = "Target average CPU percent for the auto-scaling policy."
  type        = number
  default     = 50
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
