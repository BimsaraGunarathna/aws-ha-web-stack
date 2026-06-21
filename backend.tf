# Remote state in S3 with native S3 state locking (use_lockfile).
#
# The bucket must exist BEFORE this runs -- create it once with the config in
# ./bootstrap (see README). Backend blocks cannot use variables, so edit the
# bucket name below (S3 bucket names are globally unique) or pass these values
# at init time with:
#
#   terraform init -backend-config="bucket=<your-bucket>"
#
# Locking uses a .tflock object in the bucket (Terraform >= 1.10); no DynamoDB
# table is required.
terraform {
  backend "s3" {
    bucket       = "aws-ha-web-stack-tfstate-CHANGE-ME" # <-- must be globally unique
    key          = "webapp/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
    encrypt      = true
  }
}
