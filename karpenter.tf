module "karpenter" {
  source                 = "terraform-aws-modules/eks/aws//modules/karpenter"
  version                = "20.29.0"
  cluster_name           = module.eks.cluster_name
  # irsa_oidc_provider_arn = module.eks.oidc_provider_arn

  enable_v1_permissions = true
  enable_pod_identity             = true
  create_pod_identity_association = true

  create_access_entry = true

  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    # AmazonSSMManagedEC2InstanceDefaultPolicy = "arn:aws:iam::aws:policy/AmazonSSMManagedEC2InstanceDefaultPolicy",
  }
}

provider "aws" {
  region = "us-east-1"
  alias  = "virginia"
}

data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}

data "helm_template" "karpenter" {
  repository          = "oci://public.ecr.aws/karpenter"
  chart               = "karpenter"
  version             = var.karpenter_version
  name                = "karpenter"
}

resource "kubectl_manifest" "karpenter_crds" {
  for_each        = {
    for crd in data.helm_template.karpenter.crds :
      yamldecode(crd).metadata.name => crd
  }
  yaml_body       = each.value
  apply_only      = true
}

resource "helm_release" "karpenter" {
  namespace           = "karpenter"
  create_namespace    = true
  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = var.karpenter_version
  skip_crds           = true
  cleanup_on_fail     = true

  timeout = 600 # 600 == 10 minutes

  set {
    name  = "controller.env[0].name"
    value = "AWS_REGION"
  }

  set {
    name  = "controller.env[0].value"
    value = var.region
  }

  set {
    name  = "settings.clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "settings.clusterEndpoint"
    value = module.eks.cluster_endpoint
  }

  set {
    name  = "serviceAccount.name"
    value = module.karpenter.service_account
  }

  set {
    name  = "logLevel"
    value = "debug"
  }

  # set {
  #   name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
  #   # value = module.karpenter.node_iam_role_arn
  #   value = module.karpenter.instance_profile_arn
  # }

  set {
    name  = "settings.interruptionQueue"
    value = module.karpenter.queue_name
  }

  set {
    name  = "settings.featureGates.driftEnabled"
    value = true
  }

  set {
    name  = "podAnnotations.cluster_version"
    value = "${var.cluster_version}" # Do not override, use the default defined in variables.tf
  }

  depends_on = [ 
    module.eks,
    module.karpenter,
  ]
}



# resource "helm_release" "karpenter_crd" {
#   namespace           = "karpenter"
#   create_namespace    = true
#   name                = "karpenter-crd"
#   repository          = "oci://public.ecr.aws/karpenter"
#   chart               = "karpenter-crd"
#   version             = var.karpenter_version

#   timeout = 600 # 600 == 10 minutes

  
#   depends_on = [ 
#     module.eks,
#     # module.eks.fargate_profiles,
#     module.karpenter
#   ]
# }



################

# resource "kubectl_manifest" "karpenter_node_template_graviton" {
#   wait = true # We need to wait for destruction and finalizer

#   yaml_body = <<-YAML
#     apiVersion: karpenter.k8s.aws/v1alpha1
#     kind: AWSNodeTemplate
#     metadata:
#       name: application
#     spec:
#       blockDeviceMappings:
#         - deviceName: /dev/xvda
#           ebs:
#             volumeSize: 100Gi
#             volumeType: gp3
#             encrypted: true
#             deleteOnTermination: true
#       subnetSelector:
#         karpenter.sh/discovery: ${var.cluster_name}
#       securityGroupSelector:
#         Name: "*eks-cluster-sg-${var.cluster_name}*"
#       tags: ${jsonencode(merge(var.tags, {
#         "karpenter.sh/discovery" = "${var.cluster_name}"
#         }))}
#   YAML
#   depends_on = [
#     helm_release.karpenter
#   ]
# }

# resource "kubectl_manifest" "karpenter_provisioner_graviton" {
#   wait = true # We need to wait for destruction and finalizer
#   yaml_body = <<-YAML
#     apiVersion: karpenter.sh/v1alpha5
#     kind: Provisioner
#     metadata:
#       name: ${var.cluster_name}-graviton
#     spec:
#       requirements:
#         - key: kubernetes.io/arch
#           operator: In
#           values: ["arm64"]
#       limits:
#         resources:
#           cpu: 30000
#           memory: "1000Gi"
#       providerRef:
#         name: eks11-graviton
#       taints:
#         - effect: NoSchedule
#           key: graviton
#       consolidation:
#         enabled: true
#   YAML

  # depends_on = [
  #   kubectl_manifest.karpenter_node_template_graviton
  # ]
#}

################

# resource "kubectl_manifest" "karpenter_node_template_x86" {
#   wait = true # We need to wait for destruction and finalizer

#   yaml_body = <<-YAML
#     apiVersion: karpenter.k8s.aws/v1alpha1
#     kind: AWSNodeTemplate
#     metadata:
#       name: application
#     spec:
#       blockDeviceMappings:
#         - deviceName: /dev/xvda
#           ebs:
#             volumeSize: 100Gi
#             volumeType: gp3
#             encrypted: true
#             deleteOnTermination: true
#       subnetSelector:
#         karpenter.sh/discovery: ${var.cluster_name}
#       securityGroupSelector:
#         Name: "*eks-cluster-sg-${var.cluster_name}*"
#       tags: ${jsonencode(merge(var.tags, {
#         "karpenter.sh/discovery" = "${var.cluster_name}"
#         }))}
#   YAML

