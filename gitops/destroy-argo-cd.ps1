# =============================================================================
# Remove the boutique app from Kubernetes (reverse of deploy-argo-cd.ps1)
# =============================================================================
#
# Before running:
#   aws eks update-kubeconfig --region us-east-1 --name eks-cluster
#
# This removes the app only. ArgoCD, Prometheus, Grafana, and EKS stay running.
# Run terraform destroy separately when you want to remove the cluster.
#
# Run from this folder:
#   .\destroy-argo-cd.ps1
# =============================================================================

# -----------------------------------------------------------------------------
# Step 1: Unregister the app from ArgoCD
# -----------------------------------------------------------------------------
# Stops ArgoCD from syncing and self-healing the boutique app.
Write-Host "Step 1: Remove ArgoCD application"
kubectl delete -f "$PSScriptRoot\argo-cd.yml" -n argocd --ignore-not-found

# -----------------------------------------------------------------------------
# Step 2: Wait until ArgoCD has finished removing the app
# -----------------------------------------------------------------------------
Write-Host "Step 2: Waiting for ArgoCD application to be gone..."
kubectl wait --for=delete application/boutique -n argocd --timeout=120s 2>$null | Out-Null

# -----------------------------------------------------------------------------
# Step 3: Remove the database restore job
# -----------------------------------------------------------------------------
# deploy-argo-cd.ps1 applies this manually (not via ArgoCD sync).
Write-Host "Step 3: Remove database restore job"
kubectl delete job boutique-db-restore -n boutique --ignore-not-found

# -----------------------------------------------------------------------------
# Step 4: Remove boutique HTTPS ingress
# -----------------------------------------------------------------------------
# deploy-argo-cd.ps1 applies this manually (not via ArgoCD sync).
Write-Host "Step 4: Remove boutique HTTPS ingress"
kubectl delete -k "$PSScriptRoot\boutique-ingress" --ignore-not-found

# -----------------------------------------------------------------------------
# Step 5: Remove monitoring resources deployed from gitops/
# -----------------------------------------------------------------------------
# These live in the monitoring namespace, not boutique.
Write-Host "Step 5: Remove monitoring resources"
kubectl delete servicemonitor boutique-services -n monitoring --ignore-not-found
kubectl delete configmap grafana-dashboards -n monitoring --ignore-not-found

# -----------------------------------------------------------------------------
# Step 6: Delete the boutique namespace
# -----------------------------------------------------------------------------
# Removes all app pods, services, postgres, secrets, and PVCs.
Write-Host "Step 6: Delete boutique namespace"
kubectl delete namespace boutique --wait --timeout=300s --ignore-not-found

# -----------------------------------------------------------------------------
# Step 7: Verify everything is gone
# -----------------------------------------------------------------------------
Write-Host "Step 7: Verify cleanup"
kubectl get application boutique -n argocd 2>$null
kubectl get ingress boutique -n boutique 2>$null
kubectl get namespace boutique 2>$null
kubectl get servicemonitor boutique-services -n monitoring 2>$null
kubectl get job boutique-db-restore -n boutique 2>$null

Write-Host ""
Write-Host "Done. Boutique app removed."
Write-Host " ArgoCD, Prometheus, and Grafana in the monitoring namespace are still running."
