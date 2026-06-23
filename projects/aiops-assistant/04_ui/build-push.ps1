# Build and push Kira UI to ECR (linux/amd64 for EKS)
# Run: .\04_ui\build-push.ps1
# ECR repo (one-time): terraform apply in projects\Infrastructure\03_ecr
# ARM laptop (one-time): docker buildx create --name amd64builder --driver docker-container --use
#                        docker buildx inspect --bootstrap

$ErrorActionPreference = "SilentlyContinue"

$REGION = "us-east-1"
$REPO = "aiops-assistant"
$AppRoot = (Resolve-Path "$PSScriptRoot\..").Path

# Step 1: Docker must be running
Write-Host "`nStep 1: Checking Docker..."
docker info > $null 2>&1
($LASTEXITCODE -eq 0) -or (Write-Error "Start Docker Desktop." -ErrorAction Stop) | Out-Null

# Step 2: ECR repo must exist
Write-Host "Step 2: Checking ECR repo..."
aws ecr describe-repositories --repository-names $REPO --region $REGION > $null 2>&1
($LASTEXITCODE -eq 0) -or (Write-Error "Run terraform apply in 03_ecr first." -ErrorAction Stop) | Out-Null

# Step 3: Image name
$ACCOUNT = aws sts get-caller-identity --query Account --output text
$IMAGE = "$ACCOUNT.dkr.ecr.$REGION.amazonaws.com/${REPO}:latest"
Write-Host "Step 3: Image -> $IMAGE"

# Step 4: Log in to ECR
Write-Host "Step 4: Logging in to ECR..."
aws ecr get-login-password --region $REGION |
    docker login --username AWS --password-stdin "$ACCOUNT.dkr.ecr.$REGION.amazonaws.com"
($LASTEXITCODE -eq 0) -or (Write-Error "ECR login failed." -ErrorAction Stop) | Out-Null

# Step 5: Build amd64 image and push (live output)
Write-Host "Step 5: Building and pushing (linux/amd64)..."
docker buildx build --builder amd64builder --platform linux/amd64 --progress=plain --provenance=false --sbom=false -t $IMAGE --push $AppRoot
($LASTEXITCODE -eq 0) -or (Write-Error "Build/push failed." -ErrorAction Stop) | Out-Null

# Step 6: Remove untagged images — old builds left behind when :latest moves
Write-Host "Step 6: Removing old untagged images..."
$Ids = aws ecr list-images --repository-name $REPO --region $REGION --filter tagStatus=UNTAGGED --query imageIds --output json
($Ids -notmatch "imageDigest") -or $(aws ecr batch-delete-image --repository-name $REPO --region $REGION --image-ids $Ids; ($LASTEXITCODE -eq 0) -or (Write-Error "Cleanup failed." -ErrorAction Stop) | Out-Null) | Out-Null

Write-Host "`nDone: $IMAGE (only :latest kept in ECR)"
