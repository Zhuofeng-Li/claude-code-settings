# K8s Node Access

在 K8s 集群的 pod 上执行命令。支持单节点命令、多节点并行命令、以及训练管理操作。

## Usage:

`/k8s-exec [cluster-name] [command]`

## 工作方式

所有操作均通过 `kubectl exec <pod> -n application-nonprod -- bash -c "..."` 注入，无需 SSH，无需 Docker。

## Process:

### 1. 确定集群和节点

```bash
# 列出所有 running pod
kubectl get pods -n application-nonprod | grep <cluster-name>

# 常用集群命名规律：
# xliucr-slime-8n-june16-worker-{0..7}
# xliucr-slime-16n-june6-worker-{0..15}
```

### 2. 单节点执行

```bash
kubectl exec <pod-name> -n application-nonprod -- bash -c "<command>"
```

### 3. 多节点并行执行

```bash
for rank in 0 1 2 3 4 5 6 7; do
  kubectl exec <cluster>-worker-${rank} -n application-nonprod -- bash -c "
    <command>
  " 2>&1 &
done
wait
```

### 4. 后台启动训练（nohup + log）

```bash
# Worker 1-7 先启动（等待 master rendezvous）
for rank in 1 2 3 4 5 6 7; do
  kubectl exec <cluster>-worker-${rank} -n application-nonprod -- bash -c "
    NODE_RANK=${rank} <ENV_VARS> \
      nohup bash /path/to/script.sh \
      > /shared/dev/zhuofeng/logs/worker-${rank}.log 2>&1 &
    echo worker-${rank} PID: \$!
  " 2>&1 &
done
wait

# 最后启动 worker-0（master）
kubectl exec <cluster>-worker-0 -n application-nonprod -- bash -c "
  NODE_RANK=0 <ENV_VARS> \
    nohup bash /path/to/script.sh \
    > /shared/dev/zhuofeng/logs/worker-0.log 2>&1 &
  echo worker-0 PID: \$!
" 2>&1
```

### 5. Kill 训练

```bash
for rank in 0 1 2 3 4 5 6 7; do
  kubectl exec <cluster>-worker-${rank} -n application-nonprod -- bash -c "
    pkill -f 'swift/cli/sft.py' 2>/dev/null
    pkill -f 'torchrun' 2>/dev/null
    echo worker-${rank} killed
  " 2>&1 &
done
wait
```

### 6. 查看日志

```bash
# 单节点实时
kubectl exec <cluster>-worker-0 -n application-nonprod -- bash -c \
  "tail -f /shared/dev/zhuofeng/logs/worker-0.log"

# 所有节点最新状态
for rank in 0 1 2 3 4 5 6 7; do
  echo "=== worker-${rank} ==="
  kubectl exec <cluster>-worker-${rank} -n application-nonprod -- bash -c \
    "tail -3 /shared/dev/zhuofeng/logs/worker-${rank}.log 2>/dev/null" 2>&1 &
done
wait
```

### 7. 同步代码到节点（S3 中转）

```bash
# Dev machine → S3
/local/home/zhuofeng/slime/.venv/bin/s5cmd sync \
  --exclude ".git/*" --exclude ".venv/*" --exclude "__pycache__/*" \
  /local/home/zhuofeng/nemotron-corpus-sft/ms-swift/ \
  s3://p11-dev/zhuofeng/nemotron-corpus-sft/ms-swift/

# K8s node ← S3（在 exec 里执行）
/shared/crenyuan/s5cmd sync \
  's3://p11-dev/zhuofeng/nemotron-corpus-sft/ms-swift/*' \
  /shared/dev/zhuofeng/nemotron-corpus-sft/ms-swift/
```

## Examples:

```bash
# 检查 GPU 状态
kubectl exec xliucr-slime-8n-june16-worker-0 -n application-nonprod -- bash -c "nvidia-smi"

# 检查共享盘是否可访问
kubectl exec xliucr-slime-8n-june16-worker-0 -n application-nonprod -- bash -c "ls /shared/dev/zhuofeng/"

# 查看某个进程是否在跑
kubectl exec xliucr-slime-8n-june16-worker-0 -n application-nonprod -- bash -c "pgrep -af torchrun"

# 检查日志是否有 error
kubectl exec xliucr-slime-8n-june16-worker-0 -n application-nonprod -- bash -c \
  "grep -i 'error\|oom\|killed' /shared/dev/zhuofeng/logs/worker-0.log | tail -10"
```

## Notes:

- `application-nonprod` 是固定 namespace，所有 pod 都在这个 namespace 下
- 共享盘路径：`/shared/dev/zhuofeng/`，所有节点可读写
- s5cmd 路径：`/shared/crenyuan/s5cmd`（节点上）
- 多节点并行时加 `&` + `wait`，避免串行等待
- 后台命令用 `nohup ... &`，关闭 kubectl 连接后进程继续运行
- `-it` 参数在 nohup/后台场景下会报错，去掉即可
- Worker 节点无 `sudo`，无 `aws` CLI，安装依赖用 `pip install`（不要用 Docker 装，会 kill 所有节点）
