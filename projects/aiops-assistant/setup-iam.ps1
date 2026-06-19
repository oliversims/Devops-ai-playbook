# =============================================================================
# AIOps Assistant - IAM Setup (PowerShell / Windows)
# =============================================================================
#
# Creates IAM roles for the AIOps project:
#   1. aiops-lambda-role        - used by the 3 Lambda functions
#   2. aiops-bedrock-agent-role - used by the Bedrock Agent (Kira)
#
# Before running:
#   - AWS CLI installed and logged in (aws configure)
#
# Run from this folder:
#   .\setup-iam.ps1
# =============================================================================

$REGION = "us-east-1"
$ACCOUNT_ID = aws sts get-caller-identity --query Account --output text

Write-Host ""
Write-Host "============================================="
Write-Host " AIOps - IAM Setup"
Write-Host " Account : $ACCOUNT_ID"
Write-Host " Region  : $REGION"
Write-Host "============================================="
Write-Host ""

# -----------------------------------------------------------------------------
# Step 1: aiops-lambda-role
# Used by: aiops-fetch-logs, aiops-fetch-metrics, aiops-fetch-health
# -----------------------------------------------------------------------------
$lambdaRoleName = "aiops-lambda-role"

Write-Host "Step 1: IAM role $lambdaRoleName"

# Trust policy - allows Lambda service to use this role
$lambdaTrustPolicy = @'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
'@

$lambdaTrustFile = "$env:TEMP\aiops-lambda-trust.json"
[System.IO.File]::WriteAllText($lambdaTrustFile, $lambdaTrustPolicy)

# Create the role (safe to re-run — if it already exists, AWS returns an error we ignore)
aws iam create-role `
    --role-name $lambdaRoleName `
    --assume-role-policy-document "file://$lambdaTrustFile" `
    --description "Role for AIOps Lambda functions" `
    2>$null | Out-Null
Write-Host "  Role ready: $lambdaRoleName"

# Attach AWS managed policy so Lambda can write logs
aws iam attach-role-policy `
    --role-name $lambdaRoleName `
    --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
Write-Host "  Attached: AWSLambdaBasicExecutionRole"

# Inline policy - read CloudWatch Logs and describe EKS
$lambdaInlinePolicy = @'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CloudWatchLogsRead",
      "Effect": "Allow",
      "Action": [
        "logs:FilterLogEvents",
        "logs:StartQuery",
        "logs:GetQueryResults",
        "logs:StopQuery",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EKSRead",
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:ListNodegroups",
        "eks:DescribeNodegroup"
      ],
      "Resource": "*"
    }
  ]
}
'@

$lambdaInlineFile = "$env:TEMP\aiops-lambda-inline.json"
[System.IO.File]::WriteAllText($lambdaInlineFile, $lambdaInlinePolicy)

aws iam put-role-policy `
    --role-name $lambdaRoleName `
    --policy-name "aiops-lambda-inline-policy" `
    --policy-document "file://$lambdaInlineFile"
Write-Host "  Inline policy applied: CloudWatch Logs read + EKS describe"

# -----------------------------------------------------------------------------
# Step 2: aiops-bedrock-agent-role
# Used by: Bedrock Agent (aiops-assistant / Kira)
# -----------------------------------------------------------------------------
$agentRoleName = "aiops-bedrock-agent-role"

Write-Host ""
Write-Host "Step 2: IAM role $agentRoleName"

# Trust policy - allows Bedrock service to use this role
$agentTrustPolicy = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "bedrock.amazonaws.com"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "aws:SourceAccount": "$ACCOUNT_ID"
        }
      }
    }
  ]
}
"@

$agentTrustFile = "$env:TEMP\aiops-agent-trust.json"
[System.IO.File]::WriteAllText($agentTrustFile, $agentTrustPolicy)

# Create the role (safe to re-run — if it already exists, AWS returns an error we ignore)
aws iam create-role `
    --role-name $agentRoleName `
    --assume-role-policy-document "file://$agentTrustFile" `
    --description "Role for Bedrock Agent - AIOps assistant" `
    2>$null | Out-Null
Write-Host "  Role ready: $agentRoleName"

# Inline policy - invoke Lambdas and Bedrock models
$agentInlinePolicy = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "InvokeLambdaFunctions",
      "Effect": "Allow",
      "Action": "lambda:InvokeFunction",
      "Resource": [
        "arn:aws:lambda:$REGION`:$ACCOUNT_ID`:function:aiops-fetch-logs",
        "arn:aws:lambda:$REGION`:$ACCOUNT_ID`:function:aiops-fetch-metrics",
        "arn:aws:lambda:$REGION`:$ACCOUNT_ID`:function:aiops-fetch-health"
      ]
    },
    {
      "Sid": "InvokeBedrockModels",
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ],
      "Resource": "arn:aws:bedrock:$REGION`::foundation-model/*"
    }
  ]
}
"@

$agentInlineFile = "$env:TEMP\aiops-agent-inline.json"
[System.IO.File]::WriteAllText($agentInlineFile, $agentInlinePolicy)

aws iam put-role-policy `
    --role-name $agentRoleName `
    --policy-name "aiops-bedrock-agent-inline-policy" `
    --policy-document "file://$agentInlineFile"
Write-Host "  Inline policy applied: Lambda invoke + Bedrock model invoke"

# -----------------------------------------------------------------------------
# Step 3: Done
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "============================================="
Write-Host " Done!"
Write-Host "============================================="
Write-Host ""
Write-Host " Roles ready:"
Write-Host "  - $lambdaRoleName"
Write-Host "    arn:aws:iam::${ACCOUNT_ID}:role/$lambdaRoleName"
Write-Host ""
Write-Host "  - $agentRoleName"
Write-Host "    arn:aws:iam::${ACCOUNT_ID}:role/$agentRoleName"
Write-Host ""
Write-Host " Next: create the 3 Lambda functions in AWS Console"
Write-Host "       and assign '$lambdaRoleName' as their execution role."
Write-Host ""
