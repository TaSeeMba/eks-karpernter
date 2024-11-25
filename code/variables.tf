
variable "cluster_name" {
  description = "The name of the EKS cluster."
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes `<major>.<minor>` version to use for the EKS cluster (i.e.: 1.21)"
  type        = string
  default     = "1.31"
}

# variable "create_vpc" {
#   description = "Flag to determine whether to create a VPC using the provided class. If set to false, manually provide vpc_id and subnet_ids."
#   type        = string
#   default     = true
# }


# variable "vpc_id" {
#   description = "ID of the VPC where the cluster security group will be provisioned."
#   type        = string
#   default     = ""
# }

# variable "private_subnets_ids" {
#   description = "A list of private subnet IDs."
#   type        = list(string)
#   default     = []
# }

# variable "public_subnets_ids" {
#   description = "A list of public subnet IDs."
#   type        = list(string)
#   default     = []
# }

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
  default     = {}
}

variable "karpenter_version" {
  description = "Version of Karpenter."
  default     = "1.0.8"
}

variable "region" {
  description = "Name of AWS region resources will be created in."
  default     = "eu-west-1"
}