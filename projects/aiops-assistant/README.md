# AIOps Assistant — Kira

An AI-powered SRE assistant built on AWS Bedrock Agent. Kira diagnoses production incidents by querying CloudWatch Logs, CloudWatch Metrics (via Prometheus), and EKS cluster health — then responds with root cause, evidence, and fix recommendations.

---

## Architecture

```
Streamlit UI (app.py)
      │
      ▼
Bedrock Agent (Kira)
      │
      ├── fetch_logs         → CloudWatch Logs
      ├── fetch_metrics      → Prometheus (ELB endpoint)
      └── fetch_service_health → EKS cluster + node groups
```

---

## Prerequisites

- AWS account with access to Bedrock (model access enabled for your chosen model)
- EKS cluster running with Prometheus exposed via a LoadBalancer service
- AWS CLI configured (`aws configure`)
- Python 3.10+

---

## Step 1: Set Up IAM Roles

Run the provided script to create both required IAM roles:

```bash
chmod +x iam/setup-iam.sh
./iam/setup-iam.sh
```

On Windows:
```powershell
.\iam\setup-iam.ps1
```

This creates:

| Role | Used By | Permissions |
|------|---------|-------------|
| `aiops-lambda-role` | All 3 Lambda functions | CloudWatch Logs read, EKS describe, Lambda basic execution |
| `aiops-bedrock-agent-role` | Bedrock Agent | Invoke the 3 Lambda functions, invoke Bedrock models |

---

## Step 2: Configure and Deploy the Lambda Functions

Edit `config.env` if needed (Prometheus URL, log group, cluster name):

```env
AWS_REGION=us-east-1
LOG_GROUP_NAME=/eks/boutique/pods
PROMETHEUS_URL=https://pro.simsoliver.com
DEFAULT_CLUSTER=eks-cluster
DEFAULT_NAMESPACE=boutique
```

Then run the deploy script. It zips each file in `lambda/` and creates (or updates) the 3 functions:

| Function Name | Source |
|---------------|--------|
| `aiops-fetch-logs` | `lambda/fetch_logs/` |
| `aiops-fetch-metrics` | `lambda/fetch_metrics/` |
| `aiops-fetch-health` | `lambda/fetch_health/` |

**Windows (PowerShell):**
```powershell
.\lambdas\deploy-lambdas.ps1
```

**Linux / macOS:**
```bash
chmod +x lambdas/deploy-lambdas.sh
./lambdas/deploy-lambdas.sh
```

Re-run this script any time you change Lambda code or `config.env`.

---

## Step 3: Deploy the Bedrock Agent

Run the deploy script. It will:
- Verify the Lambda functions and IAM role exist
- Set Lambda timeouts to 30s and add Bedrock invoke permissions
- Create the Bedrock Agent (`aiops-assistant`) with the Kira system prompt
- Attach all 3 action groups with their OpenAPI schemas
- Prepare the agent

```bash
chmod +x bedrock/deploy.sh
./bedrock/deploy.sh
```

On Windows:
```powershell
.\bedrock\deploy.ps1
```

At the end, the script prints your **Agent ID** — keep it for the next step.

---

## Step 4: (Optional) Generate Sample Data

Populate CloudWatch Logs with realistic error scenarios to test Kira:

```bash
python3 scripts/generate_sample_data.py --region us-east-1
```

This writes 100 realistic log events (503 errors, OOM kills, connection pool exhaustion, etc.) to `/app/production`.

---

## Step 5: Run the Streamlit UI

```bash
cp .env.example .env
```

Edit `.env` and fill in your values:

```env
AWS_REGION=us-east-1
BEDROCK_AGENT_ID=<YOUR_AGENT_ID>
BEDROCK_AGENT_ALIAS_ID=TSTALIASID

# Optional — omit to use your AWS CLI profile / SSO / IAM role:
# AWS_ACCESS_KEY_ID=<YOUR_ACCESS_KEY>
# AWS_SECRET_ACCESS_KEY=<YOUR_SECRET_KEY>
# AWS_SESSION_TOKEN=<YOUR_SESSION_TOKEN>
```

Install dependencies and start the UI:

```bash
pip install -r requirements.txt
streamlit run app.py
```

Open **http://localhost:8501** in your browser.

---

## Project Structure

