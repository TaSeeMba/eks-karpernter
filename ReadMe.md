# EKS Karpernter Graviton

You've joined a new and growing startup.

The company wants to build its initial Kubernetes infrastructure on AWS. The team wants to leverage the latest autoscaling capabilities by Karpenter, as well as utilize Graviton instances for better price/performance

They have asked you if you can help create the following:

1. Terraform code that deploys an EKS cluster (whatever latest version is currently available) into an existing VPC

2. The terraform code should also deploy Karpenter with node pool(s) that can deploy both x86 and arm64 instances

3. Include a short readme that explains how to use the Terraform repo and that also demonstrates how an end-user (a developer from the company) can run a pod/deployment on x86 or Graviton instance inside the cluster.

# Solution Overview

The solution used is based on running the Karpenter controller on AWS Fargate. The reasons are: its faster to spin up (versus EC2 managed node groups), automatic scaling and simplified management. 

To simplify the whole process (see gotchas section), I have created a vpc with the solution - however, the solution can be easily parameterised to deploy into an existing vpc by using terraform input variables. 

Once the cluster is provisioned, Karpenter and its dependencies are installed. We install Karpenter CRDs separately. After Karpenter is installed, we create a [NodeClass](https://karpenter.sh/v1.0/concepts/nodeclasses/) and [NodePools](https://karpenter.sh/v1.0/concepts/nodepools/) for the x86 and graviton nodes. We use taints to mark the two node types. To select which pods can be scheduled on the either type of nodes, we apply tolerations on those pods to match the keys on the node taints. 

## Contents

This repo contains terraform code and k8s manifests file. For ease of demonstration, this code creates a vpc however if there is an existing vpc, see instructions at the bottom of the page.

The terraform code does the following:
- Creates a VPC
- Creates an EKS cluster
- Assigns the required tags required by EKS and Karpenter for services to
- Installs IAM required by Karpenter and an SQS queue . [See](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest/submodules/karpenter)
- Installs Karpenter using terraform helm provider

The folder `/k8s` contains test kubernetes manifests for launching test pods on either x86 and graviton based instances.

## Getting Started

1. Ensure you have an AWS account and necessary rights to create an IAM user for terraform. Also ensure you have installed the latest AWS CLI on your machine.

2. Create an IAM user for terraform. For ease of demonstration, give the user Administrator rights. Then, create security credentials for the user (Access Key and Secret Key). When you go to live, remember to grant only permissions required.

3. Create an S3 bucket and a DynamoDB table for storing state in the desired AWS region. [See](https://developer.hashicorp.com/terraform/language/backend/s3) if you intend to use remote state for your Terraform infra.

4. Setup your AWS CLI. 
```
aws configure sso
```

5. Uncomment and modify backend.tf file with the details from step 3 if you will be using remote state.

6. Run 

```
terraform init --reconfigure

terraform plan

terraform apply
```

7. After terraform has successfully run, configure your kube context
```
aws eks update-kubeconfig --region REGION --name CLUSTER_NAME
```

8. Verify whether the installation was successful:

```
# check if coredns pods are running
kubectl get po -n kube-system

# check if karpenter pods are running
kubectl get po -n karpenter
kubectl logs -n karpenter POD_NAME -f

# check whether the NodeClass and NodePool resources are successfully created and in a ready state
kubectl get ec2nodeclass
kubectl get nodepool

```

9. Change directory into `/k8s` folder and install the test deployments. Then, check the nodes to pick the architecture of the nodes the deployments are spun.
```
cd k8s/
# install the test manifests
kubectl apply -f .
# verify that the pods get into a running state
kubectl get po
# After pods are running, you can use the info from KERNEL-VERSION to check type of node (arm64 or amd64) the pods are running from
kubectl get node -o wide
```

## Gotchas

1. The subnets need to have correct tags for EKS otherwise coredns won't start.
2. When using Fargate, pods need to be scheduled in private subnets that do not have a direct route to an internet gateway. So, you need a NAT gateway which introduces additional costs.
3. By default, CRDs are installed during intial helm chart installation however not updated when Karpenter versions are upgraded. Hence the solution introduced for CRDs.
4. The karpenter module requires additional parameters (lines 7-11) for the Karpernter pods to correctly come up using PodIdentity. Without these, you will experience permissions related errors when the pods are coming up. This info is not available in the existing docs nor articles available for v1 Karpenter.