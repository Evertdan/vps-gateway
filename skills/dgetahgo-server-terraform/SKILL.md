---
name: dgetahgo-server-terraform
description: >
  Terraform Infrastructure as Code for dgetahgo.edu.mx VPS and AWS resources.
  Trigger: When provisioning infrastructure, managing Terraform state, or automating infrastructure deployments.
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "1.0"
---

## When to Use

- Initial infrastructure provisioning
- Managing AWS Route 53 DNS records
- Docker container orchestration via Terraform
- Managing Terraform state and workspaces
- CI/CD pipeline with Terraform
- Infrastructure drift detection
- Multi-environment management (dev/staging/prod)

## Architecture

### Terraform Structure

```
terraform/
├── modules/
│   ├── dns/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── docker/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── vpn/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── environments/
│   ├── production/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   └── staging/
│       ├── main.tf
│       ├── variables.tf
│       └── terraform.tfvars
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars
├── backend.tf
└── provider.tf
```

### State Management

**Local State** (Development)
```hcl
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
```

**Remote State - S3** (Production)
```hcl
terraform {
  backend "s3" {
    bucket         = "dgetahgo-terraform-state"
    key            = "infrastructure/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

## Provider Configuration

### AWS Provider

```hcl
# provider.tf
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
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
    }
  }
}
```

### Docker Provider (Remote)

```hcl
provider "docker" {
  host = "ssh://usuario@195.26.244.180:22"
  
  ssh_opts = [
    "-o", "StrictHostKeyChecking=no",
    "-o", "UserKnownHostsFile=/dev/null"
  ]
}
```

## Core Resources

### Route 53 DNS Records

```hcl
# modules/dns/main.tf
resource "aws_route53_record" "subdomains" {
  for_each = var.subdomains
  
  zone_id = var.hosted_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = each.value.ttl
  records = each.value.records
}

# modules/dns/variables.tf
variable "hosted_zone_id" {
  description = "Route 53 Hosted Zone ID"
  type        = string
}

variable "subdomains" {
  description = "Map of DNS records"
  type = map(object({
    name    = string
    type    = string
    ttl     = number
    records = list(string)
  }))
}
```

### Docker Containers

```hcl
# modules/docker/main.tf
resource "docker_container" "openvpn" {
  name  = "openvpn"
  image = "kylemanna/openvpn:latest"
  
  capabilities {
    add = ["NET_ADMIN"]
  }
  
  ports {
    internal = 1194
    external = 1194
    protocol = "udp"
  }
  
  volumes {
    host_path      = "/opt/openvpn/data"
    container_path = "/etc/openvpn"
  }
  
  env = ["EASYRSA_BATCH=1"]
  
  restart = "always"
}

resource "docker_container" "n8n" {
  count = var.enable_n8n ? 1 : 0
  
  name  = "n8n"
  image = "n8nio/n8n:latest"
  
  ports {
    internal = 5678
    external = 5678
  }
  
  volumes {
    host_path      = "/opt/n8n/data"
    container_path = "/home/node/.n8n"
  }
  
  env = [
    "N8N_HOST=n8n.dgetahgo.edu.mx",
    "N8N_PORT=5678",
    "N8N_PROTOCOL=https",
    "WEBHOOK_URL=https://n8n.dgetahgo.edu.mx/",
    "GENERIC_TIMEZONE=America/Mexico_City",
    "TZ=America/Mexico_City"
  ]
  
  restart = "always"
}
```

## Variables

```hcl
# variables.tf
variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "domain" {
  description = "Main domain"
  type        = string
  default     = "dgetahgo.edu.mx"
}

variable "server_ip" {
  description = "VPS IP address"
  type        = string
  default     = "195.26.244.180"
}

variable "hosted_zone_id" {
  description = "Route 53 Hosted Zone ID"
  type        = string
}

variable "enable_n8n" {
  description = "Enable n8n container"
  type        = bool
  default     = false
}

variable "enable_openvpn" {
  description = "Enable OpenVPN container"
  type        = bool
  default     = true
}
```

## Environment Configuration

### Production

```hcl
# environments/production/terraform.tfvars
environment    = "production"
domain         = "dgetahgo.edu.mx"
server_ip      = "195.26.244.180"
hosted_zone_id = "Z0748356URLST7BWNN9D"
enable_n8n     = false
enable_openvpn = true

subdomains = {
  n8n = {
    name    = "n8n"
    type    = "A"
    ttl     = 300
    records = ["195.26.244.180"]
  }
  pbx = {
    name    = "pbx"
    type    = "A"
    ttl     = 300
    records = ["195.26.244.180"]
  }
  vps1 = {
    name    = "vps1"
    type    = "A"
    ttl     = 86400
    records = ["195.26.244.180"]
  }
}
```

## Commands

### Initialize

```bash
# Initialize with local state
cd terraform/
terraform init

