# =============================================================================
# Verify Bedrock Agent deploy — run after bedrock\deploy.ps1
# Run from: projects/aiops-assistant/bedrock
# =============================================================================

$Root = (Resolve-Path "$PSScriptRoot\..").Path
$AGENT_NAME = "aiops-assistant"
$ALIAS_ID = "TSTALIASID"

# -----------------------------------------------------------------------------
# Step 1: Load region from config.env
# -----------------------------------------------------------------------------
Get-Content "$Root\config.env" |
    Where-Object { $_ -notmatch '^\s*(#|$)' } |
    ForEach-Object { $n, $v = $_ -split '=', 2; Set-Variable -Name $n.Trim() -Value $v.Trim() -Scope Script }

$DEPLOY_REGION = @($DEPLOY_REGION, $AWS_REGION, "us-east-1") | Where-Object { $_ } | Select-Object -First 1

# -----------------------------------------------------------------------------
# Step 2: Find agent ID (created by deploy.ps1)
# -----------------------------------------------------------------------------
Write-Host "`nStep 2: Agent ID`n"
$AGENT_ID = aws bedrock-agent list-agents --region $DEPLOY_REGION `
    --query "agentSummaries[?agentName=='$AGENT_NAME'].agentId | [0]" --output text
Write-Host "  Agent ID : $AGENT_ID"
Write-Host "  Alias ID : $ALIAS_ID"

# -----------------------------------------------------------------------------
# Step 3: Agent status — expect PREPARED and model qwen.qwen3-32b-v1:0
# -----------------------------------------------------------------------------
Write-Host "`nStep 3: Agent details`n"
aws bedrock-agent get-agent --agent-id $AGENT_ID --region $DEPLOY_REGION `
    --query "agent.{Name:agentName,Status:agentStatus,Model:foundationModel}" `
    --output table

# -----------------------------------------------------------------------------
# Step 4: Action groups — expect fetch_logs, fetch_metrics, fetch_service_health
# If the table is empty, re-run deploy.ps1
# -----------------------------------------------------------------------------
Write-Host "`nStep 4: Action groups`n"
aws bedrock-agent list-agent-action-groups `
    --agent-id $AGENT_ID --agent-version DRAFT --region $DEPLOY_REGION `
    --query "actionGroupSummaries[].{Name:actionGroupName,State:actionGroupState}" `
    --output table

# -----------------------------------------------------------------------------
# Step 5: Agent alias — expect PREPARED and ACCEPT_INVOCATIONS
# -----------------------------------------------------------------------------
Write-Host "`nStep 5: Agent alias`n"
aws bedrock-agent list-agent-aliases --agent-id $AGENT_ID --region $DEPLOY_REGION `
    --query "agentAliasSummaries[].{Alias:agentAliasId,Name:agentAliasName,Status:agentAliasStatus,Invocations:aliasInvocationState}" `
    --output table

# -----------------------------------------------------------------------------
# Step 6: Agent IAM role
# -----------------------------------------------------------------------------
Write-Host "`nStep 6: Agent IAM role`n"
aws iam get-role --role-name aiops-bedrock-agent-role `
    --query "Role.{Name:RoleName,Arn:Arn}" --output table

# -----------------------------------------------------------------------------
# Step 7: Lambda Bedrock invoke permission (sample: aiops-fetch-logs)
# Expect Principal bedrock.amazonaws.com in the policy JSON
# -----------------------------------------------------------------------------
Write-Host "`nStep 7: Lambda invoke permission`n"
aws lambda get-policy --function-name aiops-fetch-logs --region $DEPLOY_REGION `
    --query Policy --output text

# -----------------------------------------------------------------------------
# Step 8: Live test — ask the agent a question (needs boto3, ~30-60s)
# Run once: pip install -r ..\requirements.txt
# -----------------------------------------------------------------------------
Write-Host "`nStep 8: Live agent test (wait ~30-60s)...`n"
$env:BEDROCK_AGENT_ID = $AGENT_ID
$env:AWS_REGION = $DEPLOY_REGION
$env:BEDROCK_AGENT_ALIAS_ID = $ALIAS_ID
py -3 "$PSScriptRoot\invoke-test.py" 2>&1

# -----------------------------------------------------------------------------
# Step 9: Values for Streamlit .env
# -----------------------------------------------------------------------------
Write-Host "`nStep 9: Copy into projects/aiops-assistant/.env`n"
Write-Host "  AWS_REGION=$DEPLOY_REGION"
Write-Host "  BEDROCK_AGENT_ID=$AGENT_ID"
Write-Host "  BEDROCK_AGENT_ALIAS_ID=$ALIAS_ID"
Write-Host ""
Write-Host "  Console: https://${DEPLOY_REGION}.console.aws.amazon.com/bedrock/home?region=${DEPLOY_REGION}#/agents/$AGENT_ID"
Write-Host "`nDone. Next: cd .. && streamlit run app.py`n"
