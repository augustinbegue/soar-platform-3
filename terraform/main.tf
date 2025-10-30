locals {
  name_prefix = "${var.project}-${var.environment}"
}

module "core" {
  source = "./modules/core"

  project               = var.project
  environment           = var.environment
  aws_region            = var.aws_region
  availability_zones    = var.availability_zones
  vpc_cidr              = var.vpc_cidr
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  database_subnet_cidrs = var.database_subnet_cidrs
}

/* ALB module disabled to avoid account ELBv2 restrictions. Re-enable if your account supports ALB. */
/*
module "alb" {
  source = "./modules/alb"

  name_prefix        = local.name_prefix
  vpc_id             = module.core.vpc_id
  subnet_ids         = module.core.public_subnet_ids
  security_group_ids = module.core.alb_security_group_ids

  depends_on = [module.core]
}
*/

module "ecs" {
  source = "./modules/ecs"

  name_prefix           = local.name_prefix
  vpc_id                = module.core.vpc_id
  # Using public-direct mode (ALB disabled) — tasks get public IPs for testing
  private_subnet_ids    = module.core.public_subnet_ids
  capacity_subnet_ids   = module.core.public_subnet_ids
  cluster_desired_count = 2

  # No ALB integration when ALB module is disabled
  target_group_arns     = []
  alb_security_group_id = ""

  depends_on = [module.core]
}

module "aurora" {
  source = "./modules/aurora"

  name_prefix             = local.name_prefix
  vpc_id                  = module.core.vpc_id
  database_subnet_ids     = module.core.private_subnet_ids
  security_group_ids      = module.core.aurora_security_group_ids
  ecs_security_group_id   = module.ecs.ecs_tasks_security_group_id
  engine_mode             = "provisioned"
  master_username         = "changeme"
  master_password         = "changeme" # TODO: Inject via secrets manager or SSM; never commit real secrets.
  backup_retention_period = 7
  # For development environments we prefer to skip creating a final snapshot to
  # avoid needing to provide a final_snapshot_identifier on destroy.
  skip_final_snapshot     = true

  depends_on = [module.core]
}
