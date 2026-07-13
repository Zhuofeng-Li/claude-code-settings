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
3. Apply tilelang fix if needed (see greenland-fix-tilelang skill)
4. Deploy the model on the target node (main or child)
5. Port-forward the service back to a local port
6. Verify with curl

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

## SSH Connection Commands

### Main node (from local machine)
```bash
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60 -p <local-port> greenland-user@localhost
```

### Child node (from main node) — IMPORTANT: port 2222!
```bash
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2222 greenland-user@<child-ip>
```

### One-shot command on child node (from local machine)
```bash
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60 \
  -p <local-port> greenland-user@localhost \
  "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2222 greenland-user@<child-ip> '<command>'"
```

## Deployment Steps

### Step 1: Deploy on Main Node

```bash
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60 \
  -p <local-port> greenland-user@localhost \
  'nohup <sglang-command> > /tmp/sglang_<model-name>.log 2>&1 &'
```

### Step 2: Deploy on Child Node

```bash
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60 \
  -p <local-port> greenland-user@localhost \
  "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2222 greenland-user@<child-ip> \
  'nohup <sglang-command> > /tmp/sglang_<model-name>.log 2>&1 &'"
```

### Step 3: Check Deployment Status

Poll the log until you see "The server is fired up and ready to roll!":
```bash
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60 \
  -p <local-port> greenland-user@localhost \
  "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2222 greenland-user@<child-ip> \
  'tail -5 /tmp/sglang_<model-name>.log'"
```

### Step 4: Port Forward

**Case A: Service on main node → forward to local**
```bash
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60 \
  -p <local-port> -L 0.0.0.0:<local-target-port>:localhost:<remote-port> -N greenland-user@localhost &
```

**Case B: Service on child node → forward to local (two-hop)**

First, forward on main node (child → main):
```bash
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60 \
  -p <local-port> greenland-user@localhost \
  'nohup ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2222 \
  -L 0.0.0.0:<intermediate-port>:localhost:<child-service-port> -N greenland-user@<child-ip> \
  > /tmp/forward_<model-name>.log 2>&1 &'
```

Then, forward to local (main → local):
```bash
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60 \
  -p <local-port> -L 0.0.0.0:<local-target-port>:localhost:<intermediate-port> -N greenland-user@localhost &
```

### Step 5: Verify

```bash
curl -s http://localhost:<local-target-port>/v1/models
```

## Discovering Worker Nodes

```bash
ssh ... greenland-user@localhost "cat container.env | tr ' ' '\n' | grep VC_WORKER"
```

Key env vars:
- `VC_WORKER_NODES_HOSTS` — comma-separated worker hostnames
- `VC_WORKER_NODES_NUM` — number of workers
- `VC_MAIN_NODE_HOSTS` — main node hostname

## Key Facts

- Main node SSH tunnel port: 2222 (forwarded to local via SSM)
- **Child node SSH port: 2222** (NOT 22!)
- GPU type: Typically NVIDIA H200 (143GB each), 8 per node
- sglang is pre-installed at `/opt/sglang/`
- Container env file: `/home/greenland-user/container.env`
- `/shared` is Lustre filesystem mounted across all nodes (for sharing data between nodes)

## Common Issues

1. **Child node SSH "Permission denied"**: Must use `-p 2222`, not default port 22
2. **LiteLLM "Missing credentials" error**: Set `OPENAI_API_KEY=EMPTY` — sglang doesn't validate the key but the openai client library requires it non-empty
3. **tilelang compilation errors** (`cuda/atomic`, `nv/target`, `cccl/`): Use the `greenland-fix-tilelang` skill to install CCCL headers
4. **"Hidden size mismatch" with DeepSeek-V4**: Use `--moe-runner-backend marlin` instead of default triton backend
5. **CUDA graph capture hangs (GPU 0% util, log frozen)**: Model uses too much memory for graph capture. Add `--mem-fraction-static 0.8` or `--disable-cuda-graph`
6. **Deprecated flags**:
   - `--mamba-scheduler-strategy` → use `--mamba-radix-cache-strategy`
   - `--enable-flashinfer-allreduce-fusion` → use `--flashinfer-allreduce-fusion-backend=auto`
