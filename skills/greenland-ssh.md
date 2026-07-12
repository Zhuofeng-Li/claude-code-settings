---
name: greenland-ssh
description: Connect to Greenland SDB instances and child nodes via SSH
triggers:
  - greenland
  - sdb
  - child node
  - worker node
---

# Greenland SSH Connection Skill

Use this skill when connecting to Greenland SDB (Scalable Developer Box) instances.

## Connection Architecture

Greenland uses a two-hop SSH setup:
1. **SSM tunnel**: Creates a port forward from local machine to the SDB instance
2. **SSH**: Connects through the tunnel to the container

## Step 1: SSM Tunnel (user runs in separate terminal)

```bash
aws ssm start-session \
  --target '<instance-id>' \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["2222"],"localPortNumber":["<local-port>"]}' \
  --profile greenland \
  --region us-west-2
```

## Step 2: SSH to Main Node

```bash
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60 -p <local-port> greenland-user@localhost
```

## Step 3: SSH to Child/Worker Nodes

**IMPORTANT**: Child nodes use port 2222, NOT the default port 22.

```bash
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2222 greenland-user@<child-node-ip>
```

## Discovering Worker Nodes

Worker node hostnames and IPs are in the container environment:

```bash
# On the main node:
grep VC_WORKER_NODES /home/greenland-user/container.env
# Or parse:
cat container.env | tr ' ' '\n' | grep VC_WORKER
```

Key env vars:
- `VC_WORKER_NODES_HOSTS` - Comma-separated list of worker node hostnames
- `VC_WORKER_NODES_NUM` - Number of worker nodes
- `VC_MAIN_NODE_HOSTS` - Main node hostname

## Running Commands on Child Nodes (from local)

For one-shot commands through the full chain:

```bash
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60 \
  -p <local-port> greenland-user@localhost \
  "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2222 greenland-user@<child-ip> '<command>'"
```

## Running Background Services on Child Nodes

```bash
ssh ... greenland-user@localhost \
  "ssh ... -p 2222 greenland-user@<child-ip> 'nohup <command> > /tmp/service.log 2>&1 &'"
```

## Shared Storage

- `/shared` is a Lustre filesystem mounted across all nodes
- Use it for sharing data, scripts, and configs between main and worker nodes
- User directories may not be writable; use `/shared/dev/` for scratch space

## Key Facts

- Main node SSH port: 2222 (tunneled to local via SSM)
- Child node SSH port: **2222** (not 22!)
- Authentication: publickey (with PermitEmptyPasswords on internal port)
- GPU type: Typically NVIDIA H200 (143GB each), 8 per node
- sglang is pre-installed at `/opt/sglang/`
- Container env file: `/home/greenland-user/container.env`
