# =============================================================================
# AIOps Assistant - Bedrock Agent Teardown (PowerShell / Windows)
# =============================================================================
#
# Removes what bedrock/deploy.ps1 created:
#   - Bedrock Agent (aiops-assistant) + aliases + action groups
#   - Bedrock invoke permissions on the 3 Lambdas
#
# Does NOT delete Lambda functions or IAM roles.
# Run from this folder: .\destroy-deploy.ps1
# =============================================================================

$Root = (Resolve-Path "$PSScriptRoot\..").Path
$AGENT_NAME = "aiops-assistant"
$LAMBDAS = @("aiops-fetch-logs", "aiops-fetch-metrics", "aiops-fetch-health")

# Load region from config.env (same as other scripts)
Get-Content "$Root\config.env" |
    Where-Object { $_ -notmatch '^\s*(#|$)' } |
    ForEach-Object { $n, $v = $_ -split '=', 2; Set-Variable -Name $n.Trim() -Value $v.Trim() -Scope Script }

$REGION = @($DEPLOY_REGION, "us-east-1") | Where-Object { $_ } | Select-Object -First 1
$ACCOUNT_ID = aws sts get-caller-identity --query Account --output text

Write-Host ""
Write-Host "============================================="
Write-Host " AIOps - Bedrock Agent Teardown"
Write-Host " Account : $ACCOUNT_ID"
Write-Host " Region  : $REGION"
Write-Host "============================================="
Write-Host ""

# -----------------------------------------------------------------------------
# Step 1: Find agent
# -----------------------------------------------------------------------------
Write-Host "Step 1: Find Bedrock Agent $AGENT_NAME"

$AGENT_ID = aws bedrock-agent list-agents `
    --region $REGION `
    --query "agentSummaries[?agentName=='$AGENT_NAME'].agentId | [0]" `
    --output text

$AGENT_ID = @($AGENT_ID) | Where-Object { $_ -and $_ -ne "None" } | Select-Object -First 1

Write-Host $(@("  Agent ID: $AGENT_ID", "  Not found (already removed)")[[int][string]::IsNullOrEmpty($AGENT_ID)])

# -----------------------------------------------------------------------------
# Step 2: Delete agent (aliases + action groups are removed with it)
# -----------------------------------------------------------------------------
# delete-agent-action-group fails while ENABLED — delete-agent removes all in one step.
Write-Host ""
Write-Host "Step 2: Delete Bedrock Agent"
Write-Host $(@("  Deleting agent $AGENT_ID...", "  Skipped (no agent)")[[int][string]::IsNullOrEmpty($AGENT_ID)])

$null = $AGENT_ID -and (aws bedrock-agent delete-agent `
    --agent-id $AGENT_ID `
    --skip-resource-in-use-check `
    --region $REGION `
    --query agentStatus `
    --output text)

# Wait until gone (usually 10-20s)
$null = $AGENT_ID -and $(do {
    Start-Sleep -Seconds 5
    $check = aws bedrock-agent list-agents --region $REGION `
        --query "agentSummaries[?agentName=='$AGENT_NAME'].agentId | [0]" --output text
    $check = @($check) | Where-Object { $_ -and $_ -ne "None" } | Select-Object -First 1
    Write-Host $(@("  Still deleting...", "  Agent removed")[[int][string]::IsNullOrEmpty($check)])
} until ([string]::IsNullOrEmpty($check)))

# -----------------------------------------------------------------------------
# Step 3: Remove Lambda Bedrock invoke permissions (added by deploy.ps1)
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "Step 3: Remove Lambda Bedrock permissions"

foreach ($func in $LAMBDAS) {
    aws lambda remove-permission `
        --function-name $func `
        --statement-id AllowBedrockInvoke `
        --region $REGION `
        2>$null | Out-Null
    Write-Host $(@("  Removed: $func", "  Not present: $func")[[int]($LASTEXITCODE -ne 0)])
}

# -----------------------------------------------------------------------------
# Step 4: Verify
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "Step 4: Verify"

$remaining = aws bedrock-agent list-agents --region $REGION `
    --query "agentSummaries[?agentName=='$AGENT_NAME'].agentId | [0]" --output text
$remaining = @($remaining) | Where-Object { $_ -and $_ -ne "None" } | Select-Object -First 1

Write-Host $(@("  WARNING: agent still exists: $remaining", "  Agents: none named $AGENT_NAME")[[int][string]::IsNullOrEmpty($remaining)])

aws lambda get-policy --function-name aiops-fetch-logs --region $REGION 2>$null | Out-Null
Write-Host $(@("  WARNING: aiops-fetch-logs still has a resource policy", "  Lambda permissions: removed")[[int]($LASTEXITCODE -ne 0)])

Write-Host ""
Write-Host "============================================="
Write-Host " Done!"
Write-Host "============================================="
Write-Host ""
Write-Host " Bedrock Agent removed."
Write-Host " Lambdas still exist. IAM roles: run ..\iam\destroy-iam.ps1"
Write-Host ""

exit 0
