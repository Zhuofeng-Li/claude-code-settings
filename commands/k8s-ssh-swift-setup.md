---
description: Set up SSH access to every worker of a K8s cluster (non-conflicting local ports) and install Docker, Docker Compose v2, and ms-swift on all nodes. Requires cluster name and SSH public key from user.
allowed-tools: Bash, Edit, Write, Read, AskUserQuestion
---

# K8s SSH + Swift + Docker Setup

给指定 K8s 集群的**每一个 worker 节点**：
1. 配置 SSH 公钥并启动 sshd（每个 worker 用**不重复**的本地 port-forward 端口）
2. 安装 Docker + Docker Compose v2
3. 安装 ms-swift（`pip install 'ms-swift[all]' -U`）

## Usage

```
/k8s-ssh-swift-setup <cluster-name> [ssh-pubkey]
```

示例：
```
/k8s-ssh-swift-setup xliucr-slime-8n-june20 "ecdsa-sha2-nistp521 AAAA...== user@host"
```

---

## 开始前确认参数（缺一不可）

1. `cluster-name`：K8s 集群名（worker pod 名为 `<cluster-name>-worker-N`）
2. `ssh-pubkey`：完整 SSH 公钥字符串（以 `ssh-` 或 `ecdsa-` 开头）

**如果用户没有提供 SSH 公钥，必须用 AskUserQuestion 或直接提问索取，不得假设。**
可建议用户用本机已有公钥：

```bash
cat ~/.ssh/id_ecdsa.pub 2>/dev/null || cat ~/.ssh/id_rsa.pub 2>/dev/null || cat ~/.ssh/id_ed25519.pub 2>/dev/null
```

两个参数都拿到后再继续。

---

## Steps

Namespace：`application-nonprod`

### Stage 1: 发现所有 worker pod

```bash
kubectl get pods -n application-nonprod | grep <cluster-name> | awk '{print $1}'
```

收集所有匹配的 pod 名（worker-0, worker-1, …, worker-N）。**按 worker 编号排序**，编号即用于分配本地端口。

### Stage 2: 端口分配规则（关键 — 不要冲突）

- **Pod 内 sshd 统一监听 2222**：不同 pod 是独立网络命名空间，互不冲突。
- **本地 port-forward 端口按 worker 编号递增**：worker-`i` → 本地 `2222 + i`。
  - worker-0 → `localhost:2222`
  - worker-1 → `localhost:2223`
  - worker-2 → `localhost:2224`
  - …

这样每个 worker 在本地有唯一端口，多个 port-forward 可同时运行不冲突。

### Stage 3: 对每个 worker 写入公钥并启动 sshd

对 Stage 1 的每个 pod 执行（`<pod>` = pod 名）：

```bash
kubectl exec <pod> -n application-nonprod -- bash -c "
  set -e
  # 1. 写入公钥
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  grep -qF '<ssh-pubkey>' ~/.ssh/authorized_keys 2>/dev/null || echo '<ssh-pubkey>' >> ~/.ssh/authorized_keys
  chmod 600 ~/.ssh/authorized_keys

  # 2. 确保 openssh-server 已安装
  if ! command -v sshd &>/dev/null && [ ! -x /usr/sbin/sshd ]; then
    echo '[<pod>] installing openssh-server...'
    apt-get update -qq && apt-get install -y -qq openssh-server
  fi

  # 3. 启动 sshd（端口 2222）
  if ps aux | grep -q '[s]shd.*2222'; then
    echo '[<pod>] sshd already running on 2222'
  else
    mkdir -p /run/sshd
    ls /etc/ssh/ssh_host_* &>/dev/null || ssh-keygen -A
    /usr/sbin/sshd -p 2222 \
      -o 'PermitRootLogin yes' \
      -o 'PubkeyAuthentication yes' \
      -o 'AuthorizedKeysFile ~/.ssh/authorized_keys'
    sleep 1
    echo '[<pod>] sshd started on 2222'
  fi
  ps aux | grep '[s]shd' | head -3
"
```

### Stage 4: 对每个 worker 安装 Docker + Docker Compose v2

```bash
kubectl exec <pod> -n application-nonprod -- bash -c "
  set -e
  # ── 1. 安装 Docker（如未安装）──
  if ! command -v docker &>/dev/null; then
    echo '[<pod>] === Installing Docker ==='
    apt-get update -qq
    apt-get install -y -qq ca-certificates curl gnupg lsb-release
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \$(. /etc/os-release && echo \"\$VERSION_CODENAME\") stable\" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -qq
    # docker-compose-plugin 提供 'docker compose'（v2 子命令）
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    echo '[<pod>] Docker packages installed'
  else
    echo '[<pod>] Docker already present: '\$(docker --version)
  fi

  # ── 2. 确保 dockerd 正在运行 ──
  if ! docker info &>/dev/null; then
    service docker start 2>/dev/null || true
    sleep 2
    if ! docker info &>/dev/null; then
      echo '[<pod>] launching dockerd manually (vfs storage driver)...'
      # k8s pod 宿主层是 overlay，不支持嵌套 overlay2，用 vfs。
      nohup dockerd --storage-driver=vfs --feature containerd-snapshotter=false \
        > /var/log/dockerd.log 2>&1 &
      sleep 5
    fi
  fi

  # ── 3. 验证 ──
  if docker info &>/dev/null; then
    echo '[<pod>] dockerd OK — storage: '\$(docker info --format '{{.Driver}}' 2>/dev/null)
  else
    echo '[<pod>] ERROR: dockerd failed. Check /var/log/dockerd.log' >&2
    tail -20 /var/log/dockerd.log 2>/dev/null >&2
  fi

  # ── 4. 验证 Docker Compose v2 ──
  if docker compose version &>/dev/null; then
    echo '[<pod>] Docker Compose: '\$(docker compose version)
  else
    apt-get install -y -qq docker-compose-plugin
    docker compose version && echo '[<pod>] Docker Compose installed' || echo '[<pod>] WARNING: docker compose unavailable'
  fi
"
```

