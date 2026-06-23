# Remove the boutique app (reverse of deploy-argo-cd.ps1).
# Run: aws eks update-kubeconfig --region us-east-1 --name eks-cluster
# Typical runtime: ~1-2 minutes (namespace delete is the slow part).
#
# Keeps ArgoCD, Prometheus, Grafana, and EKS running.

Write-Host "`nRemoving boutique app...`n"

# 1. Stop ArgoCD from managing the app (prune removes gitops resources too)
Write-Host "1/5 Remove ArgoCD application"
kubectl delete -f "$PSScriptRoot\argo-cd.yml" -n argocd --ignore-not-found
kubectl wait --for=delete application/boutique -n argocd --timeout=120s 2>$null | Out-Null

# 2. Remove resources deploy-argo-cd.ps1 applied outside ArgoCD
Write-Host "2/5 Remove restore job and HTTPS ingress"
kubectl delete job boutique-db-restore -n boutique --ignore-not-found
kubectl delete -k "$PSScriptRoot\02_boutique-ingress" --ignore-not-found

# 3. Remove monitoring resources synced from gitops/ (safety net if prune missed them)
Write-Host "3/5 Remove monitoring resources"
kubectl delete servicemonitor boutique-services -n monitoring --ignore-not-found
kubectl delete configmap grafana-dashboards -n monitoring --ignore-not-found

# 4. Delete the boutique namespace (pods, postgres PVC, services)
Write-Host "4/5 Delete boutique namespace (may take up to 2 min)..."
kubectl delete namespace boutique --wait --timeout=300s --ignore-not-found

# 5. Verify — use --ignore-not-found so a clean cluster does not error
Write-Host "5/5 Verify"
kubectl get application boutique -n argocd --ignore-not-found 2>$null | Out-Null
kubectl get namespace boutique --ignore-not-found 2>$null | Out-Null
kubectl get servicemonitor boutique-services -n monitoring --ignore-not-found 2>$null | Out-Null

Write-Host "`nDone. Boutique removed (~1-2 min). ArgoCD and monitoring stack still running.`n"
