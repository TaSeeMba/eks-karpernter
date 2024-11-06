# EKS Karpernter Graviton

You've joined a new and growing startup.

The company wants to build its initial Kubernetes infrastructure on AWS. The team wants to leverage the latest autoscaling capabilities by Karpenter, as well as utilize Graviton instances for better price/performance

They have asked you if you can help create the following:

1. Terraform code that deploys an EKS cluster (whatever latest version is currently available) into an existing VPC

2. The terraform code should also deploy Karpenter with node pool(s) that can deploy both x86 and arm64 instances

3. Include a short readme that explains how to use the Terraform repo and that also demonstrates how an end-user (a developer from the company) can run a pod/deployment on x86 or Graviton instance inside the cluster.
