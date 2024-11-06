terraform {
 required_providers {
   aws = {
     source  = "hashicorp/aws"
     version = "~> 5.74.0"
   }
   kubernetes = {
    source  = "hashicorp/kubernetes"
    version = "~> 2.33.0"
   }
   kubectl = {
    source  = "alekc/kubectl"
    version = "~> 2.1"
   }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = merge(var.tags, {
    })
  }
}

provider "kubectl" {
  load_config_file       = false
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    env = {
      AWS_REGION  = var.region
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--role"]
    env = {
      AWS_REGION  = var.region
    }
  }
}

provider "helm" {
  alias = "eks_module_only"

  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
      env = {
        AWS_REGION  = var.region
      }
    }
  }
}