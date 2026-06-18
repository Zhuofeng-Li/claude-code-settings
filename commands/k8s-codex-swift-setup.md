---
description: Set up a K8s pod with Docker, OpenAI Codex CLI, and ms-swift. Requires cluster name from user.
allowed-tools: Bash, Edit, Write, Read
---

# K8s Codex + Swift Setup

在指定 K8s 集群的 worker-0 pod 中安装 Docker、OpenAI Codex CLI 和 ms-swift（LLM 微调框架）。

## Usage

```
/k8s-codex-swift-setup <cluster-name>
```

示例：
```
/k8s-codex-swift-setup my-cluster-name
```

## 开始前确认参数

**必须先确认 `cluster-name` 参数**，如果用户没有在命令参数中提供，**必须先向用户提问索取**，不得假设或跳过。

- `cluster-name`：K8s 集群名（pod 名为 `<cluster-name>-worker-0`）

拿到参数后再继续执行。

---

## Steps

Pod 名：`<cluster-name>-worker-0`
Namespace：`application-nonprod`

所有命令通过 `kubectl exec <cluster-name>-worker-0 -n application-nonprod -- bash -c "..."` 执行。

### Stage 1: 检查 Pod 状态

```bash
kubectl get pod <cluster-name>-worker-0 -n application-nonprod
```

确认 pod 处于 Running 状态后继续。若不存在或非 Running，报告错误并停止。

### Stage 2: 安装 Docker

```bash
kubectl exec <cluster-name>-worker-0 -n application-nonprod -- bash -c "
  if command -v docker &>/dev/null; then
    echo 'Docker already installed: '$(docker --version)
  else
    echo '=== Installing Docker ==='
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
    docker --version && echo 'Docker installed successfully'
  fi
"
```

### Stage 3: 安装 OpenAI Codex CLI

```bash
kubectl exec <cluster-name>-worker-0 -n application-nonprod -- bash -c "
  if command -v codex &>/dev/null; then
    echo 'Codex already installed: '$(codex --version 2>/dev/null || echo 'version unknown')
  else
    echo '=== Installing OpenAI Codex CLI ==='
    curl -fsSL https://chatgpt.com/codex/install.sh | sh
    echo 'Codex install script completed'
    # Verify
    export PATH=\"\$HOME/.local/bin:\$PATH\"
    command -v codex && echo 'Codex installed successfully' || echo 'WARNING: codex not found in PATH, may need manual PATH update'
  fi
"
```

### Stage 4: 安装 ms-swift

ms-swift 是大模型微调框架，安装较慢（依赖较多），预计需要 5-15 分钟。

```bash
kubectl exec <cluster-name>-worker-0 -n application-nonprod -- bash -c "
  echo '=== Installing ms-swift (this may take 5-15 minutes) ==='
  if python3 -c 'import swift' &>/dev/null 2>&1; then
    echo 'ms-swift already installed: '$(python3 -c 'import swift; print(swift.__version__)' 2>/dev/null)
  else
    pip install 'ms-swift[all]' -U
    python3 -c 'import swift; print(\"ms-swift installed:\", swift.__version__)' && echo 'ms-swift installed successfully'
  fi
" 2>&1
```

注意：此步骤耗时较长，kubectl exec 默认超时可能不够，可以先进入 pod 后台执行：

```bash
# 备选方案：后台安装 ms-swift，将日志写入文件
kubectl exec <cluster-name>-worker-0 -n application-nonprod -- bash -c "
  nohup pip install 'ms-swift[all]' -U > /tmp/swift_install.log 2>&1 &
  echo 'ms-swift installation started in background (PID: '$!')'
  echo 'Monitor with: kubectl exec <cluster-name>-worker-0 -n application-nonprod -- tail -f /tmp/swift_install.log'
"
```

### Stage 5: 验证安装

```bash
kubectl exec <cluster-name>-worker-0 -n application-nonprod -- bash -c "
  echo '=== Installation Summary ==='
  echo -n 'Docker:  '; docker --version 2>/dev/null || echo 'NOT FOUND'
  echo -n 'Codex:   '
  export PATH=\"\$HOME/.local/bin:\$PATH\"
  codex --version 2>/dev/null || command -v codex 2>/dev/null || echo 'NOT FOUND (may need PATH update)'
  echo -n 'ms-swift: '
  python3 -c 'import swift; print(swift.__version__)' 2>/dev/null || echo 'NOT INSTALLED YET (check /tmp/swift_install.log if background install)'
"
```

---

## 执行策略

1. 按 Stage 顺序执行，每步执行完确认输出再继续
2. Stage 4（ms-swift）如果 pod 会超时，自动切换为后台安装方式，并告知用户如何监控进度
3. 全部完成后输出 Stage 5 汇总

## 注意事项

- 需要 pod 有 root 权限（apt-get 安装 Docker）
- Docker 在容器内运行需要 `--privileged` 或相应的 securityContext，若 Docker 服务启动失败请联系集群管理员
- ms-swift 完整安装包含所有可选依赖（`[all]`），体积较大
- Pod 重启后安装内容会丢失，需重新执行此 skill
