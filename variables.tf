
variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes <major>.<minor> version to use for the EKS cluster (i.e.: 1.21)"
  type = string
  default = "1.28"
}

variable "kubernetes_access_role" {
  description = "Role for accessing kubernetes"
  type = string
  default = ""
}

variable "vpc_id" {
  description = "ID of the VPC where the cluster security group will be provisioned"
  type        = string
}
variable "subnets_ids" {
  description = "A list of subnet IDs where the nodes/node groups will be provisioned"
  type        = list(string)
}

variable "public_subnets_ids" {
  description = "A list of subnet IDs where the nodes/node groups will be provisioned"
  type        = list(string)
}


variable "node_instance_types" {
  description = "List of instance types for the node pool"
  type        = list(string)
  default     = ["m5.large", "c6g.large"]  # Example instance types (x86 and arm64)
}

variable "aws_auth_roles" {
  description = "List of role maps to add to the aws-auth configmap"
  type        = list(any)
  default     = []
}
variable "aws_auth_users" {
  description = "List of user maps to add to the aws-auth configmap"
  type        = list(any)
  default     = []
}


variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
}

variable "karpenter_version" {
  default = "v0.31.0"
}

variable "region" {
  default = "af-south-1"
}