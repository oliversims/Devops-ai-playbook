# Run Kira UI locally in Docker
# Run: .\04_ui\run-docker.ps1

$ErrorActionPreference = "SilentlyContinue"

$IMAGE = "kira-ui"
$AppRoot = (Resolve-Path "$PSScriptRoot\..").Path
$ENV_FILE = Join-Path $AppRoot ".env"
$AWS_DIR = Join-Path $env:USERPROFILE ".aws"

# Step 1: Docker must be running
docker info > $null 2>&1
($LASTEXITCODE -eq 0) -or (Write-Error "Start Docker Desktop." -ErrorAction Stop) | Out-Null

# Step 2: Build
docker build -t $IMAGE $AppRoot
($LASTEXITCODE -eq 0) -or (Write-Error "Build failed." -ErrorAction Stop) | Out-Null

# Step 3: Run on http://localhost:8501 (Ctrl+C to stop)
docker run --rm -p 8501:8501 --env-file $ENV_FILE -v "${AWS_DIR}:/root/.aws:ro" $IMAGE
