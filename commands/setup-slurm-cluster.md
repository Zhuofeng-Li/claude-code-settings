---
description: Set up SLURM cluster environment (no sudo) with zsh, oh-my-zsh, uv, gpustat, ngrok, and HuggingFace CLI
allowed-tools: Bash, Edit, Write, Read
---

# Setup SLURM Cluster Environment

专为无 sudo 权限的 SLURM 集群设计的环境初始化脚本。**所有工具和包均安装到 `/scratch/user/$USER`**，不占用 home 目录配额，无需 root 权限。

安装内容：
- **zsh** + **oh-my-zsh** with productivity plugins（若已有则跳过）
- **uv** Python package manager（安装到 `/scratch/user/$USER/.local/bin`）
- **Python venv** 创建于 `/scratch/user/$USER/.venv`
- **gpustat** for GPU monitoring（安装到 venv）
- **ngrok v3** 下载到 `/scratch/user/$USER`，并添加到 PATH
- **HuggingFace CLI** for model downloads（安装到 venv）
- **NVM** environment variables persisted to `~/.zshrc`

## Usage:

`/setup-slurm-cluster`

## 重要约束

- **无 sudo / 无 apt**：集群节点通常不允许 sudo，所有安装均通过用户空间完成
- **所有包安装到 scratch**：`SCRATCH=/scratch/user/$USER`，避免占用 home 目录配额
- scratch 路径约定：`/scratch/user/$USER`（本集群实测路径）
- 幂等执行：每个 Stage 执行前先检查是否已安装，已存在则跳过

## Process:

按顺序执行每个 Stage。某 Stage 失败时先诊断原因再继续。

### Stage 1 — Install zsh（用户级，无 sudo）

先检查系统是否已有 zsh：

```bash
which zsh || zsh --version
```

如果系统已有 zsh，直接进入 Stage 2。若无，尝试从预编译包安装到用户目录（集群通常已预装 zsh，大概率跳过）：

```bash
# 仅在 zsh 不可用时执行
mkdir -p ~/.local/bin
# 尝试 conda 方式（若集群有 conda/mamba）
conda install -y -c conda-forge zsh 2>/dev/null || echo "conda not available, skip"
```

