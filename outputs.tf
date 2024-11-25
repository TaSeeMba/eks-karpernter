output "eks_cluster_endpoint" {
  description = "Kubernetes cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "karpenter_iam_role_arn" {
  description = "The Amazon Resource Name (ARN) specifying the Karpenter controller IAM role"
  value       = module.karpenter.iam_role_arn
}