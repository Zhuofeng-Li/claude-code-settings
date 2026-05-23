#!/bin/bash
# kill_gpu_processes.sh
# Kill all processes occupying GPU resources using multiple detection methods.
# Sometimes nvidia-smi doesn't show all GPU-occupying processes, so we use
# fuser and lsof as fallbacks to find processes holding open device handles.

set -e

DRY_RUN=false
VERBOSE=false
SIGNAL="SIGKILL"

usage() {
    echo "Usage: $0 [-n] [-v] [-s SIGNAL]"
    echo "  -n  Dry run (show what would be killed, don't kill)"
    echo "  -v  Verbose output"
    echo "  -s  Signal to send (default: SIGKILL)"
    exit 1
}

while getopts "nvs:" opt; do
    case $opt in
        n) DRY_RUN=true ;;
        v) VERBOSE=true ;;
        s) SIGNAL="$OPTARG" ;;
        *) usage ;;
    esac
done

log() {
    if [ "$VERBOSE" = true ]; then
        echo "[INFO] $*"
    fi
}

# Collect PIDs from multiple sources
declare -A ALL_PIDS

# Method 1: nvidia-smi - finds processes with allocated GPU memory
if command -v nvidia-smi &>/dev/null; then
    log "Checking nvidia-smi for GPU processes..."
    # Get PIDs from nvidia-smi (processes with GPU memory allocation)
    while IFS= read -r pid; do
        if [ -n "$pid" ] && [ "$pid" != "0" ]; then
            ALL_PIDS["$pid"]="nvidia-smi"
        fi
    done < <(nvidia-smi --query-compute-apps=pid --format=csv,noheader 2>/dev/null || true)

    # Also check graphics processes
    while IFS= read -r pid; do
        if [ -n "$pid" ] && [ "$pid" != "0" ]; then
            ALL_PIDS["$pid"]="nvidia-smi(graphics)"
        fi
    done < <(nvidia-smi --query-accounted-apps=pid --format=csv,noheader 2>/dev/null || true)
else
    echo "Warning: nvidia-smi not found"
fi

# Method 2: fuser - finds processes with open file handles to /dev/nvidia*
# This catches processes that have a CUDA context but no memory allocation shown in nvidia-smi
if command -v fuser &>/dev/null; then
    log "Checking fuser for /dev/nvidia* file handles..."
    while IFS= read -r pid; do
        if [ -n "$pid" ]; then
            ALL_PIDS["$pid"]="fuser(/dev/nvidia*)"
        fi
    done < <(fuser /dev/nvidia* /dev/nvidiactl /dev/nvidia-uvm /dev/nvidia-uvm-tools 2>/dev/null | tr ' ' '\n' | grep -E '^[0-9]+$' || true)
fi

# Method 3: lsof - another way to find processes with open GPU device handles
if command -v lsof &>/dev/null; then
    log "Checking lsof for /dev/nvidia* file handles..."
    while IFS= read -r pid; do
        if [ -n "$pid" ]; then
            ALL_PIDS["$pid"]="lsof(/dev/nvidia*)"
        fi
    done < <(lsof /dev/nvidia* /dev/nvidiactl /dev/nvidia-uvm /dev/nvidia-uvm-tools 2>/dev/null | awk 'NR>1 {print $2}' | sort -u || true)
fi

# Method 4: /proc filesystem - scan for processes with open nvidia device files
# Useful when fuser/lsof aren't available
log "Scanning /proc for nvidia device handles..."
for pid_dir in /proc/[0-9]*/fd; do
    pid=$(echo "$pid_dir" | grep -oE '/proc/([0-9]+)/' | grep -oE '[0-9]+')
    if [ -z "$pid" ]; then continue; fi
    # Check if this process has any nvidia device open
    if ls -la "$pid_dir" 2>/dev/null | grep -q 'nvidia'; then
        ALL_PIDS["$pid"]="proc(fd scan)"
    fi
done

# Report what we found
if [ ${#ALL_PIDS[@]} -eq 0 ]; then
    echo "No GPU processes found."
    exit 0
fi

echo "Found ${#ALL_PIDS[@]} GPU process(es):"
for pid in "${!ALL_PIDS[@]}"; do
    cmdline=$(cat /proc/"$pid"/cmdline 2>/dev/null | tr '\0' ' ' | head -c 100 || echo "<unknown>")
    echo "  PID $pid (via ${ALL_PIDS[$pid]}): $cmdline"
done

if [ "$DRY_RUN" = true ]; then
    echo ""
    echo "Dry run mode — no processes were killed."
    exit 0
fi

# Kill all found processes
echo ""
echo "Sending $SIGNAL to all GPU processes..."
KILLED=0
FAILED=0

for pid in "${!ALL_PIDS[@]}"; do
    if kill -"$SIGNAL" "$pid" 2>/dev/null; then
        echo "  Killed PID $pid"
        KILLED=$((KILLED + 1))
    else
        # Process may have already exited
        if ! kill -0 "$pid" 2>/dev/null; then
            log "  PID $pid already exited"
        else
            echo "  Failed to kill PID $pid (permission denied?)"
            FAILED=$((FAILED + 1))
        fi
    fi
done

echo ""
echo "Done. Killed: $KILLED, Failed: $FAILED"

# Wait a moment and verify GPUs are freed
if command -v nvidia-smi &>/dev/null; then
    sleep 1
    remaining=$(nvidia-smi --query-compute-apps=pid --format=csv,noheader 2>/dev/null | grep -v '^$' | wc -l || echo "?")
    if [ "$remaining" = "0" ]; then
        echo "GPU successfully freed."
    else
        echo "Warning: $remaining process(es) still appear in nvidia-smi. They may need more time to release GPU resources, or may require sudo."
    fi
fi
