# ============================================
# Variables - VPS Gateway Terraform
# ============================================

variable "aws_region" {
  description = "AWS Region for Route 53"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (production, staging, development)"
  type        = string
  default     = "production"
  
  validation {
    condition     = contains(["production", "staging", "development"], var.environment)
    error_message = "Environment must be production, staging, or development."
  }
}

variable "domain" {
  description = "Main domain name"
  type        = string
  default     = "dgetahgo.edu.mx"
}

variable "server_ip" {
  description = "VPS Server IP address"
  type        = string
  default     = "195.26.244.180"
}

variable "hosted_zone_id" {
  description = "Route 53 Hosted Zone ID for dgetahgo.edu.mx"
  type        = string
  default     = "Z0748356URLST7BWNN9D"
}

# ============================================
# Project Configuration
# ============================================

variable "subdomains" {
  description = <<EOT
Map of subdomains to create as A records.
Example:
{
  "n8n-prod" = {
    name    = "n8n-prod.vps1.dgetahgo.edu.mx"
    type    = "A"
    ttl     = 300
    records = ["195.26.244.180"]
  }
}
EOT
  type = map(object({
    name    = string
    type    = string
    ttl     = number
    records = list(string)
  }))
  default = {}
}

variable "acme_challenges" {
  description = <<EOT
Map of ACME challenge CNAME records for SSL certificates.
Key: _acme-challenge.subdomain.domain
Value: fulldomain from acme-dns
Example:
{
  "_acme-challenge.n8n.vps1.dgetahgo.edu.mx" = "uuid.auth.dgetahgo.edu.mx."
}
EOT
  type        = map(string)
  default     = {}
}

# ============================================
# Legacy Variables (for backward compatibility)
# ============================================

variable "acme_dns_subdomain" {
  description = "ACME-DNS fulldomain pattern (legacy)"
  type        = string
  default     = "auth.dgetahgo.edu.mx"
}
