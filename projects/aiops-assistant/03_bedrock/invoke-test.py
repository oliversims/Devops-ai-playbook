# Quick Bedrock Agent invoke test — called by verify-deploy.ps1
# Needs: pip install boto3  (or pip install -r ../requirements.txt)

import os
import uuid
import boto3

agent_id = os.environ["BEDROCK_AGENT_ID"]
region = os.environ.get("AWS_REGION", "us-east-1")
alias_id = os.environ.get("BEDROCK_AGENT_ALIAS_ID", "TSTALIASID")

client = boto3.client("bedrock-agent-runtime", region_name=region)
response = client.invoke_agent(
    agentId=agent_id,
    agentAliasId=alias_id,
    sessionId=str(uuid.uuid4()),
    inputText="Are all pods healthy in the boutique namespace? Answer in one sentence.",
)

print("Agent response:")
for event in response["completion"]:
    chunk = event.get("chunk", {})
    if "bytes" in chunk:
        print(chunk["bytes"].decode(), end="")
print()
