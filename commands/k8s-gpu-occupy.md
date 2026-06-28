---
description: Occupy all GPUs on K8s cluster nodes to prevent others from using them. Supports occupy and release.
allowed-tools: Bash, Read, AskUserQuestion
---

# K8s GPU Occupy

占满指定 K8s 集群所有节点的 GPU 显存，防止被他人抢占。支持占用和释放操作。

## Usage

```
/k8s-gpu-occupy <cluster-name> [action]
```

- `action` 可选：`occupy`（默认）或 `release`

示例：
```
/k8s-gpu-occupy xliucr-slime-8n-june16
/k8s-gpu-occupy xliucr-slime-8n-june16 release
```

## 开始前确认参数

**必须确认集群名字，不得假设。** 如果用户没有提供 `cluster-name`，立即询问。

---

## Steps

Namespace：`application-nonprod`

### Stage 1: 发现所有 worker pod

```bash
kubectl get pods -n application-nonprod | grep <cluster-name> | awk '{print $1}'
```

### Stage 2: 检查当前 GPU 状态

对每个 pod 并行检查：

```bash
for pod in <pod-list>; do
  kubectl exec ${pod} -n application-nonprod -- bash -c "
    echo '=== ${pod} ==='
    nvidia-smi --query-gpu=index,memory.used,memory.total,utilization.gpu --format=csv,noheader
  " 2>&1 &
done
wait
```

### Stage 3a: 占用 GPU（action = occupy）

对每个 pod 执行以下 Python 脚本，后台运行占满所有 GPU：

```bash
kubectl exec <pod> -n application-nonprod -- bash -c "
  # 检查是否已有占位进程
  if pgrep -f 'gpu_placeholder' &>/dev/null; then
    echo '[<pod>] GPU placeholder already running'
    nvidia-smi
  else
    echo '[<pod>] Starting GPU placeholder...'
    nohup python3 -c '
import torch
import os
import time
import signal
import sys

os.environ[\"CUDA_VISIBLE_DEVICES\"] = \",\".join(str(i) for i in range(torch.cuda.device_count()))

def handler(sig, frame):
    sys.exit(0)

signal.signal(signal.SIGTERM, handler)

tensors = []
for i in range(torch.cuda.device_count()):
    with torch.cuda.device(i):
        free_mem = torch.cuda.mem_get_info()[0]
        # 占用 95% 的可用显存
        alloc_size = int(free_mem * 0.95) // 4  # float32 = 4 bytes
        t = torch.ones(alloc_size, dtype=torch.float32, device=f\"cuda:{i}\")
        tensors.append(t)
        used = torch.cuda.memory_allocated(i) / 1024**3
        print(f\"GPU {i}: allocated {used:.1f} GB\", flush=True)

print(\"gpu_placeholder: all GPUs occupied, sleeping...\", flush=True)
while True:
    time.sleep(3600)
' > /tmp/gpu_placeholder.log 2>&1 &
    echo '[<pod>] GPU placeholder started (PID: '\$!')'
    sleep 3
    nvidia-smi --query-gpu=index,memory.used,memory.total --format=csv,noheader
  fi
"
```

多节点并行执行（加 `&` + `wait`）。

### Stage 3b: 释放 GPU（action = release）

```bash
for pod in <pod-list>; do
  kubectl exec ${pod} -n application-nonprod -- bash -c "
    pkill -f 'gpu_placeholder' 2>/dev/null && echo '[${pod}] GPU released' || echo '[${pod}] No placeholder process found'
  " 2>&1 &
done
wait
```

### Stage 4: 验证最终状态

```bash
for pod in <pod-list>; do
  kubectl exec ${pod} -n application-nonprod -- bash -c "
    echo '=== ${pod} ==='
    nvidia-smi --query-gpu=index,memory.used,memory.total,utilization.gpu --format=csv,noheader
    pgrep -af 'gpu_placeholder' 2>/dev/null || echo 'No placeholder running'
  " 2>&1 &
done
wait
```

---

## 执行策略

1. Stage 1 先枚举所有 pod
2. Stage 2 并行检查 GPU 状态，向用户展示当前占用情况
3. 根据 action 执行 Stage 3a 或 3b，多节点并行
4. Stage 4 验证并汇总结果，以表格形式展示每个节点的 GPU 占用状态

## 注意事项

- 占位进程使用 PyTorch 分配 95% 可用显存，保留少量给系统
- 进程名包含 `gpu_placeholder` 字符串，方便 grep/pkill
- `nohup` 后台运行，关闭 kubectl 连接后进程继续
- Pod 重启后占位进程会消失，需重新执行
- 释放时使用 `pkill -f` 精确匹配进程名
- 如果节点没有 PyTorch，会报错——此时需先 `pip install torch`
