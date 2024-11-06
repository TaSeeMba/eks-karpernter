cluster_name = "eks"
cluster_version = "1.31"

vpc_id = "vpc-083802e6ba962b63b"
subnets_ids = ["subnet-08f180efa59541bae", "subnet-01b081c53503e37d1"]

karpenter_version = "v0.31.0"

tags = {
  "ProjectName"        = "EKS-DEMO"
  "Owner"              = "Tasimba Chirindo"
}