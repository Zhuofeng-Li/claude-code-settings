---
description: Set up all K8s nodes with Docker, OpenAI Codex CLI, and ms-swift. Requires cluster name from user.
allowed-tools: Bash, Edit, Write, Read
---

# K8s Codex + Swift Setup

在指定 K8s 集群的**所有节点**（master + 所有 worker）上安装 Docker、OpenAI Codex CLI 和 ms-swift（LLM 微调框架）。

## Usage

```
/k8s-codex-swift-setup <cluster-name>
```

示例：
```
/k8s-codex-swift-setup my-cluster-name
```

## 开始前确认参数

**第一步必须询问用户集群名字，不得跳过，不得假设。**

如果用户在命令参数或消息中没有提供 `cluster-name`，立即停下并向用户提问：

> 请提供 K8s 集群名字（例如：`my-cluster-june16`），我将在该集群的所有节点上安装 Docker、Codex 和 ms-swift。

收到用户回复后再继续执行后续步骤。

---

## Steps

Namespace：`application-nonprod`

### Stage 1: 发现所有节点 Pod

先列出该集群的所有 pod，找出所有节点：

```bash
kubectl get pods -n application-nonprod | grep <cluster-name>
```

收集所有匹配 `<cluster-name>` 的 pod 名称（通常包括 master、worker-0、worker-1 … worker-N 等）。

### Stage 2: 对每个 Pod 并行安装（逐个执行）

对 Stage 1 发现的**每一个** pod，依次执行 Stage 2a ~ 2c。

#### Stage 2a: 安装 Docker

```bash
kubectl exec <pod-name> -n application-nonprod -- bash -c "
  if command -v docker &>/dev/null; then
    echo '[<pod-name>] Docker already installed: '$(docker --version)
  else
    echo '[<pod-name>] === Installing Docker ==='
    apt-get update -qq
    apt-get install -y -qq ca-certificates curl gnupg lsb-release
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \$(. /etc/os-release && echo \"\$VERSION_CODENAME\") stable\" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    service docker start || dockerd &>/var/log/dockerd.log &
    sleep 2
    docker --version && echo '[<pod-name>] Docker installed successfully'
  fi
"
```

#### Stage 2b: 安装 OpenAI Codex CLI

```bash
kubectl exec <pod-name> -n application-nonprod -- bash -c "
  export PATH=\"\$HOME/.local/bin:\$PATH\"
  if command -v codex &>/dev/null; then
    echo '[<pod-name>] Codex already installed'
  else
    echo '[<pod-name>] === Installing OpenAI Codex CLI ==='
    curl -fsSL https://chatgpt.com/codex/install.sh | sh
    export PATH=\"\$HOME/.local/bin:\$PATH\"
    command -v codex && echo '[<pod-name>] Codex installed successfully' || echo '[<pod-name>] WARNING: codex not found in PATH after install'
  fi
"
```

#### Stage 2c: 后台安装 ms-swift

ms-swift 依赖多，安装慢（5-15 分钟），使用后台方式避免超时：

```bash
kubectl exec <pod-name> -n application-nonprod -- bash -c "
  if python3 -c 'import swift' &>/dev/null 2>&1; then
    echo '[<pod-name>] ms-swift already installed'
  else
    echo '[<pod-name>] === Starting ms-swift background install ==='
    nohup pip install 'ms-swift[all]' -U > /tmp/swift_install.log 2>&1 &
    echo '[<pod-name>] ms-swift installing in background (PID: '\$!')'
  fi
"
```

### Stage 3: 等待 ms-swift 安装完成

所有 pod 启动后台安装后，轮询检查直到全部完成：

```bash
# 对每个 pod 检查安装状态
kubectl exec <pod-name> -n application-nonprod -- bash -c "
  tail -5 /tmp/swift_install.log 2>/dev/null
  python3 -c 'import swift; print(\"[<pod-name>] ms-swift:\", swift.__version__)' 2>/dev/null || echo '[<pod-name>] ms-swift still installing...'
"
```

若仍在安装中，等待 60 秒后重试，直到所有 pod 完成。

### Stage 4: 全节点验证汇总

对每个 pod 运行：

```bash
kubectl exec <pod-name> -n application-nonprod -- bash -c "
  echo '=== [<pod-name>] Installation Summary ==='
  echo -n 'Docker:   '; docker --version 2>/dev/null || echo 'NOT FOUND'
  echo -n 'Codex:    '; export PATH=\"\$HOME/.local/bin:\$PATH\"; codex --version 2>/dev/null || command -v codex 2>/dev/null || echo 'NOT FOUND'
  echo -n 'ms-swift: '; python3 -c 'import swift; print(swift.__version__)' 2>/dev/null || echo 'NOT INSTALLED'
"
```

最终以表格形式输出所有节点的安装结果。

---

## 执行策略

1. Stage 1 先枚举所有 pod，不要假设只有 worker-0
2. Stage 2 对每个 pod 顺序执行（2a → 2b → 2c），再处理下一个 pod
3. ms-swift 统一后台安装，Stage 3 统一轮询等待
4. 若某个 pod 的某步失败，记录错误继续处理其余 pod，最后汇报失败节点

## 注意事项

- 需要 pod 有 root 权限（apt-get 安装 Docker）
- Docker 在容器内运行需要 `--privileged`，若 dockerd 启动失败请联系集群管理员
- Pod 重启后安装内容会丢失，需重新执行此 skill
