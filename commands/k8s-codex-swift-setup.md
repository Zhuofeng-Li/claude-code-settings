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

#### Stage 2a: 安装 Docker + Docker Compose，并验证可运行

```bash
kubectl exec <pod-name> -n application-nonprod -- bash -c "
  set -e

  # ── 1. 安装 Docker（如未安装）──────────────────────────────────────
  if ! command -v docker &>/dev/null; then
    echo '[<pod-name>] === Installing Docker ==='
    apt-get update -qq
    apt-get install -y -qq ca-certificates curl gnupg lsb-release
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \$(. /etc/os-release && echo \"\$VERSION_CODENAME\") stable\" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -qq
    # docker-compose-plugin 提供 'docker compose'（v2 子命令）
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    echo '[<pod-name>] Docker packages installed'
  else
    echo '[<pod-name>] Docker binary already present: '$(docker --version)
  fi

  # ── 2. 确保 dockerd 正在运行 ────────────────────────────────────────
  # 优先用 service；失败则手动后台启动
  start_docker() {
    service docker start 2>/dev/null || true
    sleep 2
    if ! docker info &>/dev/null; then
      echo '[<pod-name>] service start failed, launching dockerd manually...'
      # k8s pod 内宿主层通常是 overlay，不支持内核 overlay2 嵌套，
      # 显式指定 vfs + 关闭 containerd-snapshotter 避免 daemon 崩溃。
      nohup dockerd --storage-driver=vfs --feature containerd-snapshotter=false \
        > /var/log/dockerd.log 2>&1 &
      sleep 5
    fi
  }

  if docker info &>/dev/null; then
    echo '[<pod-name>] dockerd already running'
  else
    start_docker
  fi

  # ── 3. 验证 Docker 可正常执行容器 ───────────────────────────────────
  if docker info &>/dev/null; then
    STORAGE=\$(docker info --format '{{.Driver}}' 2>/dev/null)
    echo '[<pod-name>] dockerd OK — storage driver: '\$STORAGE
    # 快速冒烟测试（不拉镜像，只检查 daemon 响应）
    docker ps -q &>/dev/null && echo '[<pod-name>] docker ps OK'
  else
    echo '[<pod-name>] ERROR: dockerd failed to start. Check /var/log/dockerd.log' >&2
    tail -20 /var/log/dockerd.log 2>/dev/null >&2
    exit 1
  fi

  # ── 4. 验证 Docker Compose v2 可用 ──────────────────────────────────
  if docker compose version &>/dev/null; then
    echo '[<pod-name>] Docker Compose: '$(docker compose version)
  else
    echo '[<pod-name>] WARNING: docker compose not available. Trying to install docker-compose-plugin...'
    apt-get install -y -qq docker-compose-plugin
    docker compose version && echo '[<pod-name>] Docker Compose installed successfully'
  fi
"
```

> **关于 vfs vs overlay2**：k8s pod 的宿主挂载本身是 overlay，内核通常不允许再嵌套 overlay2（会报 `invalid argument`）。此处显式使用 `vfs` 是正确选择。若未来宿主支持 fuse-overlayfs 或 `--privileged` 模式已开启 nested overlay，可改为 `overlay2`，但需先停止 daemon 并迁移 `/var/lib/docker`。

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