### Stage 2 — Install oh-my-zsh

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
```

验证安装：

```bash
ls ~/.oh-my-zsh
```

### Stage 3 — Clone oh-my-zsh plugins

逐个克隆，已存在则跳过：

```bash
[ -d "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ] || \
  git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

[ -d "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ] || \
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

[ -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting" ] || \
  git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting

[ -d ~/.oh-my-zsh/custom/plugins/zsh-completions ] || \
  git clone https://github.com/zsh-users/zsh-completions ~/.oh-my-zsh/custom/plugins/zsh-completions
```

### Stage 4 — Enable plugins in ~/.zshrc

```bash
sed -i.bak 's/plugins=(.*)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting zsh-completions)/' ~/.zshrc
```

### Stage 5 — Install uv（安装到 scratch）

将 uv 二进制安装到 `/scratch/user/$USER/.local/bin`：

```bash
SCRATCH="/scratch/user/$USER"
export UV_INSTALL_DIR="$SCRATCH/.local/bin"
mkdir -p "$UV_INSTALL_DIR"
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$UV_INSTALL_DIR:$PATH"
```

将 uv 路径持久化（避免重复添加）：

```bash
SCRATCH="/scratch/user/$USER"
if ! grep -q 'UV_INSTALL_DIR' ~/.zshrc; then
  cat >> ~/.zshrc << EOF

# uv (installed to scratch)
export UV_INSTALL_DIR="$SCRATCH/.local/bin"
export PATH="\$UV_INSTALL_DIR:\$PATH"
EOF
fi
if ! grep -q 'UV_INSTALL_DIR' ~/.bashrc; then
  cat >> ~/.bashrc << EOF

# uv (installed to scratch)
export UV_INSTALL_DIR="$SCRATCH/.local/bin"
export PATH="\$UV_INSTALL_DIR:\$PATH"
EOF
fi
```

验证：

```bash
uv --version
```

### Stage 6 — 创建 Python venv 到 scratch 并安装包

在 scratch 下创建 venv，安装 gpustat 和 huggingface_hub：

```bash
SCRATCH="/scratch/user/$USER"
VENV="$SCRATCH/.venv"

if [ ! -d "$VENV" ]; then
  uv venv "$VENV"
  echo "venv created at $VENV"
fi

# 激活 venv 并安装包
source "$VENV/bin/activate"
uv pip install gpustat huggingface_hub[cli]
```

将 venv 自动激活写入 shell 配置（避免重复）：

```bash
SCRATCH="/scratch/user/$USER"
VENV="$SCRATCH/.venv"

if ! grep -q "$VENV" ~/.zshrc; then
  echo "source \"$VENV/bin/activate\"" >> ~/.zshrc
fi
if ! grep -q "$VENV" ~/.bashrc; then
  echo "source \"$VENV/bin/activate\"" >> ~/.bashrc
fi
```

### Stage 7 — Install ngrok（下载二进制到 scratch）

集群无 sudo，直接下载官方静态二进制：

```bash
SCRATCH="/scratch/user/$USER"
mkdir -p "$SCRATCH"
if [ ! -f "$SCRATCH/ngrok" ]; then
  curl -sSL https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz | tar xz -C "$SCRATCH"
  echo "ngrok downloaded to $SCRATCH/ngrok"
else
  echo "ngrok already exists, skipping"
fi
```

将 scratch 目录加入 PATH（对 ~/.zshrc 和 ~/.bashrc 均操作，避免重复添加）：

```bash
SCRATCH="/scratch/user/$USER"

if ! grep -q "$SCRATCH" ~/.zshrc; then
  echo "export PATH=\"$SCRATCH:\$PATH\"" >> ~/.zshrc
fi

if ! grep -q "$SCRATCH" ~/.bashrc; then
  echo "export PATH=\"$SCRATCH:\$PATH\"" >> ~/.bashrc
fi
```

验证版本：

```bash
export PATH="/scratch/user/$USER:$PATH"
ngrok --version
```

### Stage 8 — Install HuggingFace CLI

已在 Stage 6 中随 venv 一起安装（`huggingface_hub[cli]`），无需重复操作。验证：

```bash
huggingface-cli --version
```

### Stage 9 — Persist NVM environment variables to ~/.zshrc

```bash
if ! grep -q 'NVM_DIR' ~/.zshrc; then
  cat >> ~/.zshrc << 'EOF'

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
EOF
fi
```

## Steps:

1. 检查 zsh 是否可用，不可用时尝试用户级安装（Stage 1）
2. 安装 oh-my-zsh（Stage 2），验证 `~/.oh-my-zsh` 存在后继续
3. 克隆插件（Stage 3），已存在则跳过
4. 修改 `~/.zshrc` 启用插件（Stage 4），确认 sed 替换成功
5. 安装 uv 到 `$SCRATCH/.local/bin`，持久化 PATH（Stage 5），验证可用
6. 在 `$SCRATCH/.venv` 创建 venv，安装 gpustat + huggingface_hub，自动激活写入 shell 配置（Stage 6）
7. 下载 ngrok 到 `/scratch/user/$USER`，加入 PATH（Stage 7）
8. 验证 huggingface-cli 可用（Stage 8）
9. 追加 NVM 环境变量到 `~/.zshrc`（Stage 9），已存在则跳过
10. 打印安装摘要，提示用户执行 `exec zsh` 或重新登录使配置生效

## Notes:

- 本脚本专为 TAMU SLURM 集群设计，scratch 路径为 `/scratch/user/$USER`
- 无需 sudo，**所有包均安装到 `/scratch/user/$USER`**，不占用 home 目录配额
- ngrok 需要在 https://ngrok.com 注册并配置 authtoken 才能使用：`ngrok config add-authtoken <TOKEN>`
- 重新登录或执行 `exec zsh` 后配置才完全生效
- gpustat 使用：`gpustat -i 1`（每秒刷新）
- scratch 目录可能在节点重启后清空，重要数据请备份到 home 目录
