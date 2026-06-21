terraform {
  # 1.10+ required for the S3 backend's native `use_lockfile` locking (backend.tf).
  # (1.7+ would otherwise suffice for `mock_provider` used by the test suite.)
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
