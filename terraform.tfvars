cluster_name = "eks2411eve"
cluster_version = "1.31"
region = "eu-west-1"

vpc_id = "vpc-083802e6ba962b63b"
private_subnets_ids = ["subnet-01b081c53503e37d1", "subnet-024449dfd3fc828db" ]
public_subnets_ids = ["subnet-08f180efa59541bae", "subnet-06d8536e807e04f7e"]

karpenter_version = "1.0.8" 

tags = {
  "ProjectName"        = "EKS-DEMO"
  "Owner"              = "Tasimba Chirindo"
  "Terraform"          = "true"
}