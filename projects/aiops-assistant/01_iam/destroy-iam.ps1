# AIOps IAM teardown — removes roles created by setup-iam.ps1.
# Delete Lambdas and Bedrock Agent first, then run: .\destroy-iam.ps1

$REGION = "us-east-1"
$ACCOUNT_ID = aws sts get-caller-identity --query Account --output text

Write-Host ""
Write-Host "============================================="
Write-Host " AIOps - IAM Teardown"
Write-Host " Account : $ACCOUNT_ID"
Write-Host " Region  : $REGION"
Write-Host "============================================="
Write-Host ""

$lambdaRoleName = "aiops-lambda-role"

Write-Host "Step 1: Remove $lambdaRoleName"

aws iam detach-role-policy `
    --role-name $lambdaRoleName `
    --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" `
    2>$null | Out-Null
Write-Host "  Detached: AWSLambdaBasicExecutionRole"

aws iam delete-role-policy `
    --role-name $lambdaRoleName `
    --policy-name "aiops-lambda-inline-policy" `
    2>$null | Out-Null
Write-Host "  Removed inline policy: aiops-lambda-inline-policy"

aws iam delete-role --role-name $lambdaRoleName 2>$null | Out-Null
Write-Host "  Role removed: $lambdaRoleName"

$agentRoleName = "aiops-bedrock-agent-role"

Write-Host ""
Write-Host "Step 2: Remove $agentRoleName"

aws iam delete-role-policy `
    --role-name $agentRoleName `
    --policy-name "aiops-bedrock-agent-inline-policy" `
    2>$null | Out-Null
Write-Host "  Removed inline policy: aiops-bedrock-agent-inline-policy"

aws iam delete-role --role-name $agentRoleName 2>$null | Out-Null
Write-Host "  Role removed: $agentRoleName"

Write-Host ""
Write-Host "============================================="
Write-Host " Done!"
Write-Host "============================================="
Write-Host ""
Write-Host " If a role still exists, a Lambda or Bedrock Agent may still be using it."
Write-Host ""
