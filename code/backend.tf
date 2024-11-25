# terraform {
#   backend "s3" {
#     bucket         = "your-unique-bucket-name"   # name of your S3 bucket
#     key            = "path/to/your/terraform.tfstate"  
#     region         = "us-west-1" # name of AWS region
#     dynamodb_table = "terraform-locks"  # Optional, for state locking
#   }
# }
