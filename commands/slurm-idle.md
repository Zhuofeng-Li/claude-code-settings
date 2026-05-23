---
description: 读取指定 SLURM 脚本，分析其资源需求，在当前集群中找出最适合它的节点并给出提交命令
allowed-tools: Bash, Read
---

用户提供了一个 SLURM 脚本路径（通过 `$ARGUMENTS` 传入）。你需要：
1. 读取该脚本，解析其资源需求
2. 扫描集群现状
3. 综合评分，推荐最优节点/partition，并给出完整提交命令

---

## 第一步：解析 SLURM 脚本需求

读取 `$ARGUMENTS` 指定的脚本文件，提取以下 `#SBATCH` 指令：
- `--gres=gpu:*` — 需要的 GPU 型号（如有）和数量
- `--time` — 申请的时长
- `--mem` 或 `--mem-per-cpu` — 内存需求
- `--cpus-per-task` 或 `-c` — CPU 需求
- `--partition` 或 `-p` — 已指定的 partition（若有）
- `--nodes` 或 `-N` — 节点数

将解析到的需求记为"目标需求"，用于后续筛选。

---

## 第二步：收集集群节点信息

运行以下命令，同时获取 idle 和 mixed 节点（mixed 节点有部分资源空闲，也可能排上）：

```bash
sinfo -o "%P %N %T %l %D" --noheader | grep -E " (idle|mixed) "
```

同时获取当前队列负载（用于判断哪个 partition 最快排到）：

```bash
squeue -o "%P %T %r" --noheader | sort | uniq -c | sort -rn
```

---

## 第三步：筛选与评分

对每个候选节点/partition，按以下三条标准综合评分（优先级从高到低）：

### (a) 最快能排到 ⭐⭐⭐（最高优先级）
- idle 节点 > mixed 节点（idle 立即可用）
- 当前 partition 队列中 PENDING job 数少的优先
- 节点状态为 `idle` 的直接得高分

### (b) 满足 GPU 需求 ⭐⭐⭐（必要条件）
对每个节点运行：
```bash
scontrol show node <nodename>
```
提取 `Gres`、`CfgTRES`、`AllocTRES` 字段，计算该节点剩余可用 GPU 数量。
- **必须满足目标需求的 GPU 数量**，不满足的直接淘汰
- GPU 型号匹配脚本中指定型号的优先（若脚本未指定型号则不限）

### (c) 可用时长越长越好 ⭐⭐
- 将 `D-HH:MM:SS` / `HH:MM:SS` / `infinite` 统一转换为分钟数比较
- 时长 ≥ 脚本申请时长的节点才合格，否则淘汰
- 时长越长越好

---

## 第四步：输出结果

### 脚本需求摘要
```
GPU:  <需求>
时长: <需求>
内存: <需求>
CPU:  <需求>
```

### 候选节点列表（按综合评分降序）

| 排名 | 节点 | Partition | 状态 | 可用GPU | 最大时长 | CPU | 内存 | 评分说明 |
|------|------|-----------|------|---------|---------|-----|------|---------|
| 🥇   | ...  | ...       | idle | ...     | ...     | ... | ...  | 立即可用，时长充足 |
| 🥈   | ...  | ...       | mixed| ...     | ...     | ... | ...  | 有空闲GPU，队列短 |

### 推荐提交命令

基于第 1 名节点，给出两种提交方式：

**直接指定节点（最快）：**
```bash
sbatch --nodelist=<node> -p <partition> <script>
```

**仅指定 partition（更灵活）：**
```bash
sbatch -p <partition> <script>
```

---

## 注意事项

- 若 `$ARGUMENTS` 为空，提示用户：`用法：/slurm-idle <path/to/script.slurm>`，然后仅展示集群空闲节点概况
- 若无满足需求的节点，说明原因（是 GPU 不足还是时长不够），并建议最接近的替代方案
- mixed 节点需通过 `AllocTRES` vs `CfgTRES` 对比计算剩余 GPU，不要直接信任 Gres 字段
- 若 `sinfo` 不存在，提示用户确认是否在 SLURM 登录节点上运行
