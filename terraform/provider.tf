terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "dgetahgo"
      Environment = var.environment
      ManagedBy   = "terraform"
      CreatedBy   = "infrastructure-team"
    }
  }
}
