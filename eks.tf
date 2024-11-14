module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access  = true

  cluster_addons = {
    coredns = {
      # resolve_conflicts_on_create = "PRESERVE"
      # resolve_conflicts_on_update = "PRESERVE"
      configuration_values = jsonencode({
        computeType = "Fargate"
        # Ensure that the we fully utilize the minimum amount of resources that are supplied by
        # Fargate https://docs.aws.amazon.com/eks/latest/userguide/fargate-pod-configuration.html
        # Fargate adds 256 MB to each pod's memory reservation for the required Kubernetes
        # components (kubelet, kube-proxy, and containerd). Fargate rounds up to the following
        # compute configuration that most closely matches the sum of vCPU and memory requests in
        # order to ensure pods always have the resources that they need to run.
        resources = {
          limits = {
            cpu = "0.25"
            # We are targetting the smallest Task size of 512Mb, so we subtract 256Mb from the
            # request/limit to ensure we can fit within that task
            memory = "256M"
          }
          requests = {
            cpu = "0.25"
            # We are targetting the smallest Task size of 512Mb, so we subtract 256Mb from the
            # request/limit to ensure we can fit within that task
            memory = "256M"
          }
        }
        podAnnotations = {
          cluster_version = "${var.cluster_version}" # Do not override, use the default defined in variables.tf
        }
        # corefile = {} # @FIXME add lameduck 30 sec
        # @FIXME need to use container image from our ECR but there is no config option for it here
      })
    }
    
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {
      configuration_values = jsonencode({
        env = {
          # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
  }

  vpc_id                   = aws_vpc.main.id
  subnet_ids               = [ aws_subnet.private-af-south-1a.id,
      aws_subnet.private-af-south-1b.id,
      aws_subnet.public-af-south-1a.id,
      aws_subnet.public-af-south-1b.id
  ]
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
  enable_cluster_creator_admin_permissions = true

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

  fargate_profiles = {
    karpenter = {
      selectors = [
        { namespace = "karpenter" }
      ]
      subnet_ids = [aws_subnet.private-af-south-1a.id, aws_subnet.private-af-south-1b.id]
    }
    coredns = {
      selectors = [
        { namespace = "kube-system"
          labels = {
            "eks.amazonaws.com/component" = "coredns"
          }
        }
      ]
      subnet_ids = [aws_subnet.private-af-south-1a.id, aws_subnet.private-af-south-1b.id]
    }
  }

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