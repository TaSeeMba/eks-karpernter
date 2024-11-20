module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.29"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access  = true
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  # vpc_id                   = module.vpc.id
  # subnet_ids               = [ aws_subnet.private-af-south-1a.id,
  #     aws_subnet.private-af-south-1b.id, aws_subnet.public-af-south-1a.id,
  #     aws_subnet.public-af-south-1b.id
  # ]

  # control_plane_subnet_ids = [ aws_subnet.public-af-south-1a.id,
  #     aws_subnet.public-af-south-1b.id]

  eks_managed_node_groups = {
    karpenter = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["m5.large"]

      min_size     = 2
      max_size     = 3
      desired_size = 2

      taints = {
        # This Taint aims to keep just EKS Addons and Karpenter running on this MNG
        # The pods that do not tolerate this taint should run on nodes created by Karpenter
        addons = {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        },
      }
    }
  }

  node_security_group_tags = merge(var.tags, {
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    # (i.e. - at most, only one security group should have this tag in your account)
    "karpenter.sh/discovery" = var.cluster_name
  })

  # enable_irsa = false
  # control_plane_subnet_ids = var.public_subnets_ids
# EKS Managed Node Group(s)
  # eks_managed_node_group_defaults = {
  #   instance_types = ["t3.small"]
  # }
  # eks_managed_node_groups = {
  #   eks_nodes = {
  #     instance_types = ["t3.small"]
  #     min_size     = 1
  #     max_size     = 3
  #     desired_size = 2
  #   }
  # }

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

  # iam_role_additional_policies = {
  #   AmazonSSMManagedInstanceCore             = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  #   AmazonSSMManagedEC2InstanceDefaultPolicy = "arn:aws:iam::aws:policy/AmazonSSMManagedEC2InstanceDefaultPolicy"
  # }

  # access_entries = {
  #   # One access entry with a policy associated
  #   admin = {
  #     kubernetes_groups = ["nodes", "node-proxier"]
  #     principal_arn     = "arn:aws:iam::509399612661:user/terraform"

  #     policy_associations = {
  #       all = {
  #         policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
  #         access_scope = {
  #           namespaces = []
  #           type       = "cluster"
  #         }
  #       }
  #     }
  #   }
  # }

  # fargate_profiles = {
  #   karpenter = {
  #     selectors = [
  #       { namespace = "karpenter" 
  #       }
  #     ]
  #     subnet_ids = [aws_subnet.private-af-south-1a.id, aws_subnet.private-af-south-1b.id]
  #   }
  #   coredns = {
  #     selectors = [
  #       { namespace = "kube-system"
  #         labels = {
  #           "eks.amazonaws.com/component" = "coredns"
  #         }
  #       }
  #     ]
  #     subnet_ids = [aws_subnet.private-af-south-1a.id, aws_subnet.private-af-south-1b.id]
  #   }
  # }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

# resource "null_resource" "update_kubeconfig" {
#   provisioner "local-exec" {
#     command = "aws eks --region ${var.region} update-kubeconfig --name ${var.cluster_name}"
#   }
#   depends_on = [module.eks]
# }