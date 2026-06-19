# =============================================================================
# AIOps Assistant - Bedrock Agent Deploy (PowerShell / Windows)
# =============================================================================
#
# What this script does:
#   - Configures the 3 Lambda functions
#   - Creates the Bedrock Agent (aiops-assistant / Kira)
#   - Adds 3 action groups (logs, metrics, health)
#   - Prepares the agent
#
# Run AFTER setup-iam.ps1 and after creating the 3 Lambdas in AWS Console.
#
# Before running:
#   - AWS CLI installed and logged in (aws configure)
#   - Run .\setup-iam.ps1
#   - Create Lambdas: aiops-fetch-logs, aiops-fetch-metrics, aiops-fetch-health
#     (paste code from the lambda/ folder)
#
# Run from this folder:
#   .\deploy.ps1
# =============================================================================

$REGION = "us-east-1"
$ACCOUNT_ID = aws sts get-caller-identity --query Account --output text
$AGENT_ROLE_NAME = "aiops-bedrock-agent-role"
$AGENT_ROLE_ARN = "arn:aws:iam::${ACCOUNT_ID}:role/${AGENT_ROLE_NAME}"
$AGENT_NAME = "aiops-assistant"

Write-Host ""
Write-Host "============================================="
Write-Host " AIOps - Bedrock Agent Deploy"
Write-Host " Account : $ACCOUNT_ID"
Write-Host " Region  : $REGION"
Write-Host "============================================="
Write-Host ""

# -----------------------------------------------------------------------------
# Step 1: Check Lambdas and IAM role exist
# If a command fails here, create that resource first, then re-run.
# -----------------------------------------------------------------------------
Write-Host "Step 1: Pre-flight checks"

aws lambda get-function --function-name aiops-fetch-logs --region $REGION | Out-Null
Write-Host "  Lambda ready: aiops-fetch-logs"

aws lambda get-function --function-name aiops-fetch-metrics --region $REGION | Out-Null
Write-Host "  Lambda ready: aiops-fetch-metrics"

aws lambda get-function --function-name aiops-fetch-health --region $REGION | Out-Null
Write-Host "  Lambda ready: aiops-fetch-health"

aws iam get-role --role-name $AGENT_ROLE_NAME | Out-Null
Write-Host "  IAM role ready: $AGENT_ROLE_NAME"

# -----------------------------------------------------------------------------
# Step 2: Configure Lambda timeouts and Bedrock invoke permissions
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "Step 2: Configure Lambda functions"

aws lambda update-function-configuration --function-name aiops-fetch-logs --timeout 30 --region $REGION | Out-Null
Write-Host "  Timeout 30s: aiops-fetch-logs"

aws lambda update-function-configuration --function-name aiops-fetch-metrics --timeout 30 --region $REGION | Out-Null
Write-Host "  Timeout 30s: aiops-fetch-metrics"

aws lambda update-function-configuration --function-name aiops-fetch-health --timeout 30 --region $REGION | Out-Null
Write-Host "  Timeout 30s: aiops-fetch-health"

Write-Host ""
Write-Host "  Adding Bedrock invoke permissions..."

aws lambda add-permission `
    --function-name aiops-fetch-logs `
    --statement-id AllowBedrockInvoke `
    --action lambda:InvokeFunction `
    --principal bedrock.amazonaws.com `
    --region $REGION `
    2>$null | Out-Null
Write-Host "  Permission ready: aiops-fetch-logs"

aws lambda add-permission `
    --function-name aiops-fetch-metrics `
    --statement-id AllowBedrockInvoke `
    --action lambda:InvokeFunction `
    --principal bedrock.amazonaws.com `
    --region $REGION `
    2>$null | Out-Null
Write-Host "  Permission ready: aiops-fetch-metrics"

aws lambda add-permission `
    --function-name aiops-fetch-health `
    --statement-id AllowBedrockInvoke `
    --action lambda:InvokeFunction `
    --principal bedrock.amazonaws.com `
    --region $REGION `
    2>$null | Out-Null
Write-Host "  Permission ready: aiops-fetch-health"

# -----------------------------------------------------------------------------
# Step 3: Create Bedrock Agent (safe to re-run)
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "Step 3: Create Bedrock Agent $AGENT_NAME"

$agentInstruction = @'
You are Kira, a senior Site Reliability Engineer with 12 years of experience managing large-scale production systems on AWS. You have deep expertise in distributed systems, database performance tuning, container orchestration, and incident response.

