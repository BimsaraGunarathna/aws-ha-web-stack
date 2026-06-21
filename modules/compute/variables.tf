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

variable "enable_https" {
  description = "Serve HTTPS on :443 (with :80 redirecting to it). When false, the ALB serves the app directly over plain HTTP on :80 and no ACM certificate is needed."
  type        = bool
  default     = false
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for the HTTPS listener. Required only when enable_https = true."
  type        = string
  default     = ""
}

variable "ami_name_pattern" {
  description = "Name filter for the AMI lookup (most recent match is used)."
  type        = string
  default     = "al2023-ami-*-x86_64"
}

variable "ssl_policy" {
  description = "TLS security policy for the HTTPS listener."
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "health_check_path" {
  description = "Target group health check path."
  type        = string
  default     = "/"
}

variable "health_check_interval" {
  description = "Seconds between target group health checks."
  type        = number
  default     = 15
}

variable "health_check_timeout" {
  description = "Health check response timeout in seconds."
  type        = number
  default     = 5
}

variable "health_check_healthy_threshold" {
  description = "Consecutive successes before a target is healthy."
  type        = number
  default     = 2
}

variable "health_check_unhealthy_threshold" {
  description = "Consecutive failures before a target is unhealthy."
  type        = number
  default     = 2
}

variable "health_check_matcher" {
  description = "HTTP codes considered healthy."
  type        = string
  default     = "200"
}

variable "health_check_grace_period" {
  description = "Seconds the ASG waits before health-checking a new instance."
  type        = number
  default     = 300
}

variable "instance_refresh_min_healthy_percentage" {
  description = "Minimum percent of healthy instances kept during a rolling instance refresh."
  type        = number
  default     = 50
}

variable "alb_5xx_alarm_threshold" {
  description = "Target 5xx count over the period that trips the CloudWatch alarm."
  type        = number
  default     = 5
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
