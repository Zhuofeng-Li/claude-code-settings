---
description: Set up a new server with zsh, oh-my-zsh plugins, uv, and gpustat
allowed-tools: Bash
---

# Setup Server

Initializes a fresh server environment with:
- **zsh** + **oh-my-zsh** with productivity plugins
- **uv** Python package manager
- **gpustat** for GPU monitoring
- **NVM** environment variables persisted to `~/.zshrc`
- **HuggingFace CLI** for model downloads and Hub access

## Usage:

`/setup-server`

## Process:

Run each setup stage in order. If a stage fails, diagnose the error before proceeding.

### Stage 1 — Install zsh and oh-my-zsh

```bash
apt install zsh -y
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
```

### Stage 2 — Clone oh-my-zsh plugins

```bash
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting
git clone https://github.com/zsh-users/zsh-completions ~/.oh-my-zsh/custom/plugins/zsh-completions
```

### Stage 3 — Enable plugins in ~/.zshrc

```bash
sed -i.bak 's/plugins=(.*)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting zsh-completions)/' ~/.zshrc
```

### Stage 4 — Install uv

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
source $HOME/.local/bin/env
```

### Stage 5 — Install gpustat

```bash
pip install gpustat
```

### Stage 6 — Install HuggingFace CLI

```bash
curl -LsSf https://hf.co/cli/install.sh | bash
```

### Stage 7 — Persist NVM environment variables to ~/.zshrc

Append the following block to `~/.zshrc` only if it is not already present:

```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
```

Use a guard check before appending to avoid duplicates:

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

### Stage 8 — Append personal env vars and aliases to ~/.zshrc and ~/.bashrc

**Before running this stage**, ask the user for the following values:
- `HF_TOKEN` — HuggingFace User Access Token (from https://huggingface.co/settings/tokens)
- `WANDB_API_KEY` — Weights & Biases API Key (from https://wandb.ai/settings)

If the user skips either, leave the corresponding line commented out in the block.

Use the marker `# === Personal Env & Aliases ===` as a guard to avoid duplicate appends. Append to **both** `~/.zshrc` and `~/.bashrc`:

```bash
PERSONAL_BLOCK='
# === Personal Env & Aliases ===

## Env Var

# HuggingFace token
export HF_TOKEN="your_hf_token_here"

# HuggingFace cache paths (uncomment and adjust for shared clusters)
# export HF_DATASETS_CACHE="/data/.cache/huggingface/datasets"
# export HF_HOME="/data/.cache/huggingface"

# Personal home override (uncomment if needed)
# export HOME="/data/zhuofeng"

# Ray cache path (only needed if using Ray)
# export RAY_ROOT_DIR="/data/.cache/ray"

# Weights & Biases API key
export WANDB_API_KEY="your_wandb_api_key_here"

## Python

alias py="python"
alias upip="python -m uv pip install"
alias ipy="ipython --TerminalInteractiveShell.shortcuts '"'"'{\"command\":\"IPython:auto_suggest.resume_hinting\", \"new_keys\": []}'"'"'"

## Dev

alias pre="pre-commit run --show-diff-on-failure --color=always --all-files"
alias pi="python -m uv pip install .[all]"
alias le="less"
alias his="history"
alias tr="tree -FLCN 2"
alias trd="tree -FLCNd 2"
alias wd="watch -n 0.1 du -hs"
alias tf="tail -f"
alias c7="chmod 777 -R"
alias op="open ."
alias cur="cursor"
alias cod="code"
alias ope="cursor ~/.zshrc"
alias co="cursor ."
alias nvi="nvidia-smi"
alias gpu="watch -n 1 gpustat"
alias tns="tmux new -s"
alias tls="tmux ls"
alias tat="tmux attach -t"
alias dfh="df -h"
'

for RC in ~/.zshrc ~/.bashrc; do
  if [ -f "$RC" ] && ! grep -q '# === Personal Env & Aliases ===' "$RC"; then
    echo "$PERSONAL_BLOCK" >> "$RC"
    echo "Appended personal env & aliases to $RC"
  else
    echo "Already present or file not found: $RC — skipping"
  fi
done
```

## Steps:

1. Run Stage 1 (zsh + oh-my-zsh). Use `--unattended` flag so the installer does not prompt to change the default shell interactively.
2. Verify oh-my-zsh is installed at `~/.oh-my-zsh` before proceeding.
3. Run Stage 2 (clone plugins). Skip any plugin that already exists.
4. Run Stage 3 (patch ~/.zshrc). Confirm the sed replacement succeeded.
5. Run Stage 4 (install uv). Verify `uv` is available after sourcing the env.
6. Run Stage 5 (install gpustat via uv).
7. Run Stage 6 (install HuggingFace CLI).
8. Run Stage 7 (append NVM env vars to ~/.zshrc). Skip if already present.
9. Run Stage 8: first ask the user for `HF_TOKEN` and `WANDB_API_KEY`, then append personal env vars and aliases to ~/.zshrc and ~/.bashrc. Skip if marker already present.
10. Print a summary of what was installed and remind the user to restart their shell or run `exec zsh` to activate the new configuration.

## Notes:

- Requires root or sudo privileges for `apt install zsh`.
- oh-my-zsh installer is run with `--unattended` to avoid interactive prompts.
- If the shell is not changed to zsh automatically, run: `chsh -s $(which zsh)`
- After setup, reload with: `exec zsh`
