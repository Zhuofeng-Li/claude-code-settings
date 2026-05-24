---
description: 从登录节点用 ngrok 转发 SLURM 计算节点上的服务端口到公网
allowed-tools: Bash
---

从 SLURM 登录节点将计算节点上运行的服务（如 SGLang、vLLM 等）通过 ngrok 暴露到公网。

## 参数

用户可能提供：
- 节点名（如 `dgx053`）和端口（如 `8000`）
- 或者只说"转发当前 job"，此时需要自动查找

## 步骤

### 1. 确定目标节点和端口

如果用户没有指定，自动查找正在运行的 SLURM job：

```bash
squeue -u $USER --format="%.10i %.20j %.8T %R" --noheader | grep RUNNING
```

从输出的 `NODELIST` 字段获取节点名，端口默认为 `8000`。

### 2. 验证服务可达性

```bash
curl -s --connect-timeout 3 http://<node>:<port>/model_info
```

若返回 JSON 则可达，否则提示用户确认服务是否已启动。

### 3. 停止旧 ngrok 进程

```bash
pkill -f ngrok; sleep 1
```

### 4. 启动 ngrok 转发计算节点

**关键**：直接指向计算节点地址，而非 `localhost`：

```bash
nohup /scratch/user/zhuofengli_tamu.edu/ngrok http <node>:<port> > /tmp/ngrok.log 2>&1 &
sleep 5
```

### 5. 获取公网地址

```bash
curl -s http://localhost:4040/api/tunnels | python3 -c "
import sys, json
d = json.load(sys.stdin)
for t in d.get('tunnels', []):
    print(t['public_url'])
"
```

### 6. 输出结果

以清晰格式展示：

```
✅ ngrok 转发成功

公网地址：https://xxxx.ngrok-free.dev
转发目标：<node>:<port>

测试命令：
  curl https://xxxx.ngrok-free.dev/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{"model": "...", "messages": [{"role": "user", "content": "Hello"}], "max_tokens": 100}'
```

## 注意事项

- 登录节点与计算节点在同一内网，可直接用 `<node>:<port>` 访问，**不需要 SSH 隧道**
- ngrok 免费账号 URL 固定不变（同一账号），重启后 URL 相同
- 若 ngrok 报 `ERR_NGROK_334`（已有隧道），先 `pkill -f ngrok` 再重启
- 若 ngrok 报 `ERR_NGROK_8012`（连不上），说明指向了 `localhost` 而非计算节点，检查命令是否正确
