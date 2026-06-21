provider "aws" {
  region = var.aws_region

  # Tags applied to every taggable resource the provider creates.
  default_tags {
    tags = {
      project     = "aws-ha-web-stack"
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
