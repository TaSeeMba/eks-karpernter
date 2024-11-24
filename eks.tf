# Create EKS cluster fron the latest available module as of 24/11/2024
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.29"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  # add cluster creator to admins to be able to administer cluster view AWS console and CLI
  enable_cluster_creator_admin_permissions = true

  # this setting is required to allow Karpenter pods to startup using PodIdentity auth
  enable_irsa = true

  cluster_addons = {
    coredns = {
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
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
    kube-proxy             = {}
    eks-pod-identity-agent = {
      most_recent = true
    }
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
  subnet_ids               = [ aws_subnet.private-eu-west-1a.id,
      aws_subnet.private-eu-west-1b.id,
      aws_subnet.public-eu-west-1a.id,
      aws_subnet.public-eu-west-1b.id
  ]

  fargate_profiles = {
    karpenter = {
      selectors = [
        { namespace = "karpenter" 
        }
      ]
      subnet_ids = [aws_subnet.private-eu-west-1a.id, aws_subnet.private-eu-west-1b.id]
    }
    coredns = {
      selectors = [
        { namespace = "kube-system"
          labels = {
            "eks.amazonaws.com/component" = "coredns"
          }
        }
      ]
      subnet_ids = [aws_subnet.private-eu-west-1a.id, aws_subnet.private-eu-west-1b.id]
    }
  }

  # add this tag to for karpenter NodeClass required field idesecurityGroupSelectorTerms. See: https://karpenter.sh/v1.0/concepts/nodeclasses/#specsecuritygroupselectorterms
  cluster_security_group_tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }

  tags = merge(
    { Name = var.cluster_name},
    var.tags
  )
}