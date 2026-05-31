# Development Guidelines

This document contains critical information about working with this codebase. Follow these guidelines precisely.

## Core Development Rules

1. Package Management
   - ONLY use uv, NEVER pip
   - Installation: `uv pip install <package>`
   - Running tools: `uv run <tool>`

## Basic Information

1. Github
   - Username: Zhuofeng-Li
   - Email: 100427192@qq.com

## Command Management

1. Whenever any file under `~/.claude/commands/` is modified, automatically git commit and push the changes to github repo https://github.com/Zhuofeng-Li/claude-code-settings
2. Whenever `~/.claude/CLAUDE.md` is modified, automatically git commit and push the changes to github repo https://github.com/Zhuofeng-Li/claude-code-settings

## File Generation Rules

1. When generating a standalone executable file (e.g., a Python script, shell script, or any file meant to be run directly), you MUST include the common invocation command(s) at the top of the file, in a comment or docstring. For example, a Python script should show the typical `uv run python script.py <args>` usage in its module docstring.
2. For shell scripts that require environment variables, the Usage block MUST show a complete invocation example with all required env vars inlined, e.g.:
   ```
   # Usage:
   #   MASTER_ADDR=10.0.0.1 \
   #   HOSTFILE=/path/to/hostfile \
   #   WANDB_KEY=<key> \
   #   bash scripts/foo.sh
   ```

## Skill Self-Improvement

1. When executing a skill (custom command under `~/.claude/commands/`), if you discover a better approach, best practice, bug fix, or any improvement during the process, you MUST update the corresponding skill file to incorporate the improvement before finishing the task. Always keep skills evolving and up-to-date.

## HuggingFace Upload Best Practices

1. **Always install `hf_transfer`** before uploading large datasets: `uv pip install hf_transfer`
2. **Enable hf_transfer in both shell AND Python**: set `HF_HUB_ENABLE_HF_TRANSFER=1` as env var AND `os.environ['HF_HUB_ENABLE_HF_TRANSFER'] = '1'` inside the Python process
3. **Use `num_workers=16`** with `upload_large_folder` for maximum parallel throughput
4. **Use Python API directly** (`HfApi.login()`) instead of `huggingface-cli` or `uv tool run hf` — more reliable across venv configurations
5. **HF commit rate limit**: 128 commits/hour. When deleting many files, use batches of 250+ files per commit and add 65-second retry on 429 errors
6. **Verify AKIA false positives**: base64-encoded image/binary data in `agent-messages.jsonl` / `requests.jsonl` may contain strings that match `AKIA[A-Z0-9]` — check case sensitivity and surrounding context before blocking upload