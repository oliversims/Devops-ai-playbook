"""
Wire Lambda tools to the Bedrock agent (action groups).

Each tool = one Lambda function + one OpenAPI schema in ../schemas/

Called by deploy.ps1:
  py -3 add-action-groups.py <region> <agent_id> <account_id> <project_root>
"""

import sys

import boto3

# --- Arguments from deploy.ps1 ---
region = sys.argv[1]
agent_id = sys.argv[2]
account_id = sys.argv[3]
root_dir = sys.argv[4]

# --- Connect to Bedrock ---
client = boto3.client("bedrock-agent", region_name=region)

# --- The 3 tools: name, lambda function, schema file, description ---
tools = [
    (
        "fetch_logs",
        "aiops-fetch-logs",
        "fetch_logs.json",
        "Search CloudWatch Logs for errors, warnings, and application events",
    ),
    (
        "fetch_metrics",
        "aiops-fetch-metrics",
        "fetch_metrics.json",
        "Retrieve Prometheus metrics (CPU, memory, restarts)",
    ),
    (
        "fetch_service_health",
        "aiops-fetch-health",
        "fetch_health.json",
        "Check EKS cluster health, deployments, and crashing pods",
    ),
]

# --- Create each tool on the agent ---
for name, lambda_name, schema_file, description in tools:
    # Read the OpenAPI schema (fails with a clear error if the file is missing)
    with open(f"{root_dir}/schemas/{schema_file}", encoding="utf-8") as f:
        schema = f.read()

    # Lambda ARN Bedrock calls when the agent uses this tool
    lambda_arn = f"arn:aws:lambda:{region}:{account_id}:function:{lambda_name}"

    try:
        client.create_agent_action_group(
            agentId=agent_id,
            agentVersion="DRAFT",
            actionGroupName=name,
            description=description,
            actionGroupExecutor={"lambda": lambda_arn},
            apiSchema={"payload": schema},
        )
        print(f"  OK {name}")
    except client.exceptions.ConflictException:
        # Tool already exists from a previous deploy.ps1 run
        print(f"  OK {name} (already exists)")

print("\n  All action groups ready.")
