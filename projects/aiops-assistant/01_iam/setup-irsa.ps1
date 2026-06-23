# IRSA for Kira UI pod — lets the pod call Bedrock InvokeAgent (no AWS keys in secrets)
# Run from this folder: .\setup-irsa.ps1
# Prerequisite: .env with BEDROCK_AGENT_ID, EKS cluster running

$REGION = "us-east-1"
$CLUSTER = "eks-cluster"
$ROLE_NAME = "aiops-kira-ui-role"
$SA_NAMESPACE = "aiops"
$SA_NAME = "kira-ui"

$ACCOUNT_ID = aws sts get-caller-identity --query Account --output text
$AppRoot = (Resolve-Path "$PSScriptRoot\..").Path
$ENV_FILE = Join-Path $AppRoot ".env"

Write-Host ""
Write-Host "============================================="
Write-Host " AIOps - Kira UI IRSA Setup"
Write-Host " Account : $ACCOUNT_ID"
Write-Host " Region  : $REGION"
Write-Host " Cluster : $CLUSTER"
Write-Host "============================================="
Write-Host ""

# Step 1: Read Bedrock agent ID from .env
Write-Host "Step 1: Reading .env"
$AGENT_ID = (Get-Content $ENV_FILE | Where-Object { $_ -match '^BEDROCK_AGENT_ID=' }) -replace '^BEDROCK_AGENT_ID=', '' -replace '\s', ''
($AGENT_ID.Length -gt 0) -or (Write-Error "Set BEDROCK_AGENT_ID in .env first." -ErrorAction Stop) | Out-Null
Write-Host "  Agent ID: $AGENT_ID"

# Step 2: EKS OIDC provider (for IRSA trust policy)
Write-Host "Step 2: EKS OIDC provider"
$OIDC_ISSUER = aws eks describe-cluster --name $CLUSTER --region $REGION --query "cluster.identity.oidc.issuer" --output text
($LASTEXITCODE -eq 0) -or (Write-Error "Cluster not found. Run aws eks update-kubeconfig first." -ErrorAction Stop) | Out-Null
$OIDC_ID = $OIDC_ISSUER -replace '^https://', ''
$OIDC_PROVIDER_ARN = "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_ID}"
Write-Host "  OIDC: $OIDC_ID"

# Step 3: IAM role trust policy — only the kira-ui ServiceAccount can assume this role
Write-Host "Step 3: IAM role $ROLE_NAME"
$trustPolicy = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "$OIDC_PROVIDER_ARN"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_ID}:aud": "sts.amazonaws.com",
          "${OIDC_ID}:sub": "system:serviceaccount:${SA_NAMESPACE}:${SA_NAME}"
        }
      }
    }
  ]
}
"@

$trustFile = "$env:TEMP\aiops-kira-ui-trust.json"
[System.IO.File]::WriteAllText($trustFile, $trustPolicy)

aws iam create-role `
    --role-name $ROLE_NAME `
    --assume-role-policy-document "file://$trustFile" `
    --description "IRSA role for Kira UI pod" `
    2>$null | Out-Null

aws iam update-assume-role-policy `
    --role-name $ROLE_NAME `
    --policy-document "file://$trustFile" `
    2>$null | Out-Null
Write-Host "  Role ready: $ROLE_NAME"

# Step 4: Inline policy — InvokeAgent on your Bedrock agent only
Write-Host "Step 4: Inline policy (bedrock:InvokeAgent)"
$inlinePolicy = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "InvokeBedrockAgent",
      "Effect": "Allow",
      "Action": "bedrock:InvokeAgent",
      "Resource": [
        "arn:aws:bedrock:${REGION}:${ACCOUNT_ID}:agent/${AGENT_ID}",
        "arn:aws:bedrock:${REGION}:${ACCOUNT_ID}:agent-alias/${AGENT_ID}/*"
      ]
    }
  ]
}
"@

$inlineFile = "$env:TEMP\aiops-kira-ui-inline.json"
[System.IO.File]::WriteAllText($inlineFile, $inlinePolicy)

aws iam put-role-policy `
    --role-name $ROLE_NAME `
    --policy-name "aiops-kira-ui-inline-policy" `
    --policy-document "file://$inlineFile"
Write-Host "  Inline policy applied: bedrock:InvokeAgent"

$ROLE_ARN = "arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

Write-Host ""
Write-Host "============================================="
Write-Host " Done!"
Write-Host "============================================="
Write-Host ""
Write-Host " Role ARN: $ROLE_ARN"
Write-Host " Next: ..\04_ui\deploy.ps1 (re-apply k8s.yml with ServiceAccount)"
Write-Host ""
