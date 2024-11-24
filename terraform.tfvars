cluster_name = "eks2411"
cluster_version = "1.31"
region = "af-south-1"

kubernetes_access_role = "arn:aws:iam::509399612661:role/bmt-admin-role"

vpc_id = "vpc-083802e6ba962b63b"
subnets_ids = ["subnet-01b081c53503e37d1", "subnet-024449dfd3fc828db", ]
public_subnets_ids = ["subnet-08f180efa59541bae", "subnet-06d8536e807e04f7e"]

karpenter_version = "1.0.8" 

tags = {
  "ProjectName"        = "EKS-DEMO"
  "Owner"              = "Tasimba Chirindo"
}