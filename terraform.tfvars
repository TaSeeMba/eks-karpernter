cluster_name = "eks11"
cluster_version = "1.31"

kubernetes_access_role = "arn:aws:iam::509399612661:role/bmt-admin-role"

vpc_id = "vpc-083802e6ba962b63b"
subnets_ids = ["subnet-01b081c53503e37d1", "subnet-024449dfd3fc828db", ]
public_subnets_ids = ["subnet-08f180efa59541bae", "subnet-06d8536e807e04f7e"]

karpenter_version = "v0.31.0"

tags = {
  "ProjectName"        = "EKS-DEMO"
  "Owner"              = "Tasimba Chirindo"
}