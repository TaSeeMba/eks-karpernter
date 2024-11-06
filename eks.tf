module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access  = true

  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
  }

  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnets_ids
# EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    instance_types = ["m6i.large", "m5.large", "m5n.large"]
  }
  eks_managed_node_groups = {
    eks_nodes = {
      instance_types = ["m5.large"]
      min_size     = 1
      max_size     = 3
      desired_size = 2
    }
  }

  # eks_managed_node_groups = {
  #   example = {
  #     instance_types = var.node_instance_types

  #     # Exposes all EFA interfaces on the launch template created by the node group(s)
  #     # This would expose all 32 EFA interfaces for the p5.48xlarge instance type
  #     enable_efa_support = true

  #     pre_bootstrap_user_data = <<-EOT
  #       # Mount NVME instance store volumes since they are typically
  #       # available on instance types that support EFA
  #       setup-local-disks raid0
  #     EOT

  #     # EFA should only be enabled when connecting 2 or more nodes
  #     # Do not use EFA on a single node workload
  #     min_size     = 1
  #     max_size     = 3
  #     desired_size = 1
  #   }
  # }

  # Cluster access entry
  # To add the current caller identity as an administrator
  enable_cluster_creator_admin_permissions = true

#   access_entries = {
#     # One access entry with a policy associated
#     example = {
#       kubernetes_groups = []
#       principal_arn     = "arn:aws:iam::123456789012:role/something"

#       policy_associations = {
#         example = {
#           policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
#           access_scope = {
#             namespaces = ["default"]
#             type       = "namespace"
#           }
#         }
#       }
#     }
#   }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}