```
aiops-assistant/
├── app.py                  # Streamlit chat UI
├── config.env              # Lambda settings (Prometheus URL, log group, etc.)
├── verify-lambdas.txt      # Commands to verify Lambda deploy
├── iam/
│   ├── setup-iam.ps1       # Create IAM roles (Windows)
│   ├── setup-iam.sh        # Create IAM roles (Linux/macOS)
│   └── destroy-iam.ps1     # Remove IAM roles
├── lambdas/
│   ├── deploy-lambdas.ps1  # Deploy the 3 Lambda functions (Windows)
│   ├── deploy-lambdas.sh   # Deploy the 3 Lambda functions (Linux/macOS)
│   └── verify-lambdas.ps1  # Verify Lambda deploy
├── bedrock/
│   ├── deploy.ps1          # Bedrock Agent deployment (Windows)
│   ├── deploy.sh           # Bedrock Agent deployment (Linux/macOS)
│   ├── verify-deploy.ps1   # Verify Bedrock Agent deploy
│   ├── invoke-test.py      # Live agent test (used by verify-deploy.ps1)
│   └── destroy-deploy.ps1  # Remove Bedrock Agent
├── requirements.txt
├── .env.example
├── lambda/
│   ├── fetch_logs/
│   ├── fetch_metrics/
│   └── fetch_health/
├── schemas/
│   ├── fetch_logs.json
│   ├── fetch_metrics.json
│   └── fetch_health.json
└── scripts/
    └── generate_sample_data.py
```

---

## Sample Questions to Ask Kira

- Why are we seeing 503 errors in the last hour?
- Is CPU usage high across the boutique services?
- Check database connections and latency
- Are all pods healthy? Any restarts?
- What are the most frequent errors in the last 2 hours?

---

## Potential Issues

### Bedrock model access not enabled
The deploy script will fail at agent creation if model access hasn't been requested. Go to **AWS Console → Bedrock → Model access** and enable access for the model used in `bedrock/deploy.sh` before running the script.

### Prometheus URL unreachable from Lambda
`fetch_metrics` and `fetch_health` make outbound HTTP calls to the Prometheus ELB. If Lambda is deployed inside a VPC without a NAT gateway or internet gateway route, these calls will time out. Either:
- Keep Lambda outside a VPC (default), or
- Ensure the VPC has a route to the internet and the Prometheus ELB security group allows inbound on port 9090.

### Agent stuck in PREPARING state
After running `bedrock/deploy.sh`, the agent status shows `PREPARING`. This is normal and takes 30–60 seconds. If it stays in this state, check the Bedrock console for validation errors — usually caused by a malformed OpenAPI schema or a Lambda ARN that doesn't exist.

### Streamlit shows "NOT CONFIGURED"
The app requires `BEDROCK_AGENT_ID` and `BEDROCK_AGENT_ALIAS_ID` to be set in `.env`. If you started Streamlit before populating `.env`, stop it and restart — `load_dotenv()` only reads the file at startup.

```bash
# Stop and restart
pkill -f "streamlit run app.py"
streamlit run app.py
```

### fetch_logs returns no results
The default log group is `/eks/boutique/pods`. This group is only created after Fluent Bit starts shipping logs. Make sure `aws-for-fluent-bit` is running:

```bash
kubectl get pods -n amazon-cloudwatch
```

If the log group doesn't exist yet, run the sample data generator first (Step 5) which creates `/app/production`.

### fetch_health uses wrong cluster name
Update `DEFAULT_CLUSTER` in `config.env` and re-run `lambdas\deploy-lambdas.ps1` (or `lambdas/deploy-lambdas.sh`).

### Lambda execution role missing permissions
If `fetch_health` returns an access denied error on `eks:DescribeCluster`, the inline policy may not have propagated yet (IAM can take ~10–15 seconds). Wait and retry. If it persists, verify the inline policy is attached:

```bash
aws iam get-role-policy \
  --role-name aiops-lambda-role \
  --policy-name aiops-lambda-inline-policy
```

### AWS credentials not resolving in Streamlit
If `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are left blank in `.env`, boto3 falls back to the default credential chain (`~/.aws/credentials`, environment variables, IAM role). If none of those are configured, Bedrock calls will fail with an auth error. Either fill in the credentials in `.env` or ensure your terminal session has valid AWS credentials before starting Streamlit.
