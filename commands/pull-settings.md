---
description: Pull claude settings from GitHub repo to local ~/.claude/
allowed-tools: Bash(git:*), Bash(cp:*), Bash(mkdir:*), Bash(ls:*), Bash(rsync:*)
---

# Pull Settings

Pull `commands/`, `skills/`, and `CLAUDE.md` from the remote repository `https://github.com/Zhuofeng-Li/claude-code-settings` into `~/.claude/`.

## Steps:

1. Ensure the local repo clone exists:
   - If `~/claude-code-settings` does not exist, run `git clone https://github.com/Zhuofeng-Li/claude-code-settings ~/claude-code-settings`
   - If it already exists, run `git -C ~/claude-code-settings pull` to get the latest changes

2. Sync files from repo to `~/.claude/`:
   - Copy all `.md` files from `~/claude-code-settings/commands/` to `~/.claude/commands/`
   - Copy `~/claude-code-settings/CLAUDE.md` to `~/.claude/CLAUDE.md`
   - If `~/claude-code-settings/skills/` exists, copy its contents to `~/.claude/skills/`

3. Report results:
   - List which files were updated
   - If already up to date, inform the user

## Notes:

- This is the reverse of `/sync-settings` — it pulls FROM GitHub, not pushes TO it
- Local files will be overwritten by the remote versions
- Always pull latest before making local edits to avoid conflicts
