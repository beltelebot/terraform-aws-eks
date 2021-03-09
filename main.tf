provider "aws" {
  region = var.region
}


resource "random_string" "eksname" {
  length           = 6
  special          = false
}

data "aws_eks_cluster" "cluster" {
  name = module.control_plane.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.control_plane.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
#  load_config_file       = false
#  version                = "~> 1.9"
}
  
  
module "control_plane" {
  source = "./modules/control_plane"

  cluster_create_security_group                = var.cluster_create_security_group
  cluster_create_timeout                       = var.cluster_create_timeout
  cluster_delete_timeout                       = var.cluster_delete_timeout
  cluster_enabled_log_types                    = var.cluster_enabled_log_types
  cluster_encryption_key_arn                   = var.cluster_encryption_key_arn
  cluster_encryption_resources                 = var.cluster_encryption_resources
  cluster_endpoint_private_access              = var.cluster_endpoint_private_access
  cluster_endpoint_public_access               = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs         = var.cluster_endpoint_public_access_cidrs
  cluster_iam_role_name                        = var.cluster_iam_role_name
  cluster_log_kms_key_id                       = var.cluster_log_kms_key_id
  cluster_log_retention_in_days                = var.cluster_log_retention_in_days
#  cluster_name                                 = var.cluster_name
  cluster_name = "${var.cluster_name}-${random_string.eksname.result}"
 
  cluster_security_group_id                    = var.cluster_security_group_id
  cluster_version                              = var.cluster_version
  config_output_path                           = var.config_output_path
  create_eks                                   = var.create_eks
  eks_oidc_root_ca_thumbprint                  = var.eks_oidc_root_ca_thumbprint
  enable_irsa                                  = var.enable_irsa
  iam_path                                     = var.iam_path
  kubeconfig_aws_authenticator_additional_args = var.kubeconfig_aws_authenticator_additional_args
  kubeconfig_aws_authenticator_command         = var.kubeconfig_aws_authenticator_command
  kubeconfig_aws_authenticator_command_args    = var.kubeconfig_aws_authenticator_command_args
  kubeconfig_aws_authenticator_env_variables   = var.kubeconfig_aws_authenticator_env_variables
  kubeconfig_name                              = var.kubeconfig_name
  manage_cluster_iam_resources                 = var.manage_cluster_iam_resources
  permissions_boundary                         = var.permissions_boundary
  subnets                                      = var.subnets
  tags                                         = var.tags
  vpc_id                                       = var.vpc_id
  write_kubeconfig                             = var.write_kubeconfig
}

module "eks-node-group" {
  source = "umotif-public/eks-node-group/aws"
  version = "~> 3.0.0"

  cluster_name = module.control_plane.cluster_id

  subnet_ids = var.subnets

  desired_size = 1
  min_size     = 1
  max_size     = 3

  instance_types = ["t3.large"]
#  capacity_type  = "SPOT"

  ec2_ssh_key = "prodkey2"

  kubernetes_labels = {
    lifecycle = "OnDemand"
  }

  force_update_version = true

  tags = {
    Environment = "stage"
  }
}
  
  
  
module "aws_auth" {
  source = "./modules/aws_auth"

  cluster_name  = module.control_plane.cluster_id
  map_instances = concat(module.worker_groups.aws_auth_roles, module.node_groups.aws_auth_roles)

  create_eks           = var.create_eks
  manage_aws_auth      = var.manage_aws_auth
  map_accounts         = var.map_accounts
  map_roles            = var.map_roles
  map_users            = var.map_users
  wait_for_cluster_cmd = var.wait_for_cluster_cmd
}
