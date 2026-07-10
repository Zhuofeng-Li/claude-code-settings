# Frontier-CS Results Analysis

Analyze frontier-cs-algorithm job results and display a formatted Unicode table showing ALL attempts per problem.

## Arguments

The user provides one or more job directory paths (relative or absolute) as $ARGUMENTS.

## Instructions

For each job directory provided in $ARGUMENTS:

1. Locate all trial subdirectories (pattern: `frontier-cs-algorithm-{id}__{hash}`)
2. Group trials by problem ID (numeric, extracted from dir name)
3. For each trial, read:
   - `verifier/reward.json` for judge results (score, cases, error details)
   - `agent/trajectory.json` for token metrics (`final_metrics.total_prompt_tokens`, `final_metrics.total_completion_tokens`) and consult count
4. Read one trial's parent job `config.json` to identify student model and teacher model

Count consults by finding steps where `source == "agent"` and `tool_calls` contains `function_name == "consult"`.

## Output Format

**CRITICAL**: The final output MUST be a Unicode box-drawing table where EVERY ROW corresponds to ONE attempt of ONE problem. Each problem has N attempts (typically 4), so there are N rows per problem. Group rows by problem with horizontal separators between problem groups.

Mark the best-scoring attempt per problem with ★ after the score.

### Table columns:
- **Problem**: numeric ID (only show on first row of each problem group, leave blank for subsequent attempts)
- **#**: attempt number (1, 2, 3, 4...)
- **Score**: 0-100, append ★ if this is the best attempt for that problem (and score > 0)
- **Cases**: passed/total (with ✓ if all passed)
- **In Tok**: total prompt tokens from trajectory
- **Out Tok**: total completion tokens from trajectory
- **Consults**: number of teacher tool calls (omit column entirely if no teacher/consult in any trial)
- **详细结果**: condensed error classification (see rules below)

### Error classification rules for 详细结果:
- `"compile failed"` in detail/error → `编译失败`
- `"empty"` in detail → `空提交`
- No cases or score is None → `无结果`
- All cases scoreRatio >= 0.99 → `满分通过`
- `"Overlap"` in msg → `Overlap(N)`
- `"Out of bounds"` in msg → `OOB(N)`
- `"(signal=unknown)"` in msg → `Protocol违规(N)`
- `"buffer overflow"` in msg → `Buffer overflow(N)`
- `"too many queries"` in msg → `查询超限(N)`
- `"Answer exists but -1"` in msg → `误判无解(N)`
- Other non-empty msg with scoreRatio < 0.99 → extract key metric (Your=X, Best=X, Value=X, Min distance=X, Wrong guess N, No correct guess, Not palindrome, etc.)
- Empty msg with scoreRatio < 0.99 → `WA(N)`
- Multiple error types in same trial → join with "; "

### Table format (example with 4 attempts per problem):
```
MODEL: {model_name} (agent_name, no teacher)
配置: max_turns=X, max_checkpoints=Y, n_attempts=Z

┌─────────┬───┬───────┬───────┬────────┬─────────┬───────────────────────────────────────────────────────┐
│ Problem │ # │ Score │ Cases │ In Tok │ Out Tok │ 详细结果                                              │
├─────────┼───┼───────┼───────┼────────┼─────────┼───────────────────────────────────────────────────────┤
│ 0       │ 1 │    0  │ 0/70  │  9,027 │  11,093 │ Overlap(58); WA(12)                                   │
│         │ 2 │    0  │ 0/70  │ 18,385 │  15,047 │ Protocol违规(54); WA(16)                              │
│         │ 3 │    0  │ 0/70  │ 13,772 │  22,379 │ OOB(4); Protocol违规(66)                              │
│         │ 4 │    0  │ 0/70  │  5,148 │  13,196 │ Overlap(5); OOB(1); WA(64)                            │
├─────────┼───┼───────┼───────┼────────┼─────────┼───────────────────────────────────────────────────────┤
│ 1       │ 1 │   95★ │ 0/3   │  3,948 │   9,221 │ Value: 174740202                                      │
│         │ 2 │    0  │ 0/3   │  3,836 │   6,225 │ 编译失败                                              │
│         │ 3 │    0  │ 0/0   │  5,992 │   7,338 │ 无结果                                                │
│         │ 4 │    0  │ 0/0   │ 14,016 │  27,826 │ 无结果                                                │
├─────────┼───┼───────┼───────┼────────┼─────────┼───────────────────────────────────────────────────────┤
│ ...     │   │       │       │        │         │                                                       │
└─────────┴───┴───────┴───────┴────────┴─────────┴───────────────────────────────────────────────────────┘

Best-of-N 均值: XX.X/100 | 满分: X/Y | >50分: X/Y | 零分: X/Y
All attempts 均值: XX.X/100 (共Z次)
```

### With teacher/consults (add Consults column):
```
┌─────────┬───┬───────┬───────┬────────┬─────────┬──────────┬─────────────────────────────────────────────┐
│ Problem │ # │ Score │ Cases │ In Tok │ Out Tok │ Consults │ 详细结果                                    │
├─────────┼───┼───────┼───────┼────────┼─────────┼──────────┼─────────────────────────────────────────────┤
│ ...     │   │       │       │        │         │          │                                             │
└─────────┴───┴───────┴───────┴────────┴─────────┴──────────┴─────────────────────────────────────────────┘
```

### Summary line after table:
- Best-of-N 均值 (take max score per problem, then average)
- 满分 count (score >= 99)
- >50分 count
- 零分 count
- All attempts 均值 (average of all individual attempt scores)

If multiple job dirs provided, output one table per job for comparison.

## Important Notes

- Sort problems by numeric ID ascending
- Sort attempts within each problem by directory name (alphabetical hash) to maintain consistent ordering across runs
- Handle None/null scores as 0
- Handle missing trajectory files gracefully (show "—" for tokens)
- Use comma separators for token numbers (e.g. 12,686)
- Right-align numeric columns (Score, In Tok, Out Tok, Consults)
- Left-align text columns (Problem, Cases, 详细结果)
- The 详细结果 column should be wide enough to show useful info but truncate at ~55-65 chars if needed
