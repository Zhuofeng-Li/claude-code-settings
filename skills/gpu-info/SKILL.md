---
name: gpu-info
description: Print all processes currently occupying GPU resources, showing PID, memory usage, running command, and working directory (CWD). Use this skill whenever the user wants to inspect GPU usage, see what's running on the GPU, find which folder a GPU process is from, check GPU process details, or says things like "打印 GPU 进程", "查看 GPU 占用", "谁在用 GPU", "GPU 进程在哪个文件夹", "show GPU processes", "what's using the GPU", "which script is running on GPU". Do NOT use this skill when the user wants to kill GPU processes (use kill-gpu instead).
---

# GPU Process Info

This skill prints detailed information about all processes currently occupying GPU resources, including PID, memory usage, the exact command being run, and the working directory (so you can identify which project/folder the job belongs to).

## Workflow

### Step 1: Run the detection command

Execute this single command — it queries `nvidia-smi` for GPU processes and enriches each result with cmdline and CWD from `/proc`:

```bash
nvidia-smi --query-compute-apps=pid,used_memory,process_name --format=csv,noheader 2>/dev/null | while IFS=', ' read pid mem name; do
  echo "=== PID $pid | $name | ${mem} ==="
  echo "CMD: $(cat /proc/$pid/cmdline 2>/dev/null | tr '\0' ' ')"
  echo "CWD: $(readlink /proc/$pid/cwd 2>/dev/null)"
  echo ""
done
```

### Step 2: Format and present results

Present findings as a clear table:

| PID | 显存 | 工作目录 | 运行命令 |
|-----|------|---------|---------|
| ... | ...  | ...     | ...     |

Then add a short summary:
- Which folder(s) the jobs are running from
- What script(s) are being executed
- Notable flags (e.g., `--tp 4` for tensor parallel, benchmark names, etc.)

### Step 3: Handle edge cases

**No GPU processes found:**
```
nvidia-smi shows no running compute processes.
```

**nvidia-smi not available:**
- Fall back to scanning `/proc` for open `/dev/nvidia*` handles:
```bash
for pid in /proc/[0-9]*/fd; do
  p=${pid%/fd}; p=${p#/proc/}
  ls -la $pid 2>/dev/null | grep -q nvidia && \
    echo "PID $p: $(cat /proc/$p/cmdline 2>/dev/null | tr '\0' ' ') | CWD: $(readlink /proc/$p/cwd 2>/dev/null)"
done
```

**Permission denied on /proc/$pid/cwd:**
- The process belongs to another user; try with `sudo readlink /proc/$pid/cwd`

## Example output

```
=== PID 626003 | python | 78748 MiB ===
CMD: .venv/bin/python qvq_inference_vllm.py --benchmarks EMMA MMMU VStar --tp 4 --batch-size 8
CWD: /home/ubuntu/ipf/test/qixin/VisualReasoning
```
