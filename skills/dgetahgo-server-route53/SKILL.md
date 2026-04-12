---
name: dgetahgo-server-route53
description: >
  AWS Route 53 DNS management for dgetahgo.edu.mx domain.
  Trigger: When managing DNS records, configuring ACME CNAMEs, or validating DNS propagation.
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "1.0"
---

## When to Use

- Creating/modifying DNS records in Route 53
- Setting up ACME-DNS CNAME records
- Validating DNS propagation
- Managing hosted zones
- Debugging DNS resolution issues

## Critical Patterns

### Hosted Zone

- **Domain**: `dgetahgo.edu.mx`
- **Zone ID**: `Z0748356URLST7BWNN9D`
- **Account**: `307946672464`
- **Region**: `us-east-1` (global service)

### Required Record Structure

#### Static A Records
```
Name: n8n (or n8n.dgetahgo.edu.mx. with trailing dot)
Type: A
Value: 195.26.244.180
TTL: 300 (or 3600/86400 for production)
```

#### ACME Challenge CNAME Records
```
Name: _acme-challenge.n8n
Type: CNAME
Value: <uuid>.auth.dgetahgo.edu.mx.
TTL: 300
```

**IMPORTANT**: CNAME value MUST end with trailing dot (absolute DNS name)

#### ACME-DNS Infrastructure Records
```
Name: auth
Type: A
Value: 195.26.244.180
TTL: 300

Name: ns1.auth
Type: A
Value: 195.26.244.180
TTL: 300

Name: auth
Type: NS
Value: ns1.auth.dgetahgo.edu.mx.
TTL: 300
```

### DNS Propagation Times

| TTL | Expected Propagation |
|-----|---------------------|
| 300 (5 min) | 5-10 minutes |
| 3600 (1 hour) | 1-2 hours |
| 86400 (1 day) | 24-48 hours |

Use shorter TTLs for testing, longer for production stability.

## Commands

### List hosted zones
```bash
aws route53 list-hosted-zones
```

### List records in zone
```bash
aws route53 list-resource-record-sets \
  --hosted-zone-id Z0748356URLST7BWNN9D
```

### Create A record
```bash
aws route53 change-resource-record-sets \
  --hosted-zone-id Z0748356URLST7BWNN9D \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "subdomain.dgetahgo.edu.mx",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [{"Value": "195.26.244.180"}]
      }
    }]
  }'
```

### Create CNAME for ACME
```bash
aws route53 change-resource-record-sets \
  --hosted-zone-id Z0748356URLST7BWNN9D \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "_acme-challenge.n8n.dgetahgo.edu.mx",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "uuid.auth.dgetahgo.edu.mx."}]
      }
    }]
  }'
```

### Validate DNS propagation
```bash
# Check A record
dig +short n8n.dgetahgo.edu.mx @8.8.8.8

# Check CNAME
dig +short _acme-challenge.n8n.dgetahgo.edu.mx CNAME @8.8.8.8

# Check from multiple resolvers
for r in 8.8.8.8 1.1.1.1 9.9.9.9; do
  dig @$r A n8n.dgetahgo.edu.mx
done
```

## Code Examples

### Create record set programmatically
```python
import boto3

client = boto3.client('route53')

response = client.change_resource_record_sets(
    HostedZoneId='Z0748356URLST7BWNN9D',
    ChangeBatch={
        'Comment': 'Add subdomain',
        'Changes': [{
            'Action': 'CREATE',
            'ResourceRecordSet': {
                'Name': 'subdomain.dgetahgo.edu.mx',
                'Type': 'A',
                'TTL': 300,
                'ResourceRecords': [{'Value': '195.26.244.180'}]
            }
        }]
    }
)
```

### Check record existence
```bash
aws route53 list-resource-record-sets \
  --hosted-zone-id Z0748356URLST7BWNN9D \
  --query 'ResourceRecordSets[?Name==`n8n.dgetahgo.edu.mx.`]'
```

## Troubleshooting

### "No hosted zone found"
- Wrong Zone ID
- Different AWS account
- Check with: `aws route53 list-hosted-zones`

### "InvalidChangeBatch: already exists"
- Record already created
- Use UPSERT instead of CREATE
- Or delete first, then create

### DNS not propagating
- TTL too long (wait longer)
- Cached by resolver
- Check with multiple resolvers: `dig @8.8.8.8`, `dig @1.1.1.1`

### CNAME not working for ACME
- Missing trailing dot in value
- Wrong target domain
- ACME-DNS not responding

## Resources

- **AWS CLI Route53**: https://docs.aws.amazon.com/cli/latest/reference/route53/
- **Route 53 Docs**: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/
- **Project**: [PROJECT.md](../../PROJECT.md)
