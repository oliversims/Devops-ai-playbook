# IRSA teardown — removes role created by setup-irsa.ps1
# Run from this folder: .\destroy-irsa.ps1

$ROLE_NAME = "aiops-kira-ui-role"

Write-Host ""
Write-Host "============================================="
Write-Host " AIOps - Kira UI IRSA Teardown"
Write-Host "============================================="
Write-Host ""

Write-Host "Step 1: Remove $ROLE_NAME"

aws iam delete-role-policy `
    --role-name $ROLE_NAME `
    --policy-name "aiops-kira-ui-inline-policy" `
    2>$null | Out-Null
Write-Host "  Removed inline policy: aiops-kira-ui-inline-policy"

aws iam delete-role --role-name $ROLE_NAME 2>$null | Out-Null
Write-Host "  Role removed: $ROLE_NAME"

Write-Host ""
Write-Host "============================================="
Write-Host " Done!"
Write-Host "============================================="
Write-Host ""
