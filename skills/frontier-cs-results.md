# Frontier-CS Results Analysis

Analyze frontier-cs-algorithm job results and display a formatted summary table showing score, cases passed, token usage, and detailed error reasons per problem.

## When to use

Use this skill when the user asks to:
- Analyze frontier-cs job results
- Show frontier-cs scores/results
- Compare frontier-cs runs
- Summarize judge output for frontier-cs

Trigger phrases: "分析 frontier-cs 结果", "frontier-cs results", "frontier cs main results", "分析这个 job", "judge 结果"

## Arguments

The user provides one or more job directory paths (relative or absolute), e.g.:
- `tmp/kimi-k2.6-frontier-cs-algorithm-2026-06-26__21-49-01`
- `jobs/Qwen3.5-122B-A10B-frontier-cs-mas-2026-07-09__22-04-37`

## Instructions

1. For each job directory, locate all trial subdirectories (pattern: `frontier-cs-algorithm-{id}__{hash}`)
2. Read `verifier/reward.json` for judge results and `agent/trajectory.json` for token metrics
3. Output a formatted table per job with these columns:
   - Problem ID (numeric, sorted)
   - Score (0-100)
   - Cases (passed/total, with ✓ if all passed)
   - In Tok (total prompt tokens from trajectory)
   - Out Tok (total completion tokens from trajectory)
   - 详细结果 (detailed error summary)

4. Error classification rules:
   - `"compile failed"` in detail/error → `编译失败: {first error line}`
   - `"empty"` in detail → `空提交: solution.cpp is empty`
   - All cases scoreRatio >= 0.99 → `满分通过` (extract Value/Your/Best from msg)
   - `"Overlap"` in msg → `Overlap(拼图重叠) (N个case)`
   - `"Out of bounds"` in msg → `Out of bounds(坐标越界) (N个case)`
   - `"(signal=unknown)"` in msg → `Protocol error(交互协议违规) (N个case)`
   - `"buffer overflow"` in msg → `Buffer overflow(数组越界崩溃) (N个case)`
   - `"too many queries"` in msg → `Too many queries(查询次数超限) (N个case)`
   - `"translate:wrong"` in msg → `Wrong translation(翻译错误) (N个case)`
   - `"Answer exists but -1"` in msg → `误判无解(Answer exists but -1) (N个case)`
   - `"XOR collision"` in msg → `XOR collision({detail}) (N个case)`
   - `"wrong output format"` in msg → `输出格式错误 (N个case)`
   - `"points"` in msg with scoreRatio < 0.99 → partial score, show ratio range
   - Empty msg → `WA(无具体msg) (N个case)`

5. For partial scores, extract and display:
   - Min~Max ratio range
   - Key metrics from msg: Value=, Your= vs Best=, Min distance, Correct guess, etc.

6. Table format (fixed-width, Chinese headers):
```
  ┌─────────┬───────┬───────┬─────────┬──────────┬──────────────────────────────────────────────────────────────────────────────┐
  │ Problem │ Score │ Cases │ In Tok  │ Out Tok  │ 详细结果                                                                     │
  ├─────────┼───────┼───────┼─────────┼──────────┼──────────────────────────────────────────────────────────────────────────────┤
  │ {pid}   │ {sc}  │ {c}   │ {in}    │ {out}    │ {detail}                                                                     │
  ├─────────┼───────┼───────┼─────────┼──────────┼──────────────────────────────────────────────────────────────────────────────┤
  │ Mean    │ {m}   │       │ {sum_i} │ {sum_o}  │                                                                            │
  └─────────┴───────┴───────┴─────────┴──────────┴──────────────────────────────────────────────────────────────────────────────┘
```

7. Include model name in the header. Infer from:
   - Job directory name (e.g., `kimi-k2.6-frontier-cs-algorithm-...` → `kimi-k2.6`)
   - Or from `config.json` agent model_name field
   - If MAS (multi-agent), note the teacher model too

8. If multiple job dirs provided, output one table per job for side-by-side comparison.

## Example output

```
MODEL: kimi-k2.6（带 teacher 指导）

  ┌─────────┬───────┬───────┬─────────┬──────────┬──────────────────────────────────────────────────────────────────────────────┐
  │ Problem │ Score │ Cases │ In Tok  │ Out Tok  │ 详细结果                                                                     │
  ├─────────┼───────┼───────┼─────────┼──────────┼──────────────────────────────────────────────────────────────────────────────┤
  │ 0       │     0 │ 0/70  │    1059 │    61546 │ Out of bounds(坐标越界) (44个case); Overlap(拼图重叠) (26个case)                       │
  │ 1       │   100 │ 3/3 ✓ │    1155 │    60980 │ 满分通过 (Value=176450435)                                                       │
  │ 109     │   100 │ 3/3 ✓ │     594 │    36870 │ 满分通过 (Your=443556, Best=443556)                                              │
  │ 119     │   6.9 │ 0/3   │     714 │    34100 │ 部分分 ratio=6.82%~6.94% — 猜对太少                                                 │
  ├─────────┼───────┼───────┼─────────┼──────────┼──────────────────────────────────────────────────────────────────────────────┤
  │ Mean    │  49.1 │       │   12310 │   685437 │                                                                            │
  └─────────┴───────┴───────┴─────────┴──────────┴──────────────────────────────────────────────────────────────────────────────┘
```
