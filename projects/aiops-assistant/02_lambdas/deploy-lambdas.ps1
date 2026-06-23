# =============================================================================
# Deploy the 3 AIOps Lambda functions
# =============================================================================
# Run order:
#   1. ..\iam\setup-iam.ps1       (creates IAM roles)
#   2. .\deploy-lambdas.ps1       (this script)
#   3. ..\bedrock\deploy.ps1              (creates Bedrock Agent)
#
# Edit ..\config.env to change Prometheus URL, log group, cluster name, etc.
# =============================================================================

# Stop the script if any command fails
$ErrorActionPreference = "Stop"

# Parent folder (aiops-assistant/) — holds config.env and lambda/ code
$Root = (Resolve-Path "$PSScriptRoot\..").Path

# -----------------------------------------------------------------------------
# Step 1: Load settings from config.env
# Reads DEPLOY_REGION (or AWS_REGION), PROMETHEUS_URL, LOG_GROUP_NAME, etc.
# -----------------------------------------------------------------------------
Get-Content "$Root\config.env" |
    Where-Object { $_ -notmatch '^\s*(#|$)' } |
    ForEach-Object { $n, $v = $_ -split '=', 2; Set-Variable -Name $n.Trim() -Value $v.Trim() -Scope Script }
if (-not $DEPLOY_REGION) { $DEPLOY_REGION = $AWS_REGION }

# -----------------------------------------------------------------------------
# Step 2: Build the IAM role ARN (created earlier by setup-iam.ps1)
# -----------------------------------------------------------------------------
$Role = "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/aiops-lambda-role"

# -----------------------------------------------------------------------------
# Helper: deploy one Lambda function
# -----------------------------------------------------------------------------
function Deploy-Lambda($Name, $Folder, $Env) {
    $zip = "$env:TEMP\$Name.zip"
    $envFile = "$env:TEMP\$Name-env.json"

    # Package lambda_function.py into a zip (Lambda requires a zip upload)
    Remove-Item $zip -ErrorAction SilentlyContinue
    Compress-Archive -Path "$Root\lambda\$Folder\lambda_function.py" -DestinationPath $zip

    # Write env vars (PROMETHEUS_URL, LOG_GROUP_NAME, etc.) to a temp JSON file
    (@{ Variables = $Env } | ConvertTo-Json -Compress -Depth 3) | Set-Content $envFile

    # Create the function on first run (safe to re-run — ignores "already exists")
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    aws lambda create-function --function-name $Name --runtime python3.12 `
        --handler lambda_function.lambda_handler --role $Role `
        --zip-file "fileb://$zip" --timeout 30 --environment "file://$envFile" `
        --region $DEPLOY_REGION 2>&1 | Out-Null
    $created = ($LASTEXITCODE -eq 0)
    $ErrorActionPreference = $prev

    # On first create, wait until Lambda is ready before updating
    if ($created) {
        aws lambda wait function-active-v2 --function-name $Name --region $DEPLOY_REGION | Out-Null
    }

    # Always push the latest code (run this again after editing lambda_function.py)
    aws lambda update-function-code --function-name $Name --zip-file "fileb://$zip" --region $DEPLOY_REGION | Out-Null

    # Wait briefly — AWS needs a moment between code and config updates
    Start-Sleep -Seconds 2

    # Apply timeout (30s) and env vars from config.env
    aws lambda update-function-configuration --function-name $Name --timeout 30 `
        --environment "file://$envFile" --region $DEPLOY_REGION | Out-Null

    Write-Host "OK $Name"
}

# -----------------------------------------------------------------------------
# Step 3: Deploy all 3 functions
# -----------------------------------------------------------------------------
Write-Host "`nDeploying Lambdas (region $DEPLOY_REGION)...`n"

# CloudWatch Logs — queries /eks/boutique/pods
# Note: do not pass AWS_REGION — Lambda sets it automatically (reserved key)
Deploy-Lambda "aiops-fetch-logs"     "fetch_logs"    @{ LOG_GROUP_NAME=$LOG_GROUP_NAME }

# Prometheus metrics — CPU, memory, restarts
Deploy-Lambda "aiops-fetch-metrics" "fetch_metrics" @{ PROMETHEUS_URL=$PROMETHEUS_URL; DEFAULT_NAMESPACE=$DEFAULT_NAMESPACE }

# EKS + Prometheus health — cluster status, deployments, crashing pods
Deploy-Lambda "aiops-fetch-health"  "fetch_health"  @{ PROMETHEUS_URL=$PROMETHEUS_URL; DEFAULT_CLUSTER=$DEFAULT_CLUSTER; DEFAULT_NAMESPACE=$DEFAULT_NAMESPACE }

Write-Host "`nDone. Next: ..\bedrock\deploy.ps1`n"
