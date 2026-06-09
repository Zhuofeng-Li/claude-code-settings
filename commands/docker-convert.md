# Docker Convert

Convert a uv-based Python project (with `pyproject.toml` / `uv.lock`) into a Docker environment.

## Steps

1. **Read project metadata** — read `pyproject.toml` (and `uv.lock` if present) to extract:
   - `requires-python` → Python version
   - `dependencies` → detect GPU/ML libs (torch, transformers, vllm, flash-attn, etc.)
   - optional dependency groups (e.g. `[project.optional-dependencies]`)

2. **Choose base image** based on detected dependencies:
   - Has `torch` / `vllm` / `flash-attn` / `triton` → `nvcr.io/nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04`
   - Has `transformers` / `accelerate` but no torch listed → `nvcr.io/nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04`
   - Pure CPU project → `python:3.XX-slim` (match `requires-python`)
   - Already has a `FROM` comment hint in pyproject → respect it

3. **Generate `Dockerfile`** at project root using this template pattern:
   ```dockerfile
   FROM <base_image>

   # System deps (add extras if detected: git for VCS deps, build-essential for compiled packages)
   RUN apt-get update && apt-get install -y \
       python3.XX python3.XX-dev python3-pip \
       git curl wget build-essential \
       && rm -rf /var/lib/apt/lists/*

   # Install uv
   RUN pip3 install uv --quiet

   WORKDIR /workspace

   # Copy lock file first for layer caching
   COPY pyproject.toml uv.lock* ./

   # Install dependencies (reproducible from lock file if present)
   RUN uv pip install --system -e ".[all_extras_if_any]"

   # Copy source
   COPY . .

   CMD ["/bin/bash"]
   ```

4. **Generate `docker-build.sh`** — a convenience build+run script:
   ```bash
   #!/bin/bash
   # Usage: bash docker-build.sh [run]
   IMAGE=<project-name>:dev
   docker build -t $IMAGE .
   if [ "$1" = "run" ]; then
     docker run --gpus all -it --rm -v $(pwd):/workspace $IMAGE
   fi
   ```

5. **Check for existing Dockerfile** — if one already exists, print a diff/comparison and ask whether to overwrite.

6. **Validate** — run `docker build -t <project>:dev .` in dry-run mode (`--no-cache --progress=plain`) if Docker is available, and report any layer failures.

## Key rules

- Always use `uv pip install --system` inside Docker (not bare `pip`), so the same tool is used inside and outside container
- Copy `uv.lock` before source for better layer caching
- If `uv.lock` is absent, warn the user: "reproducibility not guaranteed — consider running `uv lock` first"
- For GPU projects, default `--gpus all` in the run command
- Never hardcode absolute paths — use `WORKDIR /workspace` and relative paths
- If the project has a `[tool.uv] torch-backend = "auto"` in pyproject.toml, it needs CUDA base image regardless of explicit torch dep
