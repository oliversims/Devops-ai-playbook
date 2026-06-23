# =============================================================================
# AIOps Assistant - Lambda Teardown (PowerShell / Windows)
# =============================================================================
#
# Removes what lambdas/deploy-lambdas.ps1 created:
#   - aiops-fetch-logs
#   - aiops-fetch-metrics
#   - aiops-fetch-health
#
# Also removes Bedrock invoke permissions if bedrock/deploy.ps1 was run.
# Does NOT delete IAM roles — run ..\iam\destroy-iam.ps1 for those.
#
# Run order (full teardown):
#   1. ..\bedrock\destroy-deploy.ps1
#   2. .\destroy-lambdas.ps1
#   3. ..\iam\destroy-iam.ps1
# =============================================================================

$Root = (Resolve-Path "$PSScriptRoot\..").Path
$LAMBDAS = @("aiops-fetch-logs", "aiops-fetch-metrics", "aiops-fetch-health")

# Load region from config.env
Get-Content "$Root\config.env" |
    Where-Object { $_ -notmatch '^\s*(#|$)' } |
    ForEach-Object { $n, $v = $_ -split '=', 2; Set-Variable -Name $n.Trim() -Value $v.Trim() -Scope Script }

$REGION = @($DEPLOY_REGION, "us-east-1") | Where-Object { $_ } | Select-Object -First 1
$ACCOUNT_ID = aws sts get-caller-identity --query Account --output text

Write-Host ""
Write-Host "============================================="
Write-Host " AIOps - Lambda Teardown"
Write-Host " Account : $ACCOUNT_ID"
Write-Host " Region  : $REGION"
Write-Host "============================================="
Write-Host ""

# -----------------------------------------------------------------------------
# Step 1: List functions
# -----------------------------------------------------------------------------
Write-Host "Step 1: Find Lambda functions"

aws lambda list-functions --region $REGION `
    --query "Functions[?starts_with(FunctionName, 'aiops-fetch')].FunctionName" `
    --output table

# -----------------------------------------------------------------------------
# Step 2: Remove Bedrock invoke permissions (added by bedrock/deploy.ps1)
# -----------------------------------------------------------------------------
Write-Host "Step 2: Remove Bedrock invoke permissions"

foreach ($func in $LAMBDAS) {
    aws lambda remove-permission `
        --function-name $func `
        --statement-id AllowBedrockInvoke `
        --region $REGION `
        2>$null | Out-Null
    Write-Host $(@("  Removed: $func", "  Not present: $func")[[int]($LASTEXITCODE -ne 0)])
}

# -----------------------------------------------------------------------------
# Step 3: Delete Lambda functions
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "Step 3: Delete Lambda functions"

foreach ($func in $LAMBDAS) {
    aws lambda delete-function --function-name $func --region $REGION 2>$null | Out-Null
    Write-Host $(@("  Deleted: $func", "  Not found: $func")[[int]($LASTEXITCODE -ne 0)])
}

# -----------------------------------------------------------------------------
# Step 4: Verify
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "Step 4: Verify"

$remaining = aws lambda list-functions --region $REGION `
    --query "Functions[?starts_with(FunctionName, 'aiops-fetch')].FunctionName" `
    --output text
$remaining = @($remaining) | Where-Object { $_ -and $_ -ne "None" } | Select-Object -First 1

Write-Host $(@("  WARNING: still exists: $remaining", "  Lambdas: all removed")[[int][string]::IsNullOrEmpty($remaining)])

Write-Host ""
Write-Host "============================================="
Write-Host " Done!"
Write-Host "============================================="
Write-Host ""
Write-Host " Lambda functions removed."
Write-Host " IAM roles still exist. Run: ..\iam\destroy-iam.ps1"
Write-Host ""

exit 0
