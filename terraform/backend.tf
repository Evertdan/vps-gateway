# Local backend (for development)
# For production, use S3 backend

terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

# Production S3 Backend (uncomment for production)
# terraform {
#   backend "s3" {
#     bucket         = "dgetahgo-terraform-state"
#     key            = "infrastructure/terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     dynamodb_table = "terraform-locks"
#   }
# }
