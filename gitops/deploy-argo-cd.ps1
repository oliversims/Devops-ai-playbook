# Register the boutique app with ArgoCD.
# Run from anywhere: .\gitops\deploy-argo-cd.ps1

kubectl apply -f "$PSScriptRoot\argo-cd.yml" -n argocd
