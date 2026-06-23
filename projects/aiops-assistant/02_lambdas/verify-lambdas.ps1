# =============================================================================
# Verify AIOps Lambdas — run after deploy-lambdas.ps1
# Run from: projects/aiops-assistant/lambdas
# =============================================================================

$Root = (Resolve-Path "$PSScriptRoot\..").Path

# -----------------------------------------------------------------------------
# Step 1: Load region from config.env
# -----------------------------------------------------------------------------
Get-Content "$Root\config.env" |
    Where-Object { $_ -notmatch '^\s*(#|$)' } |
    ForEach-Object { $n, $v = $_ -split '=', 2; Set-Variable -Name $n.Trim() -Value $v.Trim() -Scope Script }

# Use DEPLOY_REGION, or AWS_REGION, or us-east-1 as fallback
$DEPLOY_REGION = @($DEPLOY_REGION, $AWS_REGION, "us-east-1") | Where-Object { $_ } | Select-Object -First 1

# -----------------------------------------------------------------------------
# Step 2: List all 3 Lambda functions (expect 3 rows)
# -----------------------------------------------------------------------------
Write-Host "`nStep 2: List functions`n"
aws lambda list-functions --region $DEPLOY_REGION `
    --query "Functions[?starts_with(FunctionName, 'aiops-fetch')].{Name:FunctionName,Runtime:Runtime,Timeout:Timeout}" `
    --output table

# -----------------------------------------------------------------------------
# Step 3: Show env vars on each function
# -----------------------------------------------------------------------------
Write-Host "`nStep 3: Function config`n"
@("aiops-fetch-logs", "aiops-fetch-metrics", "aiops-fetch-health") | ForEach-Object {
    aws lambda get-function-configuration --function-name $_ --region $DEPLOY_REGION `
        --query "{Name:FunctionName,Runtime:Runtime,Env:Environment.Variables}" --output json
}

# -----------------------------------------------------------------------------
# Step 4: Confirm IAM role exists
# -----------------------------------------------------------------------------
Write-Host "`nStep 4: IAM role`n"
aws iam get-role --role-name aiops-lambda-role `
    --query "Role.{Name:RoleName,Arn:Arn}" --output table

# -----------------------------------------------------------------------------
# Helper: invoke a Lambda with a JSON payload file (PowerShell-safe on Windows)
# -----------------------------------------------------------------------------
function Invoke-TestLambda($Name, $PayloadJson, $OutFile) {
    $payloadFile = "$env:TEMP\$Name-payload.json"
    $outPath = Join-Path $PSScriptRoot $OutFile
    [System.IO.File]::WriteAllText($payloadFile, $PayloadJson)
    Write-Host "`nInvoke $Name`n"
    aws lambda invoke --function-name $Name --region $DEPLOY_REGION `
        --payload "file://$payloadFile" `
        --cli-binary-format raw-in-base64-out $outPath | Out-Null
    Get-Content $outPath -ErrorAction SilentlyContinue
}

# -----------------------------------------------------------------------------
# Step 5: Test fetch_logs — searches CloudWatch for ERROR logs
# Expect: status "logs_found" or "no_logs_found" (both mean it works)
# -----------------------------------------------------------------------------
Invoke-TestLambda "aiops-fetch-logs" `
    '{"parameters":[{"name":"filter_pattern","value":"ERROR"},{"name":"hours_back","value":"1"}]}' `
    "out-logs.json"

# -----------------------------------------------------------------------------
# Step 6: Test fetch_metrics — queries Prometheus for CPU metrics
# Expect: status "ok" with pod data, or "no_data" if nothing to scrape
# -----------------------------------------------------------------------------
Invoke-TestLambda "aiops-fetch-metrics" `
    '{"parameters":[{"name":"metric_name","value":"pod_cpu_utilization"},{"name":"namespace","value":"boutique"},{"name":"hours_back","value":"1"}]}' `
    "out-metrics.json"

# -----------------------------------------------------------------------------
# Step 7: Test fetch_health — checks EKS cluster and deployment health
# Expect: status "success" with overall_healthy true/false
# -----------------------------------------------------------------------------
Invoke-TestLambda "aiops-fetch-health" `
    '{"parameters":[{"name":"cluster_name","value":"eks-cluster"},{"name":"namespace","value":"boutique"}]}' `
    "out-health.json"

# -----------------------------------------------------------------------------
# Step 8: Clean up temp output files
# -----------------------------------------------------------------------------
Write-Host "`nDone. Next: ..\bedrock\deploy.ps1`n"
Remove-Item "$PSScriptRoot\out-logs.json", "$PSScriptRoot\out-metrics.json", "$PSScriptRoot\out-health.json" `
    -ErrorAction SilentlyContinue
