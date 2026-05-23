---
name: monitor-and-fix
description: Run a shell script, continuously monitor its output for errors, and autonomously diagnose and fix issues until the script runs successfully. Use this skill when the user wants to launch a script and have Claude watch it and fix problems automatically. Trigger phrases include: "运行并监控", "持续监控", "run and monitor", "watch and fix", "帮我跑这个脚本如果有问题就修", "自动修复", "monitor and fix". The user must provide a script path as the argument (e.g., `/path/to/launch_server.sh`).
---

# Monitor and Fix

Run a script, tail its output, detect errors, diagnose root causes, and apply fixes — repeating until the script is healthy or a hard limit is hit.

## Inputs

- **$ARGUMENTS** — absolute or relative path to the shell script to run (required)

## Workflow

### Step 1: Validate the script

```bash
# Confirm the file exists and is executable
ls -la $ARGUMENTS
```

If it does not exist, stop and tell the user. If it is not executable, run `chmod +x $ARGUMENTS` first.

### Step 2: Launch the script and capture output

Run the script in the background, redirecting both stdout and stderr to a log file:

```bash
LOG=/tmp/monitor_fix_$(basename $ARGUMENTS .sh).log
bash $ARGUMENTS > $LOG 2>&1 &
SERVER_PID=$!
echo "Launched PID $SERVER_PID, logging to $LOG"
```

### Step 3: Poll for status in a loop

Every 15–30 seconds, read new log lines with `tail -100 $LOG`. After each read:

1. **Check if the process is still alive**: `kill -0 $SERVER_PID 2>&1`
2. **Scan for success signals** — lines like `Uvicorn running`, `Application startup complete`, `Server is ready`, `Started server process`, `vllm serve` endpoint ready messages, etc. If found → report success and stop monitoring.
3. **Scan for error signals** — lines containing `ERROR`, `Error`, `Traceback`, `RuntimeError`, `CUDA`, `OOM`, `Failed`, `Exception`, `assert`, `killed` etc.

### Step 4: Diagnose and fix errors

When an error is detected:

1. Read the **full error context** (surrounding 20–30 lines) from the log.
2. Identify root cause. Common patterns and fixes:

| Error pattern | Likely cause | Fix |
|---|---|---|
| `Error 802: system not yet initialized` | CUDA persistence mode off / driver not warmed up | `sudo nvidia-smi -pm 1`; add warm-up call before vllm |
| `CUDA out of memory` | Too many GPUs requested or batch size too large | Reduce `--tensor-parallel-size` or `--max-num-batched-tokens` in the script |
| `No module named 'xxx'` | Missing Python package | `uv pip install xxx` in the project venv |
| `Address already in use` | Port conflict — previous server still running | Kill the old process: `fuser -k <port>/tcp` |
| `FileNotFoundError` | Config or model path missing | Check paths in the script / YAML config |
| `Connection refused` (model download) | Network / HuggingFace auth issue | Check `HF_TOKEN` env var or `huggingface-cli login` |
| Process exited immediately (code ≠ 0) | Script-level error | Read the full log and fix the offending line |

3. Apply the fix by editing the relevant file with the Edit tool, or running a shell command.
4. Kill the crashed process if still alive:
```bash
kill $SERVER_PID 2>/dev/null; sleep 2
```

### Step 5: Restart and repeat

After applying the fix, go back to **Step 2** — relaunch the script with a fresh log file. Increment an attempt counter. If attempts exceed **5**, stop and report to the user with a summary of all fixes tried and the current error.

### Step 6: Report outcome

**On success:**
```
✓ Server is up after N attempt(s).
PID: <pid>
Log: <log path>
Fixes applied:
  1. <description of fix 1>
  2. <description of fix 2>
```

**On giving up:**
```
Stopped after 5 attempts. Last error:
<error excerpt>

Fixes tried:
  1. ...
  2. ...

Recommendation: <what to try next>
```

## Important rules

- **Never skip persistence mode check** — always run `nvidia-smi -pm 1` before launching any vLLM / GPU script if not already enabled.
- **Read the actual error before guessing** — always include several lines of context around the error line.
- **Do not busy-wait** — use `sleep 15` between polls, not tight loops.
- **Prefer targeted fixes** — change only the minimum needed (a flag, an env var, a missing package). Do not rewrite the whole script.
- **Communicate progress** — after each poll cycle, print a one-line status to the user so they know monitoring is active.
