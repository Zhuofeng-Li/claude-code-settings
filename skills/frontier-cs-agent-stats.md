# Frontier-CS Agent Stats

Analyze frontier-cs-mas agent behavior: tool call counts (teacher consults), turns, termination reasons, and answer format per problem.

## When to use

Use this skill when the user asks to:
- Count tool calls / consults per problem
- Analyze agent behavior in frontier-cs jobs
- Check how many times teacher was called
- See termination reasons per trial
- Understand why agents failed to submit

Trigger phrases: "统计工具调用", "tool call 次数", "consult 次数", "agent 行为", "agent stats", "调用 teacher 的次数"

## Arguments

One or more job directory paths, e.g.:
- `tmp/Qwen3.5-122B-A10B-frontier-cs-mas-2026-07-09__22-04-37`
- `jobs/some-job-dir`

## Instructions

1. For each job directory, locate all trial subdirectories
2. Read `agent/trajectory.json` for each trial
3. Count consults by finding steps where `source == "agent"` and `tool_calls` contains `function_name == "consult"`
4. Extract from trajectory:
   - Total steps
   - Agent turns (steps with `source == "agent"`)
   - Consult count (teacher calls)
   - Whether `<answer>` tag was used vs ```cpp vs no code
   - Termination reason from `final_metrics.extra.termination_reason`
5. Read `verifier/reward.json` for score
6. Read trial `config.json` for model names (student + teacher)

## Output format

First show model info from config, then the table:

```
MODEL: {student_model} + {teacher_model} teacher (MAS)
Config: max_consults={N}, max_turns={N}

  ┌─────────┬───────┬────────┬──────────┬─────────┬────────────┬──────────────────────────────────────────────────────────────┐
  │ Problem │ Score │ Turns  │ Consults │ Answer  │ Termin.    │ 摘要                                                           │
  ├─────────┼───────┼────────┼──────────┼─────────┼────────────┼──────────────────────────────────────────────────────────────┤
  │ {pid}   │ {sc}  │ {t}    │ {c}      │ {fmt}   │ {reason}   │ {summary}                                                      │
  └─────────┴───────┴────────┴──────────┴─────────┴────────────┴──────────────────────────────────────────────────────────────┘
```

Where:
- **Turns**: number of agent response steps
- **Consults**: number of successful `consult` tool calls (teacher invocations)
- **Answer**: format of submitted code — `<answer>`, ` ```cpp `, `raw code`, or `无代码`
- **Termin.**: `answer` (normal submit), `max_turns` (truncated), `invalid_output_limit`
- **摘要**: one-line summary combining score result + consult usage pattern

## Summary section

After the table, add analysis:

```
分析:
  - 总 consult 调用: {total} 次 / {n_problems} 题 (平均 {avg:.1f} 次/题, 上限 {max_consults})
  - 0 次 consult 的题: {list} → 原因: {reason}
  - max_turns 终止的题: {list} → student 未能在限制内提交
  - 编译失败的题: {list} → 代码格式/语法问题
  - 满分的题: {list} → consult 模式: {pattern}
```
