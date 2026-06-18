# Remove the boutique app from the cluster
#
# Before running:
#   aws eks update-kubeconfig --region us-east-1 --name eks-cluster
#
# This removes the app only. ArgoCD, monitoring, and the EKS cluster stay running.
# Run terraform destroy separately when you want to remove everything.
#
# Run: .\gitops\destroy-argo-cd.ps1

# Step 1: Unregister the app from ArgoCD
kubectl delete -f "$PSScriptRoot\argo-cd.yml" -n argocd --ignore-not-found

# Step 2: Delete the boutique namespace (all app pods, services, database)
kubectl delete namespace boutique --wait --timeout=300s --ignore-not-found

# Step 3: Check everything is gone
kubectl get application boutique -n argocd
kubectl get namespace boutique
