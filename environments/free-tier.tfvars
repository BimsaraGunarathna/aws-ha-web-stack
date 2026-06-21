# Overrides for the restricted AWS Free plan (accounts that haven't upgraded).
# Apply with:
#   terraform apply -var-file=environments/free-tier.tfvars -var="aws_region=us-east-1"

# ---- Database: the settings the Free plan rejects ----
db_instance_class               = "db.t3.micro" # free-tier eligible class
db_allocated_storage            = 20            # free-tier storage cap (GB)
db_multi_az                     = false         # single-AZ only on free tier
db_backup_retention_period      = 0             # Free plan caps retention; 0 disables automated backups (try 1 for a minimal daily backup)
db_performance_insights_enabled = false         # Performance Insights is not available on the restricted Free plan

# ---- Compute: free tier covers ~750 hrs/month of ONE t3.micro ----
instance_type    = "t3.micro"
min_size         = 1
max_size         = 1
desired_capacity = 1

# Allow `terraform destroy` without a manual unlock when the test is done.
db_deletion_protection = false
