# =============================================================================
# AIOps Assistant - Bedrock Agent Teardown (PowerShell / Windows)
# =============================================================================
#
# Removes what deploy.ps1 created:
#   - 3 Bedrock action groups (fetch_logs, fetch_metrics, fetch_service_health)
#   - Bedrock Agent (aiops-assistant / Kira)
#   - Bedrock invoke permissions on the 3 Lambdas
#
# Does NOT delete:
#   - Lambda functions (you created those in the Console)
#   - IAM roles (use destroy-iam.ps1 for those)
#
# Before running:
#   - AWS CLI installed and logged in (aws configure)
#
# Run from this folder:
#   .\destroy-deploy.ps1
# =============================================================================

$REGION = "us-east-1"
$ACCOUNT_ID = aws sts get-caller-identity --query Account --output text
$AGENT_NAME = "aiops-assistant"

Write-Host ""
Write-Host "============================================="
Write-Host " AIOps - Bedrock Agent Teardown"
Write-Host " Account : $ACCOUNT_ID"
Write-Host " Region  : $REGION"
Write-Host "============================================="
Write-Host ""

# -----------------------------------------------------------------------------
# Step 1: Find the Bedrock Agent ID
# -----------------------------------------------------------------------------
Write-Host "Step 1: Find Bedrock Agent $AGENT_NAME"

$AGENT_ID = aws bedrock-agent list-agents `
    --region $REGION `
    --query "agentSummaries[?agentName=='$AGENT_NAME'].agentId | [0]" `
    --output text

Write-Host "  Agent ID: $AGENT_ID"

# -----------------------------------------------------------------------------
# Step 2: Remove action groups
# Action groups must be deleted before the agent.
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "Step 2: Remove action groups"

$logsGroupId = aws bedrock-agent list-agent-action-groups `
    --agent-id $AGENT_ID `
    --agent-version DRAFT `
    --region $REGION `
    --query "actionGroupSummaries[?actionGroupName=='fetch_logs'].actionGroupId | [0]" `
    --output text

aws bedrock-agent delete-agent-action-group `
    --agent-id $AGENT_ID `
    --agent-version DRAFT `
    --action-group-id $logsGroupId `
    --region $REGION `
    2>$null | Out-Null
Write-Host "  Removed: fetch_logs"

$metricsGroupId = aws bedrock-agent list-agent-action-groups `
    --agent-id $AGENT_ID `
    --agent-version DRAFT `
    --region $REGION `
    --query "actionGroupSummaries[?actionGroupName=='fetch_metrics'].actionGroupId | [0]" `
    --output text

aws bedrock-agent delete-agent-action-group `
    --agent-id $AGENT_ID `
    --agent-version DRAFT `
    --action-group-id $metricsGroupId `
    --region $REGION `
    2>$null | Out-Null
Write-Host "  Removed: fetch_metrics"

$healthGroupId = aws bedrock-agent list-agent-action-groups `
    --agent-id $AGENT_ID `
    --agent-version DRAFT `
    --region $REGION `
    --query "actionGroupSummaries[?actionGroupName=='fetch_service_health'].actionGroupId | [0]" `
    --output text

aws bedrock-agent delete-agent-action-group `
    --agent-id $AGENT_ID `
    --agent-version DRAFT `
    --action-group-id $healthGroupId `
    --region $REGION `
    2>$null | Out-Null
Write-Host "  Removed: fetch_service_health"

# -----------------------------------------------------------------------------
# Step 3: Remove Bedrock Agent
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "Step 3: Remove Bedrock Agent"

aws bedrock-agent delete-agent `
    --agent-id $AGENT_ID `
    --skip-resource-in-use-check `
    --region $REGION `
    2>$null | Out-Null
Write-Host "  Agent removed: $AGENT_NAME"

# -----------------------------------------------------------------------------
# Step 4: Remove Bedrock invoke permissions from Lambdas
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "Step 4: Remove Lambda Bedrock permissions"

aws lambda remove-permission `
    --function-name aiops-fetch-logs `
    --statement-id AllowBedrockInvoke `
    --region $REGION `
    2>$null | Out-Null
Write-Host "  Permission removed: aiops-fetch-logs"

aws lambda remove-permission `
    --function-name aiops-fetch-metrics `
    --statement-id AllowBedrockInvoke `
    --region $REGION `
    2>$null | Out-Null
Write-Host "  Permission removed: aiops-fetch-metrics"

aws lambda remove-permission `
    --function-name aiops-fetch-health `
    --statement-id AllowBedrockInvoke `
    --region $REGION `
    2>$null | Out-Null
Write-Host "  Permission removed: aiops-fetch-health"

# -----------------------------------------------------------------------------
# Step 5: Done
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "============================================="
Write-Host " Done!"
Write-Host "============================================="
Write-Host ""
Write-Host " deploy.ps1 resources have been removed."
Write-Host ""
Write-Host " Lambdas still exist (delete them in AWS Console if you want)."
Write-Host " IAM roles still exist (run destroy-iam.ps1 to remove those)."
Write-Host ""
