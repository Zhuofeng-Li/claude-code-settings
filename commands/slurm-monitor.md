---
description: 提交 SLURM 脚本，持续监控 job 状态，自动检测错误并修复后重新提交，循环直到成功
argument-hint: <slurm_script.slurm>
allowed-tools: Bash, Read, Edit, Write, Grep
---

提交指定的 SLURM 脚本，监控 job 状态，发现错误后自动分析、修复脚本，然后重新提交，循环直到 job 成功运行。

## 核心循环

```
提交 job → 等待运行 → 监控日志 → 检测错误 → 修复脚本 → 重新提交
```

每次进入循环前：
1. 检查空闲节点（`sinfo -o "%P %N %T %l" --noheader | grep " idle "`），选择 partition 时间最长、目前空闲的节点
2. 若脚本中 `--nodelist` 与当前最佳节点不符，更新脚本

---

## 步骤

### 1. 提交 job

```bash
sbatch $ARGUMENTS
```

从输出中提取 Job ID（格式：`Submitted batch job <ID>`）。

### 2. 等待进入 RUNNING，每 10 秒轮询一次

```bash
squeue -j <JOB_ID> -o "%T %R" --noheader
```

- `PENDING`：显示等待原因，继续等待
- `RUNNING`：进入下一步
- 不在队列：跳转步骤 4

### 3. 持续读取日志

从 `#SBATCH --output` 解析日志路径（`%j` → Job ID），每 30 秒读取新内容：

```bash
tail -n 50 <log_file>
```

同时用 `squeue -j <JOB_ID>` 检测 job 是否还在队列。若 job 消失，进入步骤 4。

**监控时关注的关键信息（正面）：**
- `Serving HTTP on` 或 `Application startup complete` → 服务启动成功，报告成功
- `Loading safetensors checkpoint shards` → 正在加载模型，正常，继续等待
- `DeepGEMM ... enabled` → 依赖就绪，正常

**监控时关注的关键信息（错误）：**
- `ERROR`、`Traceback`、`AssertionError`、`RuntimeError`、`ImportError` → 进入错误分析
- `CUDA_HOME`、`cuda_home is not None` → CUDA 环境变量未传递给子进程
- `Sparse Attention Indexer CUDA op requires DeepGEMM` → DeepGEMM 未安装
- `_sysconfigdata_ is missing` → Python 版本或 venv 创建问题
- `Failed to inspect Python interpreter` → uv 缓存损坏，需清理
- `No space left on device`、`Disk quota exceeded` → 磁盘空间不足

### 4. job 结束后获取最终状态

```bash
sacct -j <JOB_ID> --format=JobID,State,ExitCode,NodeList,Elapsed -X
```

- `COMPLETED` + ExitCode 0 → 成功，输出总结
- `FAILED` 或 ExitCode 非 0 → 进入错误分析和修复

---

## 错误分析与修复策略

读取完整日志，定位最后一个错误。根据错误类型采取以下修复：

| 错误 | 修复方式 |
|------|---------|
| `assert cuda_home is not None` | 在脚本 `set -ex` 后加 `module load CUDA/12.9.1` 和 `export CUDA_HOME=/sw/eb/sw/CUDA/12.9.1` |
| `Sparse Attention Indexer requires DeepGEMM` | 在 venv 激活后加 DeepGEMM 安装步骤（`uv pip install -e /scratch/.../DeepGEMM --no-build-isolation`） |
| `_sysconfigdata_ is missing` | 改用系统 Python：`uv venv --python /usr/bin/python3.12` |
| `Failed to inspect Python interpreter` / uv 缓存错误 | 运行 `uv cache clean`，然后重试 |
| `No space left` / `Disk quota exceeded` | 运行 `/disk-check` skill 分析并清理空间 |
| `venv already exists` | 加 `--clear` 参数或先 `rm -rf "$VENV_DIR"` |
| `module not found` / `ModuleNotFoundError` | 在 venv 中安装缺失的包 |
| 节点问题（node down/drained） | 用 `sinfo` 重新选择空闲节点，更新 `--nodelist` |

修复完成后，**检查空闲节点**并重新提交（回到步骤 1）。

---

## 成功条件

日志中出现以下任意一条时，停止循环并报告成功：

- `Uvicorn running on`
- `Application startup complete`
- `Serving HTTP on`

报告内容：Job ID、节点、端口、运行时长。

---

## 注意事项

- `$ARGUMENTS` 为用户传入的 SLURM 脚本路径（必须提供）
- 每次重新提交前取消所有同名 job：`scancel --name <job_name>`
- 最多重试 **5 次**，超过后停止并向用户报告无法自动修复的错误
- 若 `sbatch` 不存在，提示用户确认是否在 SLURM 登录节点上运行
- 永远只使用一个统一的 venv，不要重复创建新环境
