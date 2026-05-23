---
name: ml-docker-convert
description: >
  Dockerize Python projects for LLM/ML research. Use this skill whenever the user:
  - Gives you Python files and wants to run them in Docker
  - Describes a workflow like "I run train.py with these args" and wants a Docker setup
  - Asks you to "dockerize", "containerize", "wrap in Docker", or "create a Dockerfile" for their project
  - Has an LLM/ML script and wants a reproducible environment

  Proactively invoke this skill when the user shares Python files with ML/LLM imports (torch, transformers, etc.)
  and mentions running or deploying them, even if they don't explicitly say "Docker".
---

# Docker Convert Skill

Your goal: analyze the user's Python project, produce a complete Docker setup, and make it **one-command launchable** via a `run.sh` script. The user should be able to clone the repo, run `./run.sh`, and have everything work — no manual steps.

---

## Step 1: Gather Information

**If the user gave you files**, read them to understand:
- Entry point(s): which file(s) get run, with what arguments
- Dependencies: scan imports, check for `requirements.txt`, `pyproject.toml`, `setup.py`, `environment.yml`
- GPU usage: look for `torch.cuda`, `device="cuda"`, `accelerate`, CUDA-specific code
- External services: databases, Redis, API servers, model hubs (HuggingFace)
- Data paths: hardcoded paths, arguments that point to datasets or model checkpoints
- Environment variables: API keys (OPENAI_API_KEY, HF_TOKEN, etc.), config flags
- Ports: any web servers or APIs that need to be exposed

**If the user described their workflow**, extract:
- What command(s) they run (e.g., `python train.py --model llama --data /data`)
- What the script does (training, inference, evaluation, serving)
- Any services or dependencies they mention
- Whether they need GPU

**Ask for clarification only if critical info is missing** — e.g., if you can't tell whether GPU is needed, or if there's no `requirements.txt` and imports aren't enough to infer deps.

---

## Step 2: Choose the Right Base Image

| Scenario | Base Image |
|----------|-----------|
| Needs GPU + PyTorch (most LLM training/inference) | `pytorch/pytorch:2.3.1-cuda12.1-cudnn8-runtime` |
| Needs GPU but no specific PyTorch version | `nvidia/cuda:12.1.0-cudnn8-runtime-ubuntu22.04` |
| CPU-only Python project | `python:3.11-slim` |
| Jupyter notebook workflow | `pytorch/pytorch:2.3.1-cuda12.1-cudnn8-runtime` + install jupyterlab |
| vLLM / inference server | `vllm/vllm-openai:latest` |

Default to the PyTorch CUDA image for LLM research unless GPU is clearly not needed.

---

## Step 3: Write the Dockerfile

**Dependency management — ALWAYS use `uv`, NEVER pip or Conda:**
- Install `uv` via the official installer script, then use `uv venv` + `uv pip install`.
- Never use `pip install` or `conda` anywhere.

**Layer order for caching:**
1. Base image + system packages + uv
2. Python deps (copy requirements first, then install — avoids reinstalling on code changes)
3. Application code

**Standard Dockerfile:**

```dockerfile
FROM pytorch/pytorch:2.3.1-cuda12.1-cudnn8-runtime

RUN apt-get update && apt-get install -y \
    git wget curl \
    && rm -rf /var/lib/apt/lists/*

# Install uv — the only package manager used here
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.cargo/bin:$PATH"

WORKDIR /app

# Install deps first (cached unless requirements.txt changes)
COPY requirements.txt .
RUN uv venv .venv && uv pip install --no-cache-dir -r requirements.txt

ENV PATH="/app/.venv/bin:$PATH"
ENV VIRTUAL_ENV="/app/.venv"
ENV PYTHONUNBUFFERED=1
ENV HF_HOME=/root/.cache/huggingface

COPY . .

CMD ["python", "train.py"]
```

If there's no `requirements.txt`, generate one from imports, pinning major versions (e.g., `torch>=2.0`, `transformers>=4.35`).

---

## Step 4: Build and Verify

```bash
docker build -t <project-name>:dev .
```

Fix any build errors (missing packages, version conflicts, system deps) and rebuild until it succeeds.

---

## Step 5: Generate `run.sh` — the One-Click Launcher (REQUIRED)

**Always generate this file.** It is the primary way users will interact with the container.

