---
name: greenland-fix-tilelang
description: Fix tilelang/marlin CUDA compilation errors (missing cuda/atomic, nv/target, cccl headers) on Greenland SDB nodes
triggers:
  - tilelang
  - cuda/atomic
  - nv/target
  - cccl
  - marlin
  - Hidden size mismatch
  - compilation terminated
---

# Fix tilelang/marlin CUDA Compilation on Greenland

Use this skill when deploying models that require tilelang JIT compilation (e.g., DeepSeek-V4 with `--moe-runner-backend marlin`) and encountering errors like:

- `fatal error: cuda/atomic: No such file or directory`
- `fatal error: nv/target: No such file or directory`
- `fatal error: cccl/cuda/std/utility: No such file or directory`
- `CUDA compiler and CUDA toolkit headers are incompatible`

## Root Cause

The sglang Docker image (e.g., `lmsysorg/sglang:v0.5.15`) ships with `nvidia/cu13/bin/nvcc` but does NOT include the CCCL (CUDA C++ Core Libraries) headers that tilelang needs for JIT kernel compilation. The nvcc include path at `/usr/local/lib/python3.12/dist-packages/nvidia/cu13/include/` is missing the `cuda/`, `nv/`, and `cccl/` subdirectories.

## Fix Steps

Run these commands on the target node (SSH in first):

```bash
# Step 1: Install nvidia-cuda-cccl package (provides compatible headers)
pip install --break-system-packages nvidia-cuda-cccl

# Step 2: Create symlinks from the installed CCCL to nvcc's include path
CCCL_SRC="$HOME/.local/lib/python3.12/site-packages/nvidia/cu13/include/cccl"
NVCC_INC="/usr/local/lib/python3.12/dist-packages/nvidia/cu13/include"

sudo ln -sf "$CCCL_SRC/cuda" "$NVCC_INC/cuda"
sudo ln -sf "$CCCL_SRC/nv" "$NVCC_INC/nv"
sudo ln -sf "$CCCL_SRC" "$NVCC_INC/cccl"

# Also link nv/ from the top-level installed location (has additional headers)
sudo ln -sf "$HOME/.local/lib/python3.12/site-packages/nvidia/cu13/include/nv" "$NVCC_INC/nv"

# Step 3: Disable CUDA version compatibility check (CCCL 13.3 vs nvcc 13.2 mismatch)
TOOLKIT_HEADER="$CCCL_SRC/cuda/std/__cccl/cuda_toolkit.h"
sudo sed -i 's/#ifndef CCCL_DISABLE_CTK_COMPATIBILITY_CHECK/#if 0 \/\/ DISABLED/' "$TOOLKIT_HEADER"
```

## Verification

```bash
# Verify all headers are accessible
ls "$NVCC_INC/cuda/atomic"    # should exist
ls "$NVCC_INC/nv/target"      # should exist  
ls "$NVCC_INC/cccl/cuda/std/utility"  # should exist
```

## One-liner (copy-paste for remote execution)

```bash
pip install --break-system-packages nvidia-cuda-cccl && \
CCCL_SRC="$HOME/.local/lib/python3.12/site-packages/nvidia/cu13/include/cccl" && \
NVCC_INC="/usr/local/lib/python3.12/dist-packages/nvidia/cu13/include" && \
sudo ln -sf "$CCCL_SRC/cuda" "$NVCC_INC/cuda" && \
sudo ln -sf "$HOME/.local/lib/python3.12/site-packages/nvidia/cu13/include/nv" "$NVCC_INC/nv" && \
sudo ln -sf "$CCCL_SRC" "$NVCC_INC/cccl" && \
sudo sed -i 's/#ifndef CCCL_DISABLE_CTK_COMPATIBILITY_CHECK/#if 0 \/\/ DISABLED/' "$CCCL_SRC/cuda/std/__cccl/cuda_toolkit.h" && \
echo "CCCL fix applied successfully"
```

## Notes

- This fix is needed per-node (each child node needs it independently)
- The fix persists until the container is restarted
- The `--break-system-packages` flag is needed because the sglang image uses system Python without a venv
- After fixing, marlin backend models like DeepSeek-V4-Flash can be deployed normally
- The "Hidden size mismatch" error is a DIFFERENT issue — it's a sglang triton fused_moe bug with DeepSeek-V4 FP8, unrelated to this fix. Use `--moe-runner-backend marlin` to avoid it
