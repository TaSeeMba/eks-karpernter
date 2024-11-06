module "karpenter" {
  source                 = "terraform-aws-modules/eks/aws//modules/karpenter"
  version                = "19.17.2"
  cluster_name           = module.eks.cluster_name
  irsa_oidc_provider_arn = module.eks.oidc_provider_arn
  policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
}

resource "helm_release" "karpenter" {
  namespace           = "karpenter"
  create_namespace    = true
  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  chart               = "karpenter"
  version             = var.karpenter_version
  skip_crds           = true

  timeout = 600 # 600 == 10 minutes

  set {
    name  = "settings.aws.clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "settings.aws.clusterEndpoint"
    value = module.eks.cluster_endpoint
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter.irsa_arn
  }

  set {
    name  = "settings.aws.defaultInstanceProfile"
    value = module.karpenter.instance_profile_name
  }

  set {
    name  = "settings.aws.interruptionQueueName"
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

resource "helm_release" "karpenter_crd" {
  namespace           = "karpenter"
  create_namespace    = true
  name                = "karpenter-crd"
  repository          = "oci://public.ecr.aws/karpenter"
  chart               = "karpenter-crd"
  version             = var.karpenter_version

  timeout = 600 # 600 == 10 minutes

  
  depends_on = [ 
    module.eks,
    # module.eks.fargate_profiles,
    module.karpenter
  ]
}

################

resource "kubectl_manifest" "karpenter_node_template_graviton" {
  wait = true # We need to wait for destruction and finalizer

  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1alpha1
    kind: AWSNodeTemplate
    metadata:
      name: application
    spec:
      blockDeviceMappings:
        - deviceName: /dev/xvda
          ebs:
            volumeSize: 100Gi
            volumeType: gp3
            encrypted: true
            deleteOnTermination: true
      subnetSelector:
        karpenter.sh/discovery: ${var.cluster_name}
      securityGroupSelector:
        Name: "*eks-cluster-sg-${var.cluster_name}*"
      tags: ${jsonencode(merge(var.tags, {
        "karpenter.sh/discovery" = "${var.cluster_name}"
        }))}
  YAML
  depends_on = [
    helm_release.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_provisioner_graviton" {
  wait = true # We need to wait for destruction and finalizer
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1alpha5
    kind: Provisioner
    metadata:
      name: ${var.cluster_name}-graviton
    spec:
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values:
            - "on-demand"
        - key: "karpenter.k8s.aws/instance-generation"
          operator: Gt
          values: ["4"]
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: "karpenter.k8s.aws/instance-size"
          operator: In
          values: ["medium", "small", "micro"]
        - key: "karpenter.k8s.aws/instance-family"
          operator: In
          values: ["t4g", "m8g"]
      limits:
        resources:
          cpu: 1000
      providerRef:
        name: graviton
      taints:
        - effect: NoSchedule
          key: graviton
      consolidation:
        enabled: true
      ttlSecondsUntilExpired: 604800 # 7 days in seconds
  YAML

  depends_on = [
    kubectl_manifest.karpenter_node_template_graviton
  ]
}

################

resource "kubectl_manifest" "karpenter_node_template_x86" {
  wait = true # We need to wait for destruction and finalizer

  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1alpha1
    kind: AWSNodeTemplate
    metadata:
      name: application
    spec:
      blockDeviceMappings:
        - deviceName: /dev/xvda
          ebs:
            volumeSize: 100Gi
            volumeType: gp3
            encrypted: true
            deleteOnTermination: true
      subnetSelector:
        karpenter.sh/discovery: ${var.cluster_name}
      securityGroupSelector:
        Name: "*eks-cluster-sg-${var.cluster_name}*"
      tags: ${jsonencode(merge(var.tags, {
        "karpenter.sh/discovery" = "${var.cluster_name}"
        }))}
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_provisioner_x86" {
  wait = true # We need to wait for destruction and finalizer
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1alpha5
    kind: Provisioner
    metadata:
      name: ${var.cluster_name}-x86
    spec:
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values:
            - "on-demand"
        - key: "karpenter.k8s.aws/instance-generation"
          operator: Gt
          values: ["4"]
        - key: kubernetes.io/arch
          operator: NotIn
          values: ["amd64"]
        - key: "karpenter.k8s.aws/instance-size"
          operator: In
          values: ["medium", "small", "micro"]
        - key: "karpenter.k8s.aws/instance-family"
          operator: In
          values: ["t3", "m5"]
      limits:
        resources:
          cpu: 1000
      providerRef:
        name: x86
      taints:
        - effect: NoSchedule
          key: x86
      consolidation:
        enabled: true
      ttlSecondsUntilExpired: 604800 # 7 days in seconds
  YAML

  depends_on = [
    kubectl_manifest.karpenter_node_template_x86
  ]
}

################
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