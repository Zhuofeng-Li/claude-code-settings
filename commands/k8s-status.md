---
description: Query K8s cluster node status including GPU usage, running processes, disk, and connectivity.
allowed-tools: Bash, Read, AskUserQuestion
---

# K8s Status

查询指定 K8s 集群的节点状态，包括 GPU 使用、运行进程、磁盘空间、网络连通性等。

## Usage

```
/k8s-status <cluster-name> [check-type]
```

- `check-type` 可选：`all`（默认）、`gpu`、`process`、`disk`、`network`

示例：
```
/k8s-status xliucr-slime-8n-june16
/k8s-status xliucr-slime-8n-june16 gpu
/k8s-status xliucr-slime-8n-june16 process
```

## 开始前确认参数

**必须确认集群名字，不得假设。** 如果用户没有提供 `cluster-name`，立即询问。

---

## Steps

Namespace：`application-nonprod`

### Stage 1: 发现所有 worker pod

```bash
kubectl get pods -n application-nonprod -o wide | grep <cluster-name>
```

展示 pod 列表（含 STATUS、AGE、NODE 等信息）。

### Stage 2: GPU 状态（check-type = gpu 或 all）

对每个 pod 并行查询：

```bash
for pod in <pod-list>; do
  kubectl exec ${pod} -n application-nonprod -- bash -c "
    echo '=== ${pod} ==='
    nvidia-smi --query-gpu=index,name,memory.used,memory.total,utilization.gpu,temperature.gpu --format=csv,noheader 2>/dev/null || echo 'nvidia-smi not available'
  " 2>&1 &
done
wait
```

汇总为表格：

| Node | GPU | Model | Used/Total | Util% | Temp |
|------|-----|-------|------------|-------|------|

### Stage 3: 进程状态（check-type = process 或 all）

```bash
for pod in <pod-list>; do
  kubectl exec ${pod} -n application-nonprod -- bash -c "
    echo '=== ${pod} ==='
    # GPU 进程
    echo '-- GPU Processes --'
    nvidia-smi --query-compute-apps=pid,used_memory,name --format=csv,noheader 2>/dev/null || echo 'none'
    # 关键训练进程
    echo '-- Training Processes --'
    pgrep -af 'torchrun|swift|deepspeed|python.*train' 2>/dev/null | head -10 || echo 'none'
  " 2>&1 &
done
wait
```

### Stage 4: 磁盘空间（check-type = disk 或 all）

```bash
for pod in <pod-list>; do
  kubectl exec ${pod} -n application-nonprod -- bash -c "
    echo '=== ${pod} ==='
    df -h / /shared 2>/dev/null | tail -n +2
    echo '-- /shared/dev/zhuofeng usage --'
    du -sh /shared/dev/zhuofeng/ 2>/dev/null || echo 'N/A'
  " 2>&1 &
done
wait
```

### Stage 5: 网络连通性（check-type = network 或 all）

检查节点间 NCCL 通信基础设施：

```bash
for pod in <pod-list>; do
  kubectl exec ${pod} -n application-nonprod -- bash -c "
    echo '=== ${pod} ==='
    # 检查 RDMA / InfiniBand
    echo -n 'ibstat: '; ibstat 2>/dev/null | grep -c 'Active' || echo '0 active ports'
    # 检查 NCCL 环境变量
    echo -n 'NCCL vars: '; env | grep -c NCCL 2>/dev/null || echo '0'
    # 检查 master 可达性
    echo -n 'Master reachable: '; ping -c 1 -W 2 <cluster-name>-worker-0.default.svc.cluster.local &>/dev/null && echo 'yes' || echo 'no (trying pod IP...)'
  " 2>&1 &
done
wait
```

### Stage 6: 汇总报告

将以上结果整理为清晰的汇总报告，包含：
1. 集群概览（节点数、运行时长、总 GPU 数）
2. GPU 显存占用概览（哪些节点有空闲 GPU）
3. 正在运行的训练任务
4. 磁盘告警（>80% 使用率的挂载点）
5. 异常节点（GPU 温度过高、进程异常等）

---

## 执行策略

1. 所有查询都用 `&` + `wait` 并行执行，加速多节点查询
2. 如果只指定了某个 check-type，只执行对应 Stage，跳过其余
3. 若某个 pod 不可达（exec 超时），标记为 `UNREACHABLE` 继续其余节点
4. 最终以结构化表格形式呈现，方便快速定位问题

## 常用快捷查询

```bash
# 快速看所有节点 GPU 占用率
for pod in $(kubectl get pods -n application-nonprod | grep <cluster-name> | awk '{print $1}'); do
  echo -n "${pod}: "
  kubectl exec ${pod} -n application-nonprod -- bash -c \
    "nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader" 2>/dev/null
done

# 看谁在用 GPU
kubectl exec <cluster-name>-worker-0 -n application-nonprod -- bash -c \
  "nvidia-smi pmon -c 1"

# 查看 pod 日志（k8s 层面）
kubectl logs <cluster-name>-worker-0 -n application-nonprod --tail=50
```

## 注意事项

- `application-nonprod` 是固定 namespace
- `nvidia-smi` 查询很快，不会影响训练性能
- 并行查询多节点时注意 `wait` 收集所有输出
- Pod STATUS 不是 Running 时 exec 会失败，直接标记异常
