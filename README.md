# SOAR Platform 3 – Terraform Scaffolding

This repository provides a Terraform IaC to bootstrap a highly-available platform on AWS using the following architecture:

- **Application Load Balancer (ALB)** spanning three Availability Zones.
- **ECS cluster** deployed across three AZs for stateless services.
- **Aurora database cluster** distributed across three AZs for resilient data storage.
- Shared networking primitives (VPC, subnets, security groups) to keep the platform scalable and secure.

## Repository layout

```
terraform/
├── config/               # Sample environment variable definitions
├── main.tf               # Module wiring for the platform
├── outputs.tf            # Root outputs exposed by the stack
├── providers.tf          # AWS provider configuration
├── variables.tf          # Root input variable definitions
├── versions.tf           # Terraform and provider version constraints
└── modules/
    ├── core/             # Networking, subnets, security groups
    ├── alb/              # Application Load Balancer skeleton
    ├── ecs/              # ECS control plane and services skeleton
    └── aurora/           # Aurora database scaffolding
```

## Getting started

1. Ensure Terraform ≥ 1.6.0 is installed and that you can authenticate to AWS (profiles, SSO, etc.).
2. Copy `terraform/config/dev.tfvars` and tailor CIDR blocks, AZs, and naming for your environment.
3. Implement the TODO sections within each module to create the actual resources.
4. Initialize and (optionally) validate the configuration:

```bash
cd terraform
terraform init
terraform validate -var-file="config/dev-single-az.tfvars"
terraform plan -var-file="config/dev-single-az.tfvars"
terraform apply -var-file="config/dev-single-az.tfvars" -auto-approve
terraform destroy -var-file="config/dev-single-az.tfvars" -auto-approve
```