#   depends_on = [
#     helm_release.karpenter
#   ]
# }

# resource "kubectl_manifest" "karpenter_provisioner_x86" {
#   wait = true # We need to wait for destruction and finalizer
#   yaml_body = <<-YAML
#     apiVersion: karpenter.sh/v1alpha5
#     kind: Provisioner
#     metadata:
#       name: ${var.cluster_name}-x86
#     spec:
#       requirements:
#         - key: kubernetes.io/arch
#           operator: In
#           values: ["amd64"]
#       limits:
#         resources:
#           cpu: 30000
#           memory: "1000Gi"
#       providerRef:
#         name: eks11-x86
#       taints:
#         - effect: NoSchedule
#           key: x86
#       consolidation:
#         enabled: true
#   YAML

#   # depends_on = [
#   #   kubectl_manifest.karpenter_node_template_x86
#   # ]
# }

###############
# resource "kubectl_manifest" "karpenter_node_template_default" {
#   wait = true # We need to wait for destruction and finalizer
#   yaml_body = <<-YAML
#     apiVersion: karpenter.k8s.aws/v1alpha1
#     kind: AWSNodeTemplate
#     metadata:
#       name: default
#     spec:
#       blockDeviceMappings:
#         - deviceName: /dev/xvda
#           ebs:
#             volumeSize: 50Gi
#             volumeType: gp3
#             encrypted: true
#       subnetSelector:
#         karpenter.sh/discovery: ${var.cluster_name}
#       securityGroupSelector:
#         Name: "*eks-cluster-sg-${var.cluster_name}*"
#       tags: ${jsonencode(merge(var.tags, {
#         "karpenter.sh/discovery" = "${var.cluster_name}"
#         }))}
#   YAML

#   depends_on = [
#     helm_release.karpenter
#   ]
# }

# resource "kubectl_manifest" "karpenter_provisioner_default" {
#   wait = true # We need to wait for destruction and finalizer
#   yaml_body = <<-YAML
#     apiVersion: karpenter.sh/v1alpha5
#     kind: Provisioner
#     metadata:
#       name: ${var.cluster_name}-default
#     spec:
#       requirements:
#         - key: karpenter.sh/capacity-type
#           operator: In
#           values:
#             - "on-demand"
#             # - "spot"
#         - key: "karpenter.k8s.aws/instance-generation"
#           operator: Gt
#           values: ["4"]
#         - key: kubernetes.io/arch
#           operator: In
#           values: ["amd64"]
#       limits:
#         resources:
#           cpu: 1000
#       providerRef:
#         name: default
#       consolidation:
#         enabled: true
#       ttlSecondsUntilExpired: 604800 # 7 days in seconds
#   YAML

#   depends_on = [
#     kubectl_manifest.karpenter_node_template_default
#   ]
# }

# resource "kubectl_manifest" "karpenter_provisioner_x86" {
#   wait = true # We need to wait for destruction and finalizer
#   yaml_body = <<-YAML
#     apiVersion: karpenter.sh/v1alpha5
#     kind: Provisioner
#     metadata:
#       name: ${var.cluster_name}-x86
#     spec:
#       requirements:
#         - key: kubernetes.io/arch
#           operator: In
#           values: ["amd64"]
#       limits:
#         resources:
#           cpu: 30000
#           memory: "1000Gi"
#       providerRef:
#         name: eks11-x86
#       taints:
#         - effect: NoSchedule
#           key: x86
#       consolidation:
#         enabled: true
#   YAML

#   # depends_on = [
#   #   kubectl_manifest.karpenter_node_template_x86
#   # ]
# }

resource "kubectl_manifest" "karpenter_nodepool_x86" {
  wait = true # We need to wait for destruction and finalizer
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: x86
    spec:
      template:
        spec:
          requirements:
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64"]
            - key: kubernetes.io/os
              operator: In
              values: ["linux"]
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["on-demand"]
            - key: karpenter.k8s.aws/instance-category
              operator: In
              values: ["c", "m", "r"]
            - key: karpenter.k8s.aws/instance-generation
              operator: Gt
              values: ["2"]
          taints:
            - effect: NoSchedule
              key: x86
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: x86
          expireAfter: 720h # 30 * 24h = 720h
      limits:
        cpu: 1000
      disruption:
        consolidationPolicy: WhenEmptyOrUnderutilized
        consolidateAfter: 1m  

    ---
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: x86
    spec:
      amiFamily: AL2 # Amazon Linux 2
      role: "KarpenterNodeRole-${var.cluster_name}" # replace with your cluster name
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: "${var.cluster_name}" # replace with your cluster name
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: "${var.cluster_name}" # replace with your cluster name
      amiSelectorTerms:
        - id: "ami-0ff2e202d965566b8"
        - id: "ami-07def89de22855fa8"
    #   - id: "ami-0e1a39a761483c601" # <- GPU Optimized AMD AMI 
    #   - name: "amazon-eks-node-1.31-*" # <- automatically upgrade when a new AL2 EKS Optimized AMI is released. This is unsafe for production workloads. Validate AMIs in lower environments before deploying them to production.
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}