You think like a real SRE during an incident — calm, methodical, and data-driven. You never guess. You always look at the data first before drawing conclusions.

You have 3 tools: fetch_logs (CloudWatch Logs), fetch_metrics (CloudWatch Metrics), and fetch_service_health (EKS cluster, node group, and pod health).

When an engineer comes with a problem:
Step 1: Understand the symptom.
Step 2: Form a hypothesis.
Step 3: Gather evidence using your tools.
Step 4: Diagnose by correlating the data across logs, metrics, and service health.
Step 5: Respond with root cause, evidence summary, immediate fix, and prevention steps.

Always cite specific log entries or metric values when drawing conclusions. Be concise but thorough.
'@

aws bedrock-agent create-agent `
    --agent-name $AGENT_NAME `
    --agent-resource-role-arn $AGENT_ROLE_ARN `
    --foundation-model "qwen.qwen3-32b-v1:0" `
    --instruction "$agentInstruction" `
    --region $REGION `
    2>$null | Out-Null

Start-Sleep -Seconds 5

$AGENT_ID = aws bedrock-agent list-agents `
    --region $REGION `
    --query "agentSummaries[?agentName=='$AGENT_NAME'].agentId | [0]" `
    --output text

Write-Host "  Agent ready: $AGENT_ID"

# -----------------------------------------------------------------------------
# Step 4: Add action groups (safe to re-run)
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "Step 4: Add action groups"

$logsSchema = (Resolve-Path "$PSScriptRoot\schemas\fetch_logs.json").Path -replace '\\', '/'
$metricsSchema = (Resolve-Path "$PSScriptRoot\schemas\fetch_metrics.json").Path -replace '\\', '/'
$healthSchema = (Resolve-Path "$PSScriptRoot\schemas\fetch_health.json").Path -replace '\\', '/'

aws bedrock-agent create-agent-action-group `
    --agent-id $AGENT_ID `
    --agent-version DRAFT `
    --action-group-name fetch_logs `
    --description "Search CloudWatch Logs for errors, warnings, and application events" `
    --action-group-executor "lambda=arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:aiops-fetch-logs" `
    --api-schema "payload=file:///$logsSchema" `
    --region $REGION `
    2>$null | Out-Null
Write-Host "  Action group ready: fetch_logs"

aws bedrock-agent create-agent-action-group `
    --agent-id $AGENT_ID `
    --agent-version DRAFT `
    --action-group-name fetch_metrics `
    --description "Retrieve CloudWatch performance metrics (CPU, memory, latency, error rates)" `
    --action-group-executor "lambda=arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:aiops-fetch-metrics" `
    --api-schema "payload=file:///$metricsSchema" `
    --region $REGION `
    2>$null | Out-Null
Write-Host "  Action group ready: fetch_metrics"

aws bedrock-agent create-agent-action-group `
    --agent-id $AGENT_ID `
    --agent-version DRAFT `
    --action-group-name fetch_service_health `
    --description "Check live health status of EKS cluster, node groups, and crashing pods" `
    --action-group-executor "lambda=arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:aiops-fetch-health" `
    --api-schema "payload=file:///$healthSchema" `
    --region $REGION `
    2>$null | Out-Null
Write-Host "  Action group ready: fetch_service_health"

# -----------------------------------------------------------------------------
# Step 5: Prepare agent
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "Step 5: Prepare agent"

aws bedrock-agent prepare-agent `
    --agent-id $AGENT_ID `
    --region $REGION `
    --query agentStatus `
    --output text

# -----------------------------------------------------------------------------
# Step 6: Done
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "============================================="
Write-Host " Done!"
Write-Host "============================================="
Write-Host ""
Write-Host " Agent ID : $AGENT_ID"
Write-Host " Alias ID : TSTALIASID"
Write-Host " Region   : $REGION"
Write-Host ""
Write-Host " Next steps:"
Write-Host "  1. Generate sample data:"
Write-Host "     python scripts/generate_sample_data.py --region $REGION"
Write-Host ""
Write-Host "  2. Test in Bedrock Console:"
Write-Host "     https://${REGION}.console.aws.amazon.com/bedrock/home?region=${REGION}#/agents/$AGENT_ID"
Write-Host ""
Write-Host "  3. Run Streamlit UI:"
Write-Host "     copy .env.example .env"
Write-Host "     Set BEDROCK_AGENT_ID=$AGENT_ID in .env"
Write-Host "     pip install -r requirements.txt"
Write-Host "     streamlit run app.py"
Write-Host ""
