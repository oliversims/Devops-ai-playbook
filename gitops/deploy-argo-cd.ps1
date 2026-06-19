# =============================================================================
# Deploy the boutique app to Kubernetes (via ArgoCD)
# =============================================================================
#
# Before running:
#   aws eks update-kubeconfig --region us-east-1 --name eks-cluster
#   On a fresh cluster, run GitHub Actions CI with "all" first (builds ECR images)
#
# Run from this folder:
#   .\deploy-argo-cd.ps1
# =============================================================================

# -----------------------------------------------------------------------------
# Step 1: Tell ArgoCD to deploy the app from Git
# -----------------------------------------------------------------------------
# This creates the "boutique" Application in ArgoCD.
# ArgoCD reads gitops/ from GitHub and creates pods, services, postgres, etc.
kubectl apply -f "$PSScriptRoot\argo-cd.yml" -n argocd

# -----------------------------------------------------------------------------
# Step 2: Wait until ArgoCD has finished syncing
# -----------------------------------------------------------------------------
# On a fresh cluster the "boutique" namespace does not exist yet.
# Do not run database steps until ArgoCD has synced — kubectl wait handles the
# waiting for us (up to 1 minute).
Write-Host "Step 2: Waiting for ArgoCD to sync the boutique app..."
kubectl wait --for=condition=Synced application/boutique -n argocd --timeout=60s

# -----------------------------------------------------------------------------
# Step 3: Wait until the PostgreSQL pod is ready
# -----------------------------------------------------------------------------
# The database must be running before we load the SQL dump.
Write-Host "Step 3: Waiting for postgres pod..."
kubectl wait --for=condition=ready pod/boutique-postgres-0 -n boutique --timeout=60s

# -----------------------------------------------------------------------------
# Step 4: Load the database from boutique_full.sql
# -----------------------------------------------------------------------------
# The restore job runs once, loads the dump, and creates auth/orders tables.
# Delete any old job first so we can run it again on a re-deploy.
Write-Host "Step 4: Restoring database..."
kubectl delete job boutique-db-restore -n boutique --ignore-not-found
kubectl apply -f "$PSScriptRoot\k8s\database\restore-job.yml"
kubectl wait --for=condition=complete job/boutique-db-restore -n boutique --timeout=60s

# -----------------------------------------------------------------------------
# Step 5: Restart backend services
# -----------------------------------------------------------------------------
# Backends may have crashed before the database existed.
# A restart makes them connect to the freshly seeded database.
Write-Host "Step 5: Restarting backend deployments..."
kubectl rollout restart deployment -n boutique auth gateway order-service orders product-service user-service

# -----------------------------------------------------------------------------
# Step 6: Apply boutique HTTPS ingress
# -----------------------------------------------------------------------------
Write-Host "Step 6: Applying boutique HTTPS ingress..."
kubectl apply -k "$PSScriptRoot\boutique-ingress"

# -----------------------------------------------------------------------------
# Step 7: Show status
# -----------------------------------------------------------------------------
Write-Host "Step 7: Deployment status"
kubectl get application boutique -n argocd
kubectl get pods -n boutique
kubectl get ingress -n boutique

Write-Host ""
Write-Host "Done. App URL (after DNS propagates): https://app.simsoliver.com"
Write-Host "Or port-forward locally:"
Write-Host "  kubectl port-forward svc/frontend 3000:3000 -n boutique"
Write-Host "  Open http://localhost:3000"
