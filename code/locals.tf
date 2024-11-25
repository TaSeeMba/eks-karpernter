data "aws_availability_zones" "available" {}

locals {
  vpc_cidr = "10.0.0.0/16"
  vpc_name = "${var.cluster_name}-vpc"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  #   public_subnets_ids = var.create_vpc == true ? module.vpc[0].public_subnets : var.public_subnets_ids
  #   private_subnets_ids = var.create_vpc == true ? module.vpc[0].private_subnets : var.private_subnets_ids
  #   intra_subnets_ids = var.create_vpc == true ? module.vpc[0].intra_subnets : var.public_subnets_ids
  #   vpc_id = var.create_vpc == true ? module.vpc[0].vpc_id : var.vpc_id

}
