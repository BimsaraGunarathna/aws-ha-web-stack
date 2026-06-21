environment       = "dev"
instance_type     = "t3.micro"
min_size          = 2
max_size          = 3
desired_capacity  = 2
db_instance_class = "db.t3.micro"
db_multi_az       = false
# Dev convenience: allow `terraform destroy` without manually disabling protection.
db_deletion_protection = false
