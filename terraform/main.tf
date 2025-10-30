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

/* ALB module enabled. Note: some AWS Academy accounts may block ALB creation (OperationNotPermitted).
   If your account cannot create load balancers, re-comment this block and use public-direct ECS mode. */
module "alb" {
  source = "./modules/alb"

  name_prefix        = local.name_prefix
  vpc_id             = module.core.vpc_id
  subnet_ids         = module.core.public_subnet_ids
  security_group_ids = module.core.alb_security_group_ids

  depends_on = [module.core]
}

module "ecs" {
  source = "./modules/ecs"

  name_prefix           = local.name_prefix
  vpc_id                = module.core.vpc_id
  # When using an ALB we want ECS tasks in the private subnets
  private_subnet_ids    = module.core.private_subnet_ids
  capacity_subnet_ids   = module.core.private_subnet_ids
  cluster_desired_count = 2

  # ALB integration
  target_group_arns     = module.alb.target_group_arns
  alb_security_group_id = module.alb.security_group_id

  depends_on = [module.core, module.alb]
}

/* Aurora temporarily disabled because the current environment provides only a single private subnet
   and Aurora RDS clusters require subnets in at least 2 AZs. To re-enable Aurora, provide
   multiple private subnets (database_subnet_ids) or run Aurora in a different account/region.

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

  depends_on = [module.core]
}
*/
