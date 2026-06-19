# =============================================================================
# AIOps Assistant - IAM Teardown (PowerShell / Windows)
# =============================================================================
#
# Removes what setup-iam.ps1 created:
#   1. aiops-lambda-role
#   2. aiops-bedrock-agent-role
#
# Before running:
#   - AWS CLI installed and logged in (aws configure)
#   - Delete Lambda functions and the Bedrock Agent first (they block role deletion)
#
# Run from this folder:
#   .\destroy-iam.ps1
# =============================================================================

$REGION = "us-east-1"
$ACCOUNT_ID = aws sts get-caller-identity --query Account --output text

Write-Host ""
Write-Host "============================================="
Write-Host " AIOps - IAM Teardown"
Write-Host " Account : $ACCOUNT_ID"
Write-Host " Region  : $REGION"
Write-Host "============================================="
Write-Host ""

# -----------------------------------------------------------------------------
# Step 1: Remove aiops-lambda-role
# -----------------------------------------------------------------------------
$lambdaRoleName = "aiops-lambda-role"

Write-Host "Step 1: Remove $lambdaRoleName"

# Detach the managed policy added by setup-iam.ps1
aws iam detach-role-policy `
    --role-name $lambdaRoleName `
    --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" `
    2>$null | Out-Null
Write-Host "  Detached: AWSLambdaBasicExecutionRole"

# Remove the inline policy added by setup-iam.ps1
aws iam delete-role-policy `
    --role-name $lambdaRoleName `
    --policy-name "aiops-lambda-inline-policy" `
    2>$null | Out-Null
Write-Host "  Removed inline policy: aiops-lambda-inline-policy"

# Delete the role (safe to re-run — ignores error if role is already gone)
aws iam delete-role --role-name $lambdaRoleName 2>$null | Out-Null
Write-Host "  Role removed: $lambdaRoleName"

# -----------------------------------------------------------------------------
# Step 2: Remove aiops-bedrock-agent-role
# -----------------------------------------------------------------------------
$agentRoleName = "aiops-bedrock-agent-role"

Write-Host ""
Write-Host "Step 2: Remove $agentRoleName"

# Remove the inline policy added by setup-iam.ps1
aws iam delete-role-policy `
    --role-name $agentRoleName `
    --policy-name "aiops-bedrock-agent-inline-policy" `
    2>$null | Out-Null
Write-Host "  Removed inline policy: aiops-bedrock-agent-inline-policy"

# Delete the role (safe to re-run — ignores error if role is already gone)
aws iam delete-role --role-name $agentRoleName 2>$null | Out-Null
Write-Host "  Role removed: $agentRoleName"

# -----------------------------------------------------------------------------
# Step 3: Done
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "============================================="
Write-Host " Done!"
Write-Host "============================================="
Write-Host ""
Write-Host " IAM roles from setup-iam.ps1 have been removed."
Write-Host ""
Write-Host " If a role still exists, a Lambda or Bedrock Agent may still be using it."
Write-Host " Delete those resources in the AWS Console, then run this script again."
Write-Host ""
