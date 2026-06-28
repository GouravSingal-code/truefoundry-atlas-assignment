# Data sources for AWS EKS cluster
data "aws_eks_cluster" "cluster" {
  name       = var.cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "cluster" {
  name       = var.cluster_name
  depends_on = [module.eks]
}

output "kubeconfig" {
  value     = local.kubeconfig_json
  sensitive = true
}
