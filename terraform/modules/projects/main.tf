# Terraform module for project DNS management

variable "hosted_zone_id" {
  description = "Route 53 Hosted Zone ID"
  type        = string
}

variable "domain" {
  description = "Base domain"
  type        = string
  default     = "vps1.dgetahgo.edu.mx"
}

variable "server_ip" {
  description = "VPS Server IP"
  type        = string
  default     = "195.26.244.180"
}

variable "projects" {
  description = "Map of projects to create"
  type = map(object({
    name    = string
    ttl     = optional(number, 300)
  }))
  default = {}
}

# Create DNS records for projects
resource "aws_route53_record" "projects" {
  for_each = var.projects

  zone_id = var.hosted_zone_id
  name    = "${each.value.name}.${var.domain}"
  type    = "A"
  ttl     = each.value.ttl
  records = [var.server_ip]
}

# Output created records
output "project_domains" {
  description = "Created project domains"
  value = {
    for name, record in aws_route53_record.projects : name => record.fqdn
  }
}
