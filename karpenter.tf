# Install k
module "karpenter" {
  source = "terraform-aws-modules/eks/aws//modules/karpenter"

  cluster_name = module.eks.cluster_name

  create = true
  enable_irsa = true
  create_instance_profile = true

  irsa_oidc_provider_arn = module.eks.oidc_provider_arn

  # Attach additional IAM policies to the Karpenter node IAM role
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = var.tags
}

# provider "aws" {
#   region = "us-east-1"
#   alias  = "virginia"
# }

# data "aws_ecrpublic_authorization_token" "token" {
#   provider = aws.virginia
# }


resource "helm_release" "karpenter" {
  namespace           = "karpenter"
  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  # repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  # repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = var.karpenter_version
  create_namespace    = true

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
    name  = "logLevel"
    value = "debug"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter.iam_role_arn
  }

  set {
    name  = "settings.interruptionQueue"
    value = module.karpenter.queue_name
  }
}

#Create a NodeClass resource. For ease of demonstration, it uses the latest Amazon Linux 2 AMI
resource "kubectl_manifest" "karpenter_nodeclass" {
  wait = true 
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: karpenter
    spec:
      amiFamily: AL2
      instanceProfile: "${module.karpenter.instance_profile_name}" 
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: "${var.cluster_name}" 
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: "${var.cluster_name}"
      amiSelectorTerms:
        - alias: al2@latest
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}

# Create Nodepool for x86 architecture nodes
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
            name: karpenter
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

# Create Nodepool for gravition architecture nodes
resource "kubectl_manifest" "karpenter_nodepool_graviton" {
  wait = true
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: graviton
    spec:
      template:
        spec:
          requirements:
            - key: kubernetes.io/arch
              operator: In
              values: ["arm64"]
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
              key: graviton
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: karpenter
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