---
name: kill-gpu
description: Kill all processes occupying GPU resources on the current machine. Use this skill whenever the user wants to free up GPU memory, kill GPU processes, release a stuck GPU, clear GPU usage, kill CUDA processes, or when they say things like "kill all GPU jobs", "free the GPU", "someone is using my GPU", "GPU memory is full", "clear NVIDIA GPU", "释放 GPU", "kill 掉 GPU 进程", or any variation of wanting to terminate processes holding onto GPU resources. Invoke this skill even if the user just asks to "check what's using the GPU" since the workflow starts with detection.
---

# Kill GPU Processes

This skill frees up GPU resources by finding and killing all processes that are occupying the GPU. The key challenge is that **`nvidia-smi` alone sometimes misses processes** — a process can hold a CUDA context (keeping the GPU busy/locked) without allocating GPU memory that shows up in `nvidia-smi`. This skill uses four complementary detection methods to catch everything.

## Why nvidia-smi alone isn't enough

`nvidia-smi --query-compute-apps` only shows processes with active GPU memory allocations. But a process can:
- Hold a CUDA context open without allocating memory (e.g., after freeing tensors but before exiting)
- Hold a `/dev/nvidia*` file descriptor open (blocking other exclusive-mode users)
- Be in a zombie or stuck state that nvidia-smi doesn't report

That's why this skill combines `nvidia-smi`, `fuser`, `lsof`, and a `/proc` scan.

## Workflow

### Step 1: Determine intent

Check if the user wants to:
- **Just kill** everything GPU-related (most common)
- **Inspect first** then decide what to kill
- **Kill specific processes** (e.g., only Python jobs, or only a specific user's jobs)
- **Dry run** to see what would be killed without actually doing it

If unclear, default to showing what will be killed and asking for confirmation before killing.

### Step 2: Use the bundled script

The script at `scripts/kill_gpu_processes.sh` handles all detection methods. Run it:

```bash
# Dry run first to see what's there
bash ~/.claude/skills/kill-gpu/scripts/kill_gpu_processes.sh -n -v

# Actually kill (may need sudo if processes belong to other users)
bash ~/.claude/skills/kill-gpu/scripts/kill_gpu_processes.sh -v

# Or with sudo if needed
sudo bash ~/.claude/skills/kill-gpu/scripts/kill_gpu_processes.sh -v
```

### Step 3: If processes remain after killing

Sometimes processes don't die immediately or require escalation. Try these in order:

1. **Wait and retry** — CUDA cleanup can take a few seconds:
   ```bash
   sleep 3 && nvidia-smi
   ```

2. **Use SIGTERM first, then SIGKILL** — some processes need a graceful shutdown:
   ```bash
   sudo bash ~/.claude/skills/kill-gpu/scripts/kill_gpu_processes.sh -s SIGTERM -v
   sleep 2
   sudo bash ~/.claude/skills/kill-gpu/scripts/kill_gpu_processes.sh -v  # SIGKILL
   ```

3. **Check for processes in uninterruptible sleep (D state)** — these can't be killed:
   ```bash
   ps aux | awk '$8 == "D" {print $0}'
   ```
   D-state processes require a driver reset or system reboot.

4. **Reset the NVIDIA driver** (nuclear option, disconnects all GPU users):
   ```bash
   sudo nvidia-smi --gpu-reset
   # Or if that fails:
   sudo rmmod nvidia_uvm && sudo modprobe nvidia_uvm
   ```

### Step 4: Verify GPU is free

```bash
nvidia-smi  # Should show 0 processes and free memory
```

## Manual detection commands (if the script can't run)

If the script can't be executed, perform these steps manually:

```bash
# Method 1: nvidia-smi (memory-using processes only)
nvidia-smi --query-compute-apps=pid,used_memory,name --format=csv

# Method 2: fuser (all processes with open device handles)
sudo fuser /dev/nvidia* /dev/nvidiactl /dev/nvidia-uvm 2>/dev/null

# Method 3: lsof (verbose — shows what each process has open)
sudo lsof /dev/nvidia* /dev/nvidiactl /dev/nvidia-uvm 2>/dev/null

# Method 4: Combine and kill
{ nvidia-smi --query-compute-apps=pid --format=csv,noheader; \
  sudo fuser /dev/nvidia* 2>/dev/null | tr ' ' '\n'; } \
  | sort -u | grep -E '^[0-9]+$' | xargs -r sudo kill -9
```

## Common scenarios

**"GPU shows memory used but nvidia-smi shows no processes"**
→ Use fuser/lsof — a process has a device handle open without active memory allocation.

**"Permission denied when killing"**
→ Run with `sudo`. Processes may belong to another user or a system service.

**"Process keeps restarting"**
→ It's managed by a supervisor (systemd, tmux, screen, nohup). Find the parent:
```bash
ps -p <pid> -o ppid=  # get parent PID
ps -p <ppid> -o comm=  # see what the parent is
```

**"GPU memory shows 0 but GPU utilization is still high"**
→ The GPU is in a compute mode that doesn't allocate memory (rare). Check:
```bash
nvidia-smi dmon -s u  # monitor GPU utilization live
```
