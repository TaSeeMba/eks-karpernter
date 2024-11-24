module "karpenter" {
  source                 = "terraform-aws-modules/eks/aws//modules/karpenter"
  version                = "~> 20.29"
  cluster_name           = module.eks.cluster_name

  enable_v1_permissions = true
  enable_pod_identity             = true
  create_pod_identity_association = true

  create_access_entry = true

  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    Additional = "${aws_iam_policy.additional.arn}"
  }
  
  create_instance_profile = true
  # create_iam_role = true
}

data "aws_iam_policy_document" "additional" {
  statement {
    sid = "AdditionalPolicies"
    actions = [
      "ec2:DescribeImages",
      "iam:GetInstanceProfile",
    ]
    resources = [
      "*"
    ]
  }
}

resource "aws_iam_policy" "additional" {
  name   = "KarpenterAdditionalPolicies"
  path   = "/"
  policy = data.aws_iam_policy_document.additional.json
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
  cleanup_on_fail     = true
  wait                = false

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
  #   value = module.karpenter.node_iam_role_arn
  #   # value = module.karpenter.instance_profile_arn
  # }

  # set {
  #   name  = "settings.interruptionQueue"
  #   value = module.karpenter.queue_name
  # }

  # set {
  #   name  = "podAnnotations.cluster_version"
  #   value = "${var.cluster_version}" # Do not override, use the default defined in variables.tf
  # }


  # values = [
  #   <<-EOT
  #   serviceAccount:
  #     name: ${module.karpenter.service_account}
  #   controller:
  #     env:
  #       - name: AWS_REGION
  #         value: ${var.region}
  #   settings:
  #     clusterName: ${module.eks.cluster_name}
  #     clusterEndpoint: ${module.eks.cluster_endpoint}
  #     interruptionQueue: ${module.karpenter.queue_name}
  #   EOT
  # ]

  # set {
  #   name  = "controller.env[0].name"
  #   value = "AWS_REGION"
  # }

  # set {
  #   name  = "controller.env[0].value"
  #   value = var.region
  # }

  # set {
  #   name  = "settings.clusterName"
  #   value = module.eks.cluster_name
  # }

  # set {
  #   name  = "settings.clusterEndpoint"
  #   value = module.eks.cluster_endpoint
  # }

  # set {
  #   name  = "serviceAccount.name"
  #   value = module.karpenter.service_account
  # }

  # set {
  #   name  = "logLevel"
  #   value = "debug"
  # }

  # set {
  #   name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
  #   # value = module.karpenter.node_iam_role_arn
  #   value = module.karpenter.instance_profile_arn
  # }

  # set {
  #   name  = "settings.interruptionQueue"
  #   value = module.karpenter.queue_name
  # }

  # set {
  #   name  = "settings.featureGates.driftEnabled"
  #   value = true
  # }

  # set {
  #   name  = "podAnnotations.cluster_version"
  #   value = "${var.cluster_version}" # Do not override, use the default defined in variables.tf
  # }

  depends_on = [ 
    module.eks,
    module.karpenter,
  ]
}


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
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_nodeclass_x86" {
  wait = true # We need to wait for destruction and finalizer
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: x86
    spec:
      amiFamily: AL2 # Amazon Linux 2
      role: "${module.karpenter.iam_role_name}" # replace with your cluster name
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: "${var.cluster_name}" # replace with your cluster name
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: "${var.cluster_name}" # replace with your cluster name
      amiSelectorTerms:
        - id: "ami-05fa457ef50e6fde6"
        - id: "ami-0a64b5f2d6b641017"
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}