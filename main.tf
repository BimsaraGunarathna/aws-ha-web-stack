locals {
  # db port derived from engine so the security group opens the right one.
  db_port = var.db_engine == "postgres" ? 5432 : 3306

  # Project/Environment/ManagedBy come from the provider's default_tags,
  # so module-level tags stay empty to avoid duplicate-key tagging.
  common_tags = {}
}

module "network" {
  source               = "./modules/network"
  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  az_count             = var.az_count
  enable_vpc_flow_logs = var.enable_vpc_flow_logs
  tags                 = local.common_tags
}

module "security" {
  source       = "./modules/security"
  project_name = var.project_name
  vpc_id       = module.network.vpc_id
  vpc_cidr     = var.vpc_cidr
  db_port      = local.db_port
  tags         = local.common_tags
}

module "compute" {
  source              = "./modules/compute"
  project_name        = var.project_name
  vpc_id              = module.network.vpc_id
  public_subnet_ids   = module.network.public_subnet_ids
  private_subnet_ids  = module.network.private_subnet_ids
  alb_sg_id           = module.security.alb_sg_id
  instance_sg_id      = module.security.instance_sg_id
  instance_type       = var.instance_type
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  cpu_target          = var.cpu_target
  enable_https        = var.enable_https
  acm_certificate_arn = var.acm_certificate_arn
  tags                = local.common_tags
}

module "database" {
  source                       = "./modules/database"
  project_name                 = var.project_name
  private_subnet_ids           = module.network.private_subnet_ids
  db_sg_id                     = module.security.database_sg_id
  engine                       = var.db_engine
  engine_version               = var.db_engine_version
  instance_class               = var.db_instance_class
  allocated_storage            = var.db_allocated_storage
  db_name                      = var.db_name
  db_username                  = var.db_username
  multi_az                     = var.db_multi_az
  skip_final_snapshot          = var.db_skip_final_snapshot
  deletion_protection          = var.db_deletion_protection
  backup_retention_period      = var.db_backup_retention_period
  performance_insights_enabled = var.db_performance_insights_enabled
  tags                         = local.common_tags
}
