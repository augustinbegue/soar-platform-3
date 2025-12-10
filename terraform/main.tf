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

  name_prefix = local.name_prefix
  vpc_id      = module.core.vpc_id
  # Using private subnets with ALB for production-ready setup
  private_subnet_ids       = module.core.private_subnet_ids
  capacity_subnet_ids      = module.core.private_subnet_ids
  cluster_desired_count    = 3
  autoscaling_min_capacity = 3
  autoscaling_max_capacity = 12

  # ALB integration enabled
  enable_alb            = true
  target_group_arns     = module.alb.target_group_arns
  alb_security_group_id = module.core.alb_security_group_ids[0]

  # Database connection
  container_image            = "ghcr.io/mzzay/soar-platform2/crud_app/backend:master-fddc6fe"
  db_secret_arn              = module.aurora.secret_arn
  db_writer_endpoint         = module.aurora.writer_endpoint
  db_reader_endpoint         = module.aurora.reader_endpoint
  db_reader_endpoints_per_az = module.aurora.reader_instance_endpoints
  db_name                    = module.aurora.database_name
  availability_zones         = var.availability_zones
  aurora_security_group_ids  = module.aurora.aurora_security_group_ids

  depends_on = [module.core, module.aurora, module.alb]
}

module "aurora" {
  source = "./modules/aurora"

  name_prefix             = local.name_prefix
  vpc_id                  = module.core.vpc_id
  database_subnet_ids     = module.core.private_subnet_ids
  security_group_ids      = module.core.aurora_security_group_ids
  availability_zones      = var.availability_zones
  engine_mode             = "provisioned"
  master_username         = "changeme"
  master_password         = "changeme" # TODO: Inject via secrets manager or SSM; never commit real secrets.
  backup_retention_period = 7
  # For development environments we prefer to skip creating a final snapshot to
  # avoid needing to provide a final_snapshot_identifier on destroy.
  skip_final_snapshot = true

  depends_on = [module.core]
}

module "s3_frontend" {
  source = "./modules/s3-frontend"

  name_prefix = local.name_prefix
  # Backend URL points to ALB DNS name
  backend_url = "http://${module.alb.load_balancer_dns_name}"

  depends_on = [module.ecs, module.alb]
}

module "monitoring" {
  source = "./modules/monitoring"

  name_prefix = local.name_prefix

  # ALB metrics
  alb_name                = module.alb.load_balancer_name
  alb_arn_suffix          = module.alb.load_balancer_arn_suffix
  target_group_name       = module.alb.target_group_name
  target_group_arn_suffix = module.alb.target_group_arn_suffix

  # ECS metrics
  ecs_cluster_name = module.ecs.cluster_name
  ecs_service_name = module.ecs.service_name
  ecs_min_capacity = 3

  # Alarm configuration
  enable_alarms = true
  alarm_actions = []

  # Thresholds
  alb_high_request_rate_threshold  = 50000
  alb_high_response_time_threshold = 1.0
  alb_high_5xx_threshold           = 100

  depends_on = [module.ecs, module.alb]
}