> **vfs vs overlay2**：k8s pod 宿主挂载本身是 overlay，内核通常不允许嵌套 overlay2（报 `invalid argument`），故用 `vfs`。

### Stage 5: 对每个 worker 后台安装 ms-swift

ms-swift 依赖多、安装慢（5-15 分钟），后台安装避免超时：

```bash
kubectl exec <pod> -n application-nonprod -- bash -c "
  if python3 -c 'import swift' &>/dev/null 2>&1; then
    echo '[<pod>] ms-swift already installed'
  else
    echo '[<pod>] === Starting ms-swift background install ==='
    nohup pip install 'ms-swift[all]' -U > /tmp/swift_install.log 2>&1 &
    echo '[<pod>] ms-swift installing in background (PID: '\$!')'
  fi
"
```

### Stage 6: 等待 ms-swift 完成并汇总验证

轮询每个 pod 直到 ms-swift 装完（仍在装则等 60s 重试）：

```bash
kubectl exec <pod> -n application-nonprod -- bash -c "
  python3 -c 'import swift; print(\"[<pod>] ms-swift:\", swift.__version__)' 2>/dev/null \
    || { echo '[<pod>] still installing...'; tail -3 /tmp/swift_install.log 2>/dev/null; }
"
```

全部完成后，对每个 pod 输出汇总：

```bash
kubectl exec <pod> -n application-nonprod -- bash -c "
  echo '=== [<pod>] Summary ==='
  echo -n 'Docker:   '; docker --version 2>/dev/null || echo 'NOT FOUND'
  echo -n 'Compose:  '; docker compose version 2>/dev/null || echo 'NOT FOUND'
  echo -n 'sshd:     '; (ps aux | grep -q '[s]shd.*2222' && echo 'running on 2222') || echo 'NOT RUNNING'
  echo -n 'ms-swift: '; python3 -c 'import swift; print(swift.__version__)' 2>/dev/null || echo 'NOT INSTALLED'
"
```

### Stage 7: 生成 SSH config 与连接说明

为每个 worker 输出 `~/.ssh/config` 片段（本地端口 = 2222 + worker编号），并主动询问用户是否写入：

```
Host <cluster-name>-worker-0
  HostName 127.0.0.1
  Port 2222
  User root
  IdentityFile ~/.ssh/id_ecdsa
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null

Host <cluster-name>-worker-1
  HostName 127.0.0.1
  Port 2223
  User root
  IdentityFile ~/.ssh/id_ecdsa
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
...
```

然后输出每个 worker 的 port-forward 命令（每条需保持各自终端窗口运行）：

```
=== SSH 连接方法（每个 worker 一条 port-forward，端口不冲突）===

# worker-0（本地 2222）
kubectl port-forward <cluster-name>-worker-0 2222:2222 -n application-nonprod &
ssh <cluster-name>-worker-0

# worker-1（本地 2223）
kubectl port-forward <cluster-name>-worker-1 2223:2222 -n application-nonprod &
ssh <cluster-name>-worker-1
...
```

可生成一个一键启动所有 port-forward 的脚本供用户使用：

```bash
for i in 0 1 2 ...; do
  kubectl port-forward <cluster-name>-worker-${i} $((2222+i)):2222 -n application-nonprod &
done
```

---

## 执行策略

1. Stage 1 先枚举所有 worker pod，**不要假设只有 worker-0**
2. 端口严格按 worker 编号分配本地端口（2222 + i），pod 内 sshd 统一 2222
3. 对每个 pod 顺序执行 Stage 3 → 4 → 5，可对多个 pod 并行（`&` + `wait`）加速
4. ms-swift 统一后台安装，Stage 6 统一轮询
5. 某个 pod 某步失败时记录错误、继续其余 pod，最后汇报失败节点
6. 最后必须询问用户是否把 SSH config 片段写入 `~/.ssh/config`

## 注意事项

- 需要 pod 有 root 权限（apt-get 装 Docker / openssh-server）
- sshd、Docker、ms-swift 在 pod 重启后都会丢失，需重新执行此 skill
- port-forward 需保持终端窗口不关闭（或用 `&` 后台 + 记录 PID）
- 若 pod 镜像不含 openssh-server 且 apt 装不上，提示联系集群管理员
- Docker 在容器内需 dockerd 以 vfs 启动；若失败联系集群管理员开 `--privileged`
