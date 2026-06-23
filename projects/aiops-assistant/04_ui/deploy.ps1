# Deploy Kira UI to EKS
# Run: .\04_ui\deploy.ps1
# Prerequisite: .\04_ui\build-push.ps1

$ErrorActionPreference = "SilentlyContinue"

$AppRoot = (Resolve-Path "$PSScriptRoot\..").Path
$ENV_FILE = Join-Path $AppRoot ".env"
$K8S_FILE = Join-Path $PSScriptRoot "k8s.yml"

# Step 1: kubectl must reach the cluster
kubectl cluster-info > $null 2>&1
($LASTEXITCODE -eq 0) -or (Write-Error "Run: aws eks update-kubeconfig --region us-east-1 --name eks-cluster" -ErrorAction Stop) | Out-Null

# Step 2: Namespace + deployment + service
kubectl apply -f $K8S_FILE
($LASTEXITCODE -eq 0) -or (Write-Error "Apply failed." -ErrorAction Stop) | Out-Null

# Step 3: Secret from .env (Bedrock agent settings)
kubectl create secret generic kira-env --from-env-file=$ENV_FILE -n aiops --dry-run=client -o yaml | kubectl apply -f -
($LASTEXITCODE -eq 0) -or (Write-Error "Secret failed." -ErrorAction Stop) | Out-Null

# Step 4: Restart pod so it picks up the secret
kubectl rollout restart deployment/kira-ui -n aiops > $null 2>&1

# Step 5: Wait for pod
kubectl rollout status deployment/kira-ui -n aiops --timeout=120s
($LASTEXITCODE -eq 0) -or (Write-Error "Rollout failed. Check: kubectl get pods -n aiops" -ErrorAction Stop) | Out-Null

Write-Host "Ready. Run: .\04_ui\port-forward.ps1"
Write-Host "Ingress: gitops/02_aiops/run.txt"
