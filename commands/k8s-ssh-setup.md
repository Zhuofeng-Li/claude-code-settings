# k8s-ssh-setup

给指定 K8s 集群的 worker-0 配置 SSH 公钥并启动 sshd，然后通过 port-forward 建立 SSH 连接。

## Usage

```
/k8s-ssh-setup <cluster-name> <ssh-pubkey>
```

示例：
```
/k8s-ssh-setup xliucr-slime-8n-june16 "ecdsa-sha2-nistp521 AAAA...== user@host"
```

## Steps

**开始前必须确认两个参数，缺一不可：**

1. `cluster-name`：K8s 集群名（pod 名为 `<cluster-name>-worker-0`）
2. `ssh-pubkey`：完整的 SSH 公钥字符串（以 `ssh-` 或 `ecdsa-` 开头）

如果用户没有在命令参数或消息中提供上述任意一个，**必须先向用户提问索取**，不得假设或跳过。两个参数都拿到后再继续执行。

按以下步骤执行：

### 1. 确定 pod 名和 namespace

Pod 名固定格式：`<cluster-name>-worker-0`
Namespace：`application-nonprod`

### 2. 写入公钥到 worker-0

```bash
kubectl exec <cluster-name>-worker-0 -n application-nonprod -- bash -c "
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  echo '<ssh-pubkey>' >> ~/.ssh/authorized_keys
  chmod 600 ~/.ssh/authorized_keys
  echo 'authorized_keys 内容：'
  cat ~/.ssh/authorized_keys
"
```

### 3. 启动 sshd（端口 2222）

```bash
kubectl exec <cluster-name>-worker-0 -n application-nonprod -- bash -c "
  # 检查 sshd 是否已在运行
  if ps aux | grep -q '[s]shd.*2222'; then
    echo 'sshd 已在运行'
  else
    mkdir -p /run/sshd
    ls /etc/ssh/ssh_host_* 2>/dev/null || ssh-keygen -A
    /usr/sbin/sshd -p 2222 \
      -o 'PermitRootLogin yes' \
      -o 'PubkeyAuthentication yes' \
      -o 'AuthorizedKeysFile ~/.ssh/authorized_keys'
    sleep 1
    echo 'sshd 已启动'
  fi
  ps aux | grep sshd | grep -v grep
"
```

### 4. 给出连接命令

执行完毕后，输出以下使用说明：

```
=== SSH 连接方法 ===

终端 1（保持运行）：
  kubectl port-forward <cluster-name>-worker-0 2222:2222 -n application-nonprod

终端 2（SSH 连接）：
  ssh -p 2222 root@127.0.0.1 -i ~/.ssh/id_ecdsa

注意：pod 重启后 sshd 会消失，需重新运行 /k8s-ssh-setup
```

### 注意事项

- sshd 在 pod 重启后不持久，每次重启需重新执行步骤 3
- port-forward 需保持终端窗口不关闭
- 如果 sshd 未安装（`which sshd` 报错），提示用户该 pod 镜像不含 openssh-server，需要联系集群管理员或换用 `kubectl exec` 直接操作
