# Infrastructure (Terraform)

Five independent Terraform stacks, each with its own S3 state file. Apply in order.

## Apply order

```text
01_s3bucket  →  02_vpc  →  04_eks  →  05_argocd
                    ↘
                     03_ecr  (parallel with 02_vpc or 04_eks — no dependency)
```

| Stack | Purpose | Depends on |
|-------|---------|------------|
| `01_s3bucket` | S3 backend for remote state | — (uses local state first) |
| `02_vpc` | VPC, subnets, Route 53, ACM cert | `01_s3bucket` (backend bucket name) |
| `03_ecr` | Container image repositories | `01_s3bucket` |
| `04_eks` | EKS cluster, nodes, EBS CSI | `02_vpc` (subnets via remote state) |
| `05_argocd` | ALB controller, external-dns, ArgoCD, monitoring, Fluent Bit → CloudWatch | `02_vpc`, `04_eks` |

## Commands (per stack)

```bash
cd projects/Infrastructure/<stack>
terraform init
terraform plan
terraform apply
```

After `04_eks`:

```bash
aws eks update-kubeconfig --region us-east-1 --name eks-cluster
```

## File layout (every stack)

| File | Contents |
|------|----------|
| `provider.tf` | `terraform` block, S3 backend, provider config |
| `variables.tf` | Input variables |
| `terraform.tfvars` | Your values (region, names, sizes) |
| `outputs.tf` | Values exported to other stacks or for humans |
| `remote_state.tf` | Reads another stack's state (stacks 04–05 only) |
| `*.tf` | Resources grouped by concern (e.g. `vpc.tf`, `cluster.tf`) |

## Remote state keys (S3)

| Stack | State key |
|-------|-----------|
| `02_vpc` | `02_vpc/terraform.tfstate` |
| `03_ecr` | `03_ecr/terraform.tfstate` |
| `04_eks` | `04_eks/terraform.tfstate` |
| `05_argocd` | `05_argocd/terraform.tfstate` |

Update the `bucket` in each stack's `provider.tf` and `tfstate_bucket` in `terraform.tfvars` after `01_s3bucket` apply.

## After `05_argocd`

- Platform HTTPS ingress: `kubectl apply -k gitops/ingress` (see `gitops/ingress/run.txt`)
- Boutique app: `gitops/deploy-argo-cd.ps1`
- Verify: `05_argocd/verify-commands.txt`

Ingress manifests and the boutique app are **not** managed by this Terraform — they live in `gitops/`.
