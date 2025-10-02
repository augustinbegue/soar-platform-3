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
  private_subnet_ids    = module.core.private_subnet_ids
  capacity_subnet_ids   = module.core.private_subnet_ids
  load_balancer_arn     = module.alb.load_balancer_arn
  target_group_arns     = module.alb.target_group_arns
  cluster_desired_count = 2

  depends_on = [module.alb]
}

module "aurora" {
  source = "./modules/aurora"

  name_prefix             = local.name_prefix
  vpc_id                  = module.core.vpc_id
  database_subnet_ids     = module.core.database_subnet_ids
  security_group_ids      = module.core.aurora_security_group_ids
  engine_mode             = "provisioned"
  master_username         = "changeme"
  master_password         = "changeme" # TODO: Inject via secrets manager or SSM; never commit real secrets.
  backup_retention_period = 7

  depends_on = [module.core]
}
