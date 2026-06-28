locals {
  eks_cluster_auth = {
    apiVersion = "v1"
    kind       = "Config"
    clusters = [{
      name = var.cluster_name
      cluster = {
        server                     = data.aws_eks_cluster.cluster.endpoint
        certificate-authority-data = data.aws_eks_cluster.cluster.certificate_authority[0].data
      }
    }]
    contexts = [{
      name = var.cluster_name
      context = {
        cluster = var.cluster_name
        user    = "aws-eks"
      }
    }]
    current-context = var.cluster_name
    users = [{
      name = "aws-eks"
      user = {
        token = data.aws_eks_cluster_auth.cluster.token
      }
    }]
  }

  kubeconfig_json = jsonencode(local.eks_cluster_auth)
}