The script must:
- Auto-detect GPU availability and add `--gpus all` only if `nvidia-smi` succeeds
- Build the image if it doesn't exist (or if `--build` flag is passed)
- Load `.env` if it exists
- Mount all relevant volumes
- Be immediately runnable: `./run.sh`

**Template:**

```bash
#!/usr/bin/env bash
set -euo pipefail

IMAGE="<project-name>:dev"
CONTAINER_NAME="<project-name>"

# ── Build ──────────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--build" ]] || ! docker image inspect "$IMAGE" &>/dev/null; then
  echo "[run.sh] Building $IMAGE ..."
  docker build -t "$IMAGE" .
fi

# ── GPU detection ──────────────────────────────────────────────────────────────
GPU_FLAG=""
if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
  GPU_FLAG="--gpus all"
  echo "[run.sh] GPU detected — running with $GPU_FLAG"
else
  echo "[run.sh] No GPU detected — running CPU-only"
fi

# ── Env file ───────────────────────────────────────────────────────────────────
ENV_FLAG=""
if [[ -f .env ]]; then
  ENV_FLAG="--env-file .env"
  echo "[run.sh] Loading environment from .env"
fi

# ── Run ────────────────────────────────────────────────────────────────────────
echo "[run.sh] Starting $CONTAINER_NAME ..."
docker run --rm \
  --name "$CONTAINER_NAME" \
  $GPU_FLAG \
  $ENV_FLAG \
  -v "$(pwd)/data:/app/data" \
  -v "$HOME/.cache/huggingface:/root/.cache/huggingface" \
  "$IMAGE"
```

**Customize per project:**
- Remove `-v "$(pwd)/data:/app/data"` if there's no data directory
- Add `-p 8000:8000` (or relevant port) if the project is a server
- Add `-it` if the container is interactive
- For Jupyter: add `-p 8888:8888` and print the URL after start
- Remove `--rm` if the user needs to inspect the container after it exits

After writing, make it executable:
```bash
chmod +x run.sh
```

Tell the user: "Run `./run.sh` to build (if needed) and start the container. Pass `--build` to force a rebuild."

---

## Step 6: Write `.dockerignore` and `.env.example` (Always)

**`.dockerignore`** — always generate this:
```
.env
*.env
.env.*
__pycache__/
*.pyc
*.pyo
.git/
.venv/
*.tar.gz
```

**`.env.example`** — generate if there are any secrets/env vars:
```
# Copy to .env and fill in your values
HF_TOKEN=
OPENAI_API_KEY=
```

---

## Step 7: Write `README.docker.md` (Minimal)

Keep it to exactly what's needed to run. No theory.

```markdown
# Quick Start (Docker)

## Run (one command)

```bash
./run.sh
```

That's it. The script auto-detects GPU, loads `.env` if present, and builds the image on first run.

## Force rebuild

```bash
./run.sh --build
```

## Environment variables

```bash
cp .env.example .env
# Edit .env with your values
```
```

---

## Common Patterns

**Multi-GPU training:**
```dockerfile
CMD ["torchrun", "--nproc_per_node=4", "train.py"]
```

**Jupyter server** — add to `run.sh`:
```bash
-p 8888:8888
```
And in Dockerfile:
```dockerfile
EXPOSE 8888
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--no-browser", "--allow-root"]
```
After start, print: `Open http://localhost:8888 in your browser`

**vLLM inference server:**
```dockerfile
EXPOSE 8000
CMD ["python", "-m", "vllm.entrypoints.openai.api_server", "--model", "meta-llama/Llama-2-7b-chat-hf"]
```
Add `-p 8000:8000` to `run.sh`.

**Sharing with teammates who can't pull from a registry:**
```bash
docker save <project-name>:dev | gzip > <project-name>.tar.gz
# Recipient:
docker load < <project-name>.tar.gz
./run.sh
```

---

## Required Outputs Checklist

Every docker-convert invocation must produce:

- [ ] `Dockerfile`
- [ ] `requirements.txt` (generate if missing)
- [ ] `run.sh` (the one-click launcher — **always required**)
- [ ] `.dockerignore`
- [ ] `.env.example` (if secrets are involved)
- [ ] `README.docker.md`
- [ ] Build result (succeeded / what was fixed)
- [ ] Final confirmation: "Run `./run.sh` to start"

`docker-compose.yml` is optional — only generate it for multi-service setups or if the `run.sh` would become unwieldy.

Keep explanations concise. The user is a researcher. Focus on making it work in one command.
