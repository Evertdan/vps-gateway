# DGETAHGO Infrastructure - Terraform Configuration

## Quick Start

```bash
# 1. Initialize Terraform
cd terraform/
terraform init

# 2. Plan changes
terraform plan

# 3. Apply changes
terraform apply

# 4. Destroy (if needed)
terraform destroy
```

## Structure

```
terraform/
├── main.tf              # Main configuration
├── variables.tf         # Input variables
├── terraform.tfvars     # Variable values (gitignored)
├── backend.tf           # State backend configuration
├── provider.tf          # Provider configuration
├── outputs.tf           # Output definitions
└── modules/
    ├── dns/            # Route 53 DNS module
    └── docker/         # Docker containers module
```

## Configuration

### Local Development

Uses local state file (`terraform.tfstate`)

### Production (S3 Backend)

Create `backend.tf`:
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

Then run:
```bash
terraform init
```

## Prerequisites

- AWS CLI configured with credentials
- Terraform >= 1.0
- SSH access to VPS (for Docker provider)

## Environment Variables

```bash
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export TF_VAR_server_ip="195.26.244.180"
```

## GitHub Actions

See `.github/workflows/terraform.yml` for automated deployments.

## Resources

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Docker Provider](https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs)
