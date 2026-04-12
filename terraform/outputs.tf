# ============================================
# Outputs - VPS Gateway Terraform
# ============================================

output "domain" {
  description = "Main domain configured"
  value       = var.domain
}

output "server_ip" {
  description = "VPS Server IP"
  value       = var.server_ip
}

output "hosted_zone_id" {
  description = "Route 53 Hosted Zone ID"
  value       = var.hosted_zone_id
}

output "dns_records" {
  description = "All created DNS records"
  value       = local.all_records
}

output "created_subdomains" {
  description = "List of created subdomain FQDNs"
  value       = values(aws_route53_record.subdomains)[*].fqdn
}

output "created_acme_challenges" {
  description = "List of created ACME challenge CNAMEs"
  value       = keys(aws_route53_record.acme_challenges)
}

output "acme_dns_endpoint" {
  description = "ACME-DNS API endpoint"
  value       = "https://auth.${var.domain}:8444"
}

output "project_summary" {
  description = "Summary of created resources"
  value = {
    subdomains_created = length(aws_route53_record.subdomains)
    acme_challenges    = length(aws_route53_record.acme_challenges)
    domain             = var.domain
    server_ip          = var.server_ip
    environment        = var.environment
  }
}

output "next_steps" {
  description = "Instructions for next steps"
  value       = <<EOT

✅ DNS Records Created Successfully!

Next steps:
1. Run GitHub Actions workflow 'Create Project - VPS Gateway'
2. Configure VPN client with the downloaded .ovpn file
3. Start your local service on the configured port
4. Access via: https://<subdomain>.${var.domain}

EOT
}
