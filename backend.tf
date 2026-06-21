# Remote state in S3 with DynamoDB state locking.
#
# The bucket and table must exist BEFORE this runs -- create them once with the
# config in ./bootstrap (see README). Backend blocks cannot use variables, so
# edit the bucket name below (S3 bucket names are globally unique) or pass these
# values at init time with:
#
#   terraform init -backend-config="bucket=<your-bucket>"
#
terraform {
  backend "s3" {
    bucket         = "myproject-tfstate-CHANGE-ME" # <-- must be globally unique
    key            = "webapp/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}
