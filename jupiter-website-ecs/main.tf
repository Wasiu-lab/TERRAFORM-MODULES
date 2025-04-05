#configure aws provider
provider "aws" {
  region  = var.region
  profile = "myprofile"
}

#create vpc
module "vpc" {
  source                       = "../modules/vpc"
  region                       = var.region
  project_name                 = var.project_name
  vpc_cidr                     = var.vpc_cidr
  public_subnet_az1_cidr       = var.public_subnet_az1_cidr
  public_subnet_az2_cidr       = var.public_subnet_az2_cidr
  private_app_subnet_az1_cidr  = var.private_app_subnet_az1_cidr
  private_app_subnet_az2_cidr  = var.private_app_subnet_az2_cidr
  private_data_subnet_az1_cidr = var.private_data_subnet_az1_cidr
  private_data_subnet_az2_cidr = var.private_data_subnet_az2_cidr
}

# Create NAT Gateway
module "nat-gateway" {
  source                      = "../modules/nat-gateway"
  public_subnet_az1_id        = module.vpc.public_subnet_az1_id
  internet_gateway            = module.vpc.internet_gateway
  public_subnet_az2_id        = module.vpc.public_subnet_az2_id
  vpc_id                      = module.vpc.vpc_id
  private_app_subnet_az1_id   = module.vpc.private_app_subnet_az1_id
  private_data_subnet_az1_id  = module.vpc.private_data_subnet_az1_id
  private_app_subnet_az2_id   = module.vpc.private_app_subnet_az2_id
  private_data_subnet_az2_id  = module.vpc.private_data_subnet_az2_id
}

# Create Security Groups
module "security-groups" {
  source = "../modules/security-groups"
  vpc_id = module.vpc.vpc_id
}

# Create ECS task execution role
module "ecs-task-execution-role" {
  source       = "../modules/ecs-task-execution-role"
  project_name = module.vpc.project_name
}

# Create Certificate Manager
module "certificate-manager" {
  source           = "../modules/Certificate-Manager"
  domain_name      = var.domain_name
  alternative_name = var.alternative_name
}

# Create application-load-balancer
module "application-load-balancer" {
  source                     = "../modules/ALB"
  project_name               = module.vpc.project_name
  alb_security_group_id      = module.security-groups.alb_security_group_id
  public_subnet_az1_id       = module.vpc.public_subnet_az1_id
  public_subnet_az2_id       = module.vpc.public_subnet_az2_id
  vpc_id                     = module.vpc.vpc_id
  certificate_arn            = module.certificate-manager.certificate_arn
}

# Create ECS Cluster
module "ecs" {
  source                      = "../modules/ECS"
  project_name                = module.vpc.project_name
  ecs_task_execution_role_arn = module.ecs-task-execution-role.ecs_task_execution_role_arn
  container_image             = var.container_image
  region                      = module.vpc.region
  private_app_subnet_az1_id   = module.vpc.private_app_subnet_az1_id
  private_app_subnet_az2_id   = module.vpc.private_app_subnet_az2_id
  ecs_security_group_id       = module.security-groups.ecs_security_group_id
  alb_target_group_arn        = module.application-load-balancer.alb_target_group_arn
}