# Initialize with S3 backend
terraform init -backend-config="bucket=dgetahgo-terraform-state"

# Upgrade providers
terraform init -upgrade
```

### Plan and Apply

```bash
# Plan changes
terraform plan

# Plan with specific var file
terraform plan -var-file="environments/production/terraform.tfvars"

# Apply changes
terraform apply

# Auto-approve (CI/CD)
terraform apply -auto-approve

# Target specific resource
terraform apply -target="docker_container.openvpn"
```

### State Management

```bash
# Show state
terraform show

# List resources
terraform state list

# Show specific resource
terraform state show 'docker_container.openvpn'

# Import existing resource
terraform import aws_route53_record.n8n Z0748356URLST7BWNN9D_n8n_A

# Remove resource from state
terraform state rm 'docker_container.n8n[0]'

# Refresh state
terraform refresh
```

### Workspaces

```bash
# Create workspace
terraform workspace new staging

# List workspaces
terraform workspace list

# Select workspace
terraform workspace select production

# Show current workspace
terraform workspace show
```

### Destroy

```bash
# Plan destroy
terraform plan -destroy

# Destroy all
terraform destroy

# Destroy specific resource
terraform destroy -target="docker_container.n8n"

# Auto-approve destroy (DANGER)
terraform destroy -auto-approve
```

## CI/CD Integration

### GitHub Actions Workflow

```yaml
# .github/workflows/terraform.yml
name: Terraform

on:
  push:
    branches: [main]
    paths: ['terraform/**']
  pull_request:
    paths: ['terraform/**']
  workflow_dispatch:

jobs:
  terraform:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: ./terraform
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.7.0"
          cli_config_credentials_token: ${{ secrets.TF_API_TOKEN }}
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: Terraform Format
        run: terraform fmt -check
      
      - name: Terraform Init
        run: terraform init
      
      - name: Terraform Validate
        run: terraform validate
      
      - name: Terraform Plan
        run: terraform plan -var-file="environments/production/terraform.tfvars"
        if: github.event_name == 'pull_request'
      
      - name: Terraform Apply
        run: terraform apply -auto-approve -var-file="environments/production/terraform.tfvars"
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
```

### Required Secrets

```yaml
# GitHub Secrets
AWS_ACCESS_KEY_ID:        # AWS Access Key
AWS_SECRET_ACCESS_KEY:    # AWS Secret Key
TF_API_TOKEN:             # Terraform Cloud Token (optional)
```

## Modules

### Using the DNS Module

```hcl
module "dns" {
  source = "./modules/dns"
  
  hosted_zone_id = var.hosted_zone_id
  subdomains     = var.subdomains
}

output "dns_records" {
  value = module.dns.record_fqdns
}
```

### Using the Docker Module

```hcl
module "containers" {
  source = "./modules/docker"
  
  enable_n8n     = var.enable_n8n
  enable_openvpn = var.enable_openvpn
}
```

## Best Practices

### 1. State Management
- Use remote state (S3) for production
- Enable state locking (DynamoDB)
- Never commit `.tfstate` files
- Use state encryption

### 2. Versioning
- Pin provider versions
- Use Terraform version constraints
- Tag module versions

### 3. Security
- Use variables for sensitive data
- Mark sensitive outputs
- Use AWS Secrets Manager or SSM Parameter Store
- Enable MFA for state operations

### 4. Organization
- Use modules for reusability
- Separate environments
- Consistent naming conventions
- Document all variables

## Troubleshooting

### State Lock Errors
```bash
# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

### Provider Authentication
```bash
# Verify AWS credentials
aws sts get-caller-identity

# Test Docker connection
docker -H ssh://usuario@195.26.244.180:22 ps
```

### Resource Drift
```bash
# Detect drift
terraform plan -detailed-exitcode

# Refresh state
terraform refresh
```

### Import Existing Resources
```bash
# Import Route 53 record
terraform import aws_route53_record.n8n Z0748356URLST7BWNN9D_n8n_A

# Import Docker container
terraform import docker_container.openvpn openvpn
```

## Outputs

```hcl
# outputs.tf
output "dns_records" {
  description = "Created DNS records"
  value       = module.dns.record_fqdns
}

output "openvpn_container_id" {
  description = "OpenVPN container ID"
  value       = docker_container.openvpn.id
}

output "server_ip" {
  description = "Server IP address"
  value       = var.server_ip
}
```

## Resources

- **Terraform Docs**: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- **Docker Provider**: https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs
- **AWS Route 53**: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record
- **Best Practices**: https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html
- **Project**: [PROJECT.md](../../PROJECT.md)
