# Generated Terraform configuration

# Define provider
provider "aws" {
  region  = var.region
  profile = "slazysloth"
}

# Define variables
variable "use_existing_network" {
  type        = bool
  description = "Flag to enable using existing network infrastructure"
  default     = false
}
variable "vpc_id" {
  type        = string
  description = "VPC ID of the network. Used only when use_existing_network is enabled"
  default     = ""
}
variable "private_subnets_ids" {
  type        = list(string)
  description = "List of private subnet IDs. Used only when use_existing_network is enabled"
  default     = []
}
variable "public_subnets_ids" {
  type        = list(string)
  description = "List of public subnet IDs. Used only when use_existing_network is enabled"
  default     = []
}
variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.10.0.0/16"
}
variable "private_subnets_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks for private subnets"
  default     = ["10.10.0.0/20", "10.10.16.0/20", "10.10.32.0/20"]
}
variable "public_subnets_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks for public subnets"
  default     = []
}
variable "use_existing_cluster" {
  type        = bool
  description = "Flag to enable existing EKS cluster"
  default     = false
}
variable "existing_cluster_node_role_arn" {
  type        = string
  description = "Node IAM role arn. Used only when use_existing_cluster is enabled"
  default     = ""
}
variable "existing_cluster_node_security_group_id" {
  type        = string
  description = "Security group ID of the node. Used only when use_existing_cluster is enabled"
  default     = "<sg-00000000000000000>"
}
variable "existing_cluster_oidc_issuer_arn" {
  type        = string
  description = "OIDC issuer ARN of EKS cluster. Used only when use_existing_cluster is enabled"
  default     = ""
}
variable "existing_cluster_oidc_issuer_url" {
  type        = string
  description = "OIDC issuer url of EKS cluster. Used only when use_existing_cluster is enabled"
  default     = ""
}
variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster to be created. If use_existing_cluster is enabled cluster_name is used to fetch cluster details"
  default     = ""
}
variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version to use for the EKS cluster"
  default     = "1.34"
}
variable "region" {
  type        = string
  description = "AWS region where resources will be created"
  default     = "us-east-1"
}
variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones for the VPC that needs to be created"
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}
variable "tenant_name" {
  type        = string
  description = "Name of the tenant"
  default     = ""
}
variable "tags" {
  type        = map(string)
  description = "Tags to be applied to all resources"
  default = {
    "truefoundry"                 = "managed"
    "terraform"                   = "true"
    "class.truefoundry.com/infra" = "true"
  }
}
variable "control_plane_install" {
  type        = bool
  description = "enable/disable control plane installation"
  default     = false
}
variable "control_plane_url" {
  type        = string
  description = "URL of the Truefoundry control plane (must include https://)"
  default     = "<control-plane-url>"
}
variable "license_key" {
  type        = string
  description = "License key for Truefoundry control plane, Required if control plane install is true"
  default     = "<license-key>"
}
variable "truefoundry_image_pull_config_json" {
  type        = string
  description = "JSON configuration for pulling Truefoundry images"
  default     = ""
}
variable "control_plane_roles" {
  type        = list(string)
  description = "List of control plane roles that can assume your platform role"
  default     = []
}
variable "existing_db_host" {
  type        = string
  description = "Host of the existing database. Required when using an existing database"
  default     = ""
}
variable "existing_db_name" {
  type        = string
  description = "Name of the existing database. Required when using an existing database"
  default     = ""
}
variable "existing_db_username" {
  type        = string
  description = "Username for the existing database. Required when using an existing database"
  default     = ""
}
variable "existing_db_password" {
  type        = string
  description = "Password for the existing database. Required when using an existing database"
  default     = ""
}
variable "enable_blob_storage" {
  type        = bool
  description = "Enable blob storage feature in the platform"
  default     = true
}
variable "enable_container_registry" {
  type        = bool
  description = "Enable docker registry feature in the platform"
  default     = true
}
variable "enable_secrets_manager" {
  type        = bool
  description = "Enable secrets manager feature in the platform"
  default     = false
}
variable "enable_parameter_store" {
  type        = bool
  description = "Enable parameter store in the platform"
  default     = true
}
variable "enable_cluster_integration" {
  type        = bool
  description = "Enable cluster integration in the platform"
  default     = true
}
variable "tfy_api_key" {
  type        = string
  description = "API key for authenticating with Truefoundry control plane"
  default     = ""
}
# Add this data source
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
# Define modules
module "network" {
  source                = "truefoundry/truefoundry-network/aws"
  version               = "0.4.1"
  aws_account_id        = data.aws_caller_identity.current.account_id
  aws_region            = var.region
  cluster_name          = var.cluster_name
  azs                   = var.availability_zones
  tags                  = var.tags
  vpc_cidr              = var.vpc_cidr
  private_subnets_cidrs = var.private_subnets_cidrs
  public_subnets_cidrs  = var.public_subnets_cidrs
}
module "eks" {
  source          = "truefoundry/truefoundry-cluster/aws"
  version         = "0.8.3"
  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version
  vpc_id          = module.network.vpc_id
  subnet_ids      = module.network.private_subnets_id
  tags            = var.tags
  node_security_group_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "karpenter.sh/discovery"                    = "${var.cluster_name}"
  }
}
module "ebs" {
  source      = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version     = "6.4.0"
  name        = "${var.cluster_name}-csi-ebs"
  policy_name = "${var.cluster_name}-csi-ebs-policy"
  oidc_providers = {
    "ebs" = {
      "provider_arn"               = "${module.eks.oidc_provider_arn}"
      "namespace_service_accounts" = ["aws-ebs-csi-driver:ebs-csi-controller-sa"]
    }
  }
  attach_ebs_csi_policy = true
  tags                  = var.tags
}
module "efs" {
  source                        = "truefoundry/truefoundry-efs/aws"
  version                       = "0.5.2"
  cluster_name                  = var.cluster_name
  region                        = var.region
  cluster_oidc_issuer_arn       = module.eks.oidc_provider_arn
  efs_node_iam_role_arn         = module.eks.eks_managed_node_groups.initial.iam_role_arn
  private_subnets_cidrs         = module.network.private_subnets_cidrs
  private_subnets_id            = module.network.private_subnets_id
  performance_mode              = "generalPurpose"
  throughput_mode               = "bursting"
  vpc_id                        = module.network.vpc_id
  k8s_service_account_name      = "efs-csi-controller-sa"
  k8s_service_account_namespace = "aws-efs-csi-driver"
  tags                          = var.tags
}
module "aws-load-balancer-controller" {
  source                        = "truefoundry/truefoundry-load-balancer-controller/aws"
  version                       = "0.2.1"
  cluster_name                  = var.cluster_name
  cluster_oidc_provider_arn     = module.eks.oidc_provider_arn
  k8s_service_account_name      = "aws-load-balancer-controller"
  k8s_service_account_namespace = "aws-load-balancer-controller"
}
module "karpenter" {
  source                       = "truefoundry/truefoundry-karpenter/aws"
  version                      = "0.4.3"
  depends_on                   = [module.eks]
  cluster_name                 = var.cluster_name
  controller_node_iam_role_arn = var.use_existing_cluster ? var.existing_cluster_node_role_arn : module.eks.eks_managed_node_groups.initial.iam_role_arn
  controller_nodegroup_name    = "initial"
  tags                         = var.tags
}
module "tfy-platform-features" {
  source                              = "truefoundry/truefoundry-platform-features/aws"
  version                             = "0.5.0"
  depends_on                          = [module.eks]
  aws_account_id                      = data.aws_caller_identity.current.account_id
  aws_region                          = var.region
  cluster_name                        = var.cluster_name
  tags                                = var.tags
  control_plane_roles                 = var.control_plane_roles
  oidc_provider_url                   = module.eks.cluster_oidc_issuer_url
  feature_secrets_manager_enabled     = var.enable_secrets_manager
  feature_parameter_store_enabled     = var.enable_parameter_store
  feature_docker_registry_enabled     = var.enable_container_registry
  feature_blob_storage_enabled        = var.enable_blob_storage
  feature_cluster_integration_enabled = var.enable_cluster_integration
}
module "tfy-sleep" {
  source          = "truefoundry/sleep/truefoundry"
  version         = "0.1.1"
  depends_on      = [module.tfy-platform-features]
  create_duration = "60s"
}
module "platform-integrations" {
  source                                       = "truefoundry/integrations/truefoundry"
  version                                      = "0.1.23"
  depends_on                                   = [module.tfy-sleep]
  cluster_name                                 = var.cluster_name
  cluster_type                                 = "aws-eks"
  tfy_api_key                                  = var.tfy_api_key
  tenant_name                                  = var.tenant_name
  aws_account_id                               = data.aws_caller_identity.current.account_id
  aws_region                                   = var.region
  control_plane_url                            = var.control_plane_url
  aws_cluster_integration_enabled              = module.tfy-platform-features.platform_cluster_integration_enabled
  aws_parameter_store_enabled                  = module.tfy-platform-features.platform_ssm_enabled
  aws_secrets_manager_enabled                  = module.tfy-platform-features.platform_secrets_manager_enabled
  aws_ecr_enabled                              = module.tfy-platform-features.platform_ecr_enabled
  aws_s3_enabled                               = module.tfy-platform-features.platform_bucket_enabled
  aws_s3_bucket_name                           = module.tfy-platform-features.platform_bucket_name
  aws_platform_features_user_enabled           = module.tfy-platform-features.platform_user_enabled
  aws_platform_features_user_access_key_id     = module.tfy-platform-features.platform_user_access_key
  aws_platform_features_user_secret_access_key = module.tfy-platform-features.platform_user_secret_key
  aws_platform_features_role_arn               = module.tfy-platform-features.platform_iam_role_arn
}
module "argocd" {
  source           = "truefoundry/truefoundry-helm/kubernetes"
  version          = "0.1.5"
  depends_on       = [module.tfy-sleep]
  chart_name       = "argo-cd"
  repo_name        = "argo"
  repo_url         = "https://argoproj.github.io/argo-helm"
  chart_version    = "9.5.11"
  create_namespace = true
  namespace        = "argocd"
  release_name     = "argocd"
  kubeconfig_json  = local.kubeconfig_json
  set_values = {
    "applicationSet.enabled"  = "false"
    "notifications.enabled"   = "false"
    "dex.enabled"             = "false"
    "server.extraArgs[0]"     = "--insecure"
    "server.extraArgs[1]"     = "--application-namespaces=*"
    "controller.extraArgs[0]" = "--application-namespaces=*"
  }
}
module "truefoundry" {
  source           = "truefoundry/truefoundry-helm/kubernetes"
  version          = "0.1.5"
  depends_on       = [module.argocd, module.platform-integrations]
  chart_name       = "tfy-k8s-aws-eks-inframold"
  release_name     = "tfy-k8s-aws-eks-inframold"
  kubeconfig_json  = local.kubeconfig_json
  create_namespace = true
  namespace        = "argocd"
  repo_name        = "truefoundry"
  repo_url         = "https://truefoundry.github.io/infra-charts"
  set_values = {
    "tenantName"      = "${var.tenant_name}"
    "controlPlaneURL" = "${var.control_plane_url}"
    "clusterName"     = "${var.cluster_name}"
    "argocd" = {
      "enabled" = true
    }
    "argoWorkflows" = {
      "enabled" = true
    }
    "argoRollouts" = {
      "enabled" = true
    }
    "metricsServer" = {
      "enabled" = true
    }
    "gpu" = {
      "enabled" = true
    }
    "keda" = {
      "enabled" = true
    }
    "prometheus" = {
      "enabled" = true
      "config" = {
        "enabled" = true
      }
    }
    "tfyLogs" = {
      "enabled" = true
    }
    "aws" = {
      "awsLoadBalancerController" = {
        "enabled" = true
        "roleArn" = "${module.aws-load-balancer-controller.elb_iam_role_arn}"
        "vpcId"   = "${module.network.vpc_id}"
        "region"  = "${var.region}"
      }
      "karpenter" = {
        "enabled"           = true
        "clusterEndpoint"   = "${module.eks.cluster_endpoint}"
        "instanceProfile"   = "${module.karpenter.karpenter_instance_profile_id}"
        "interruptionQueue" = "${module.karpenter.karpenter_sqs_name}"
        "defaultZones"      = "${var.availability_zones}"
      }
      "awsEbsCsiDriver" = {
        "enabled" = true
        "roleArn" = "${module.ebs.arn}"
      }
      "awsEfsCsiDriver" = {
        "enabled"      = true
        "fileSystemId" = "${module.efs.efs_id}"
        "roleArn"      = "${module.efs.efs_role_arn}"
      }
      "inferentia" = {
        "enabled" = true
      }
    }
    "istio" = {
      "enabled" = true
      "gateway" = {
        "annotations" = {
          "service.beta.kubernetes.io/aws-load-balancer-name"                              = "${var.cluster_name}"
          "service.beta.kubernetes.io/aws-load-balancer-type"                              = "external"
          "service.beta.kubernetes.io/aws-load-balancer-scheme"                            = "internet-facing"
          "service.beta.kubernetes.io/aws-load-balancer-ssl-ports"                         = "https"
          "service.beta.kubernetes.io/aws-load-balancer-alpn-policy"                       = "HTTP2Preferred"
          "service.beta.kubernetes.io/aws-load-balancer-backend-protocol"                  = "tcp"
          "service.beta.kubernetes.io/aws-load-balancer-additional-resource-tags"          = "cluster-name=${var.cluster_name},truefoundry.com/managed=true,owner=Truefoundry,application=tfy-istio-ingress"
          "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
        }
      }
      "discovery" = {
        "hub" = "gcr.io/istio-release"
      }
      "tfyGateway" = {
        "httpsRedirect" = true
      }
    }
    "truefoundry" = {
      "enabled" = false
    }
    "tfyAgent" = {
      "enabled"      = true
      "clusterToken" = "${module.platform-integrations.cluster_token}"
    }
  }
}
# Define outputs
output "vpc_id" {
  value = module.network.vpc_id
}
output "private_subnets_id" {
  value = module.network.private_subnets_id
}
output "cluster_name" {
  value = var.cluster_name
}
output "tenant_name" {
  value = var.tenant_name
}
output "cluster_token" {
  value     = module.platform-integrations.cluster_token
  sensitive = true
}
