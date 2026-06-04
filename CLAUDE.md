# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Operating mode

You are operating in **safe execution mode**. Before executing any command:
- Briefly explain what you're about to do in 1-2 plain sentences
- Say WHY, not just WHAT
- Then proceed

This matters because much of this repo drives live AWS infrastructure (EKS, ECR, Bedrock, Terraform) where silent commands have real cost and blast radius.

## What this repository is

A teaching repo ("DevOps + AIOps Series") that ships a complete e-commerce microservices app and walks it from local Docker → AWS EKS → CI/CD → GitOps → observability → an AIOps assistant. It is **intentionally seeded with bugs** to practice troubleshooting (see `projects/Issues.md` for documented ones). Treat surprising config/code as possibly deliberate — confirm before "fixing" something that may be a planted exercise.

Three top-level areas:
- `projects/boutique-microservices/` — the application (React frontend + Node services + PostgreSQL)
- `projects/Infrastructure/` — Terraform that provisions the AWS/EKS platform
- `gitops/` — Kubernetes manifests (Kustomize) that ArgoCD syncs to the cluster
- `projects/aiops-assistant/` — Streamlit + AWS Bedrock Agent ("Kira") for incident diagnosis
- `docs/` — the written series; `projects/README.md` is the authoritative end-to-end deployment guide

## Common commands

All app commands run from `projects/boutique-microservices/` (it is an npm workspaces root: `frontend`, `backend`, `backend/services/*`).

```bash
# Local run — everything in Docker (frontend, gateway, 5 services, postgres, prometheus, grafana)
docker-compose -f docker-compose.yml up -d
docker-compose -f docker-compose.yml down

# Local run — Node only
npm install
npm run dev            # frontend + all backend services concurrently
npm run dev:backend    # backend services only
npm run dev:frontend   # React app only

# Build / test (delegate into workspaces)
npm run build          # frontend build + tsc build of each TS service
npm test               # frontend (react-scripts/jest) + backend services

# Frontend single test (from frontend/)
npx react-scripts test src/App.test.tsx       # watch mode; CI=true for one-shot
```

Per-backend-service (from `backend/services/<svc>/`): `npm run dev` (nodemon), `npm run build` (`tsc`), `npm start` (`node dist/index.js`).

Infrastructure (from `projects/Infrastructure/`):
```bash
terraform init && terraform plan
terraform apply --auto-approve     # ~15 min; creates VPC, EKS, ECR, ArgoCD, kube-prometheus-stack
aws eks update-kubeconfig --region us-east-1 --name eks-cluster
terraform destroy --auto-approve   # full teardown
```

GitOps / cluster:
```bash
kubectl apply -k gitops/                              # apply all manifests via Kustomize
kubectl apply -f gitops/k8s/database/restore-job.yml  # seed DB *after* postgres pod is Ready
kubectl apply -f gitops/argo-cd.yml -n argocd         # register the ArgoCD Application
```

## Architecture

**Request path:** Browser → Frontend (nginx, :3000) → **Gateway** (:3001, `http-proxy-middleware`) → backend services → PostgreSQL (:5432). The gateway is the only public backend entry point; it path-rewrites `/api/<x>` to the matching service. Service URLs are injected as env vars, defaulting to `localhost` for non-Docker runs.

**Backend services** (one container/image/port each):
| Service | Port | Role | DB |
|---|---|---|---|
| gateway | 3001 | reverse proxy / single entry | — |
| auth | 3002 | login & registration | auth_db |
| product-service | 3003 | catalog & inventory | products_db |
| order-service | 3004 | cart & checkout | orders_db |
| orders | 3005 | order history/management | orders_db |
| user-service | 3006 | profiles & accounts | users_db |

A single PostgreSQL instance hosts four logical DBs (`auth_db`, `products_db`, `orders_db`, `users_db`); services connect via `DATABASE_URL`.

**Mixed implementation styles are intentional and uneven.** Some services are TypeScript (`src/index.ts`, built with `tsc` to `dist/`); others are plain JS (`src/server.js`). `product-service/` in particular has several parallel entrypoints (`server.js`, `server-fixed.js`, plus repo-root `mock-product-service.js` / `simple-product-service.js`) — check the service's `Dockerfile` and `package.json` `main`/`dev` to learn which one actually runs before editing. Most services have no real test script (`test` just errors).

**Observability:** every backend exposes `/metrics` (Node `prom-client`). Locally, Prometheus scrapes via `prometheus/prometheus.yml`; on EKS, the `kube-prometheus-stack` operator discovers scrape targets through the `ServiceMonitor` in `gitops/k8s/backend/service-monitor.yml` (must carry label `release: kube-prometheus-stack`). Grafana auto-imports `gitops/k8s/grafana-dashboard.yml` because it's a ConfigMap labeled `grafana_dashboard: "1"`.

**CI/CD + GitOps flow:** `.github/workflows/ci.yml` (currently `workflow_dispatch` only) builds each service in a 7-way matrix, pushes images to ECR tagged with the commit SHA, then a second job `sed`-rewrites those tags into `gitops/k8s/**` and commits back to `main`. ArgoCD watches `gitops/` on `main` and rolls out the change. Sync is currently **manual** (`syncPolicy: {}` in `gitops/argo-cd.yml`). Note: `argo-cd.yml` `repoURL` points at the upstream template repo — repoint it to your fork before relying on ArgoCD.

**AIOps assistant (`projects/aiops-assistant/`):** a Streamlit UI (`app.py`) talks to a Bedrock Agent backed by three Lambdas (`fetch_logs` → CloudWatch Logs, `fetch_metrics` / `fetch_health` → Prometheus ELB + EKS), each with an OpenAPI schema in `schemas/`. `deploy.sh` and `setup-iam.sh` provision it. The Lambdas have hardcoded placeholders you must edit before deploy: `PROMETHEUS_URL` and `DEFAULT_CLUSTER` (`eks-cluster`).

## Key gotchas

- **DB seeding order:** the StatefulSet's init script is skipped on EBS volumes (the `lost+found` dir makes the volume look non-empty), so on EKS the DB is loaded by `restore-job.yml` — and only after the postgres pod is `1/1 Ready`. Applying it early fails; delete and re-apply.
- **Gateway env var naming is inconsistent** between code defaults and `docker-compose.yml` (e.g. `USERS_SERVICE_URL` vs `USER_SERVICE_URL`, default ports). This is one of the planted issues — verify the actual wiring rather than trusting either side.
- **Grafana** is `:3007` locally (host) but `:8080` via `kubectl port-forward` on EKS.
- Secrets in `docker-compose.yml` / `gitops/secrets.yml` are demo credentials (`postgres123`, `admin/admin`) — fine locally, never for real deployments.
