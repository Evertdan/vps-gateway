# ============================================
# Terraform - Infrastructure as Code
# VPS Gateway - DGETAHGO
# ============================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend remoto (opcional - descomentar para usar S3)
  # backend "s3" {
  #   bucket         = "dgetahgo-terraform-state"
  #   key            = "infrastructure/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "dgetahgo"
      Environment = var.environment
      ManagedBy   = "terraform"
      CreatedBy   = "github-actions"
      Repository  = "vps-gateway"
    }
  }
}

# ============================================
# Data Sources
# ============================================
data "aws_route53_zone" "main" {
  zone_id = var.hosted_zone_id
}

# ============================================
# DNS Records - Subdomains
# ============================================
resource "aws_route53_record" "subdomains" {
  for_each = var.subdomains

  zone_id = var.hosted_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = each.value.ttl
  records = each.value.records

  lifecycle {
    prevent_destroy = false
  }
}

# ============================================
# DNS Records - ACME Challenges (CNAME)
# ============================================
resource "aws_route53_record" "acme_challenges" {
  for_each = var.acme_challenges

  zone_id = var.hosted_zone_id
  name    = each.key
  type    = "CNAME"
  ttl     = 300
  records = [each.value]
}

# ============================================
# ACME-DNS Infrastructure Records
# ============================================
resource "aws_route53_record" "auth_a" {
  zone_id = var.hosted_zone_id
  name    = "auth.${var.domain}"
  type    = "A"
  ttl     = 300
  records = [var.server_ip]
}

resource "aws_route53_record" "ns1_auth_a" {
  zone_id = var.hosted_zone_id
  name    = "ns1.auth.${var.domain}"
  type    = "A"
  ttl     = 300
  records = [var.server_ip]
}

resource "aws_route53_record" "auth_ns" {
  zone_id = var.hosted_zone_id
  name    = "auth.${var.domain}"
  type    = "NS"
  ttl     = 300
  records = ["ns1.auth.${var.domain}."]
}

# ============================================
# Locals
# ============================================
locals {
  all_records = merge(
    { for k, v in aws_route53_record.subdomains : k => v.fqdn },
    { for k, v in aws_route53_record.acme_challenges : k => v.fqdn },
    {
      auth_a   = aws_route53_record.auth_a.fqdn
      ns1_auth = aws_route53_record.ns1_auth_a.fqdn
      auth_ns  = aws_route53_record.auth_ns.fqdn
    }
  )
}
