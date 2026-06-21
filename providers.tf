provider "aws" {
  region = var.aws_region

  # Tags applied to every taggable resource the provider creates.
  # NOTE: IAM treats tag keys case-insensitively, so "project" and "Project"
  # would collide ("Duplicate tag keys") -- keep a single Project key.
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
