# AIOps IAM setup — creates aiops-lambda-role and aiops-bedrock-agent-role.
# Run from this folder: .\setup-iam.ps1

$REGION = "us-east-1"
$ACCOUNT_ID = aws sts get-caller-identity --query Account --output text

Write-Host ""
Write-Host "============================================="
Write-Host " AIOps - IAM Setup"
Write-Host " Account : $ACCOUNT_ID"
Write-Host " Region  : $REGION"
Write-Host "============================================="
Write-Host ""

# Step 1: aiops-lambda-role
$lambdaRoleName = "aiops-lambda-role"

Write-Host "Step 1: IAM role $lambdaRoleName"

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

aws iam create-role `
    --role-name $lambdaRoleName `
    --assume-role-policy-document "file://$lambdaTrustFile" `
    --description "Role for AIOps Lambda functions" `
    2>$null | Out-Null
Write-Host "  Role ready: $lambdaRoleName"

aws iam attach-role-policy `
    --role-name $lambdaRoleName `
    --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
Write-Host "  Attached: AWSLambdaBasicExecutionRole"

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

# Step 2: aiops-bedrock-agent-role
$agentRoleName = "aiops-bedrock-agent-role"

Write-Host ""
Write-Host "Step 2: IAM role $agentRoleName"

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

aws iam create-role `
    --role-name $agentRoleName `
    --assume-role-policy-document "file://$agentTrustFile" `
    --description "Role for Bedrock Agent - AIOps assistant" `
    2>$null | Out-Null
Write-Host "  Role ready: $agentRoleName"

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

Write-Host ""
Write-Host "============================================="
Write-Host " Done!"
Write-Host "============================================="
Write-Host ""
Write-Host " Roles ready:"
Write-Host "  - $lambdaRoleName"
Write-Host "  - $agentRoleName"
Write-Host ""
Write-Host " Next: ..\lambdas\deploy-lambdas.ps1"
Write-Host ""
