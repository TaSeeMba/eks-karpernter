cluster_name    = "eksdemo"
cluster_version = "1.31"
region          = "eu-west-1"

# create_vpc = true

karpenter_version = "1.0.8"

tags = {
  "ProjectName" = "EKS-DEMO"
  "Owner"       = "Tasimba Chirindo"
  "Terraform"   = "true"
}