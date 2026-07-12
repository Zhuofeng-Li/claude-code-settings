---
name: greenland-deploy
description: Deploy models on Greenland SDB nodes via SSH and forward ports to local machine
triggers:
  - greenland
  - sdb
  - child node
  - worker node
  - deploy model
  - sglang serve
---

# Greenland Model Deployment Skill

Use this skill to deploy models on Greenland SDB instances and forward service ports to the local machine.

## Workflow Overview

1. User provides SSH connection info (SSM tunnel local port, child node IPs)
2. User provides the sglang serve command to run on a specific node
3. Deploy the model on the target node (main or child)
4. Port-forward the service back to a local port

## Prerequisites

User must have SSM tunnel already running in a separate terminal:
```bash
aws ssm start-session \
  --target '<instance-id>' \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["2222"],"localPortNumber":["<local-port>"]}' \
  --profile greenland \
  --region us-west-2
```

## SSH Connection Details

- **Main node SSH**: `ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60 -p <local-port> greenland-user@localhost`
- **Child node SSH (from main)**: port **2222**, NOT port 22!
  ```bash
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2222 greenland-user@<child-ip>
  ```

## Deployment Steps

### Step 1: Deploy on Main Node

```bash
# Run sglang in background on main node
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60 \
  -p <local-port> greenland-user@localhost \
  'nohup <sglang-command> > /tmp/sglang_<model-name>.log 2>&1 &'
```

### Step 2: Deploy on Child Node

```bash
# Run sglang in background on child node
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60 \
  -p <local-port> greenland-user@localhost \
  "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2222 greenland-user@<child-ip> \
  'nohup <sglang-command> > /tmp/sglang_<model-name>.log 2>&1 &'"
```

### Step 3: Check Deployment Status

Poll the log until you see "The server is fired up and ready to roll!":
```bash
ssh ... greenland-user@localhost \
  "ssh ... -p 2222 greenland-user@<child-ip> 'tail -5 /tmp/sglang_<model-name>.log'"
```

### Step 4: Port Forward

There are two cases:

**Case A: Service on main node → forward to local**
```bash
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60 \
  -p <local-port> -L 0.0.0.0:<local-target-port>:localhost:<remote-port> -N greenland-user@localhost &
```

**Case B: Service on child node → forward to local (two-hop)**

First, create a tunnel from main node to child node:
```bash
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60 \
  -p <local-port> greenland-user@localhost \
  'nohup ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2222 \
  -L 0.0.0.0:<intermediate-port>:localhost:<child-service-port> -N greenland-user@<child-ip> \
  > /tmp/forward_<model-name>.log 2>&1 &'
```

Then, forward from main node to local:
```bash
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60 \
  -p <local-port> -L 0.0.0.0:<local-target-port>:localhost:<intermediate-port> -N greenland-user@localhost &
```

### Step 5: Verify

```bash
curl -s http://localhost:<local-target-port>/v1/models
curl -s http://localhost:<local-target-port>/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "<model-name>", "messages": [{"role": "user", "content": "Hello"}], "max_tokens": 50}'
```

## Discovering Worker Nodes

```bash
ssh ... greenland-user@localhost "cat container.env | tr ' ' '\n' | grep VC_WORKER"
```

Key env vars:
- `VC_WORKER_NODES_HOSTS` - Comma-separated worker hostnames
- `VC_WORKER_NODES_NUM` - Number of workers
- `VC_MAIN_NODE_HOSTS` - Main node hostname

## Key Facts

- Main node SSH tunnel port: 2222 (forwarded to local via SSM)
- Child node SSH port: **2222** (not 22!)
- GPU type: Typically NVIDIA H200 (143GB each), 8 per node
- sglang is pre-installed at `/opt/sglang/`
- Container env file: `/home/greenland-user/container.env`
- `/shared` is Lustre filesystem mounted across all nodes

## Common Issues

1. **Child node SSH Permission denied**: Must use `-p 2222`, not default port 22
2. **LiteLLM "Missing credentials" error**: Set `OPENAI_API_KEY=EMPTY` — sglang doesn't validate the key but the openai client library requires it to be non-empty
3. **`--moe-runner-backend marlin` fails**: tilelang compilation error on some setups, remove this flag and retry
4. **`--mamba-scheduler-strategy` deprecated**: Use `--mamba-radix-cache-strategy` instead
5. **`--enable-flashinfer-allreduce-fusion` deprecated**: Use `--flashinfer-allreduce-fusion-backend=auto` instead
