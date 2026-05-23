---
allowed-tools: Bash(git clone:*), Bash(git add:*), Bash(git commit:*), Bash(git push:*), Bash(git pull:*), Bash(git status:*), Bash(mkdir:*), Bash(cp:*), Bash(rsync:*)
description: Sync ~/.claude/commands and ~/.claude/CLAUDE.md to GitHub repo
---

## Your task

Sync `~/.claude/commands/` and `~/.claude/CLAUDE.md` to the remote repository `https://github.com/Zhuofeng-Li/claude-code-settings`.

Steps:

1. Ensure the local repo clone exists:
   - If `~/claude-code-settings` does not exist, run `git clone https://github.com/Zhuofeng-Li/claude-code-settings ~/claude-code-settings`
   - If it already exists, run `git -C ~/claude-code-settings pull` to get the latest changes

2. Sync files:
   - Create `~/claude-code-settings/commands/` if it doesn't exist
   - Copy all `.md` files from `~/.claude/commands/` to `~/claude-code-settings/commands/`
   - Copy `~/.claude/CLAUDE.md` to `~/claude-code-settings/CLAUDE.md`

3. Commit and push:
   - Run `git -C ~/claude-code-settings add .`
   - Check `git -C ~/claude-code-settings status` for changes
   - If there are changes, commit with `git -C ~/claude-code-settings commit -m "sync: update claude settings $(date '+%Y-%m-%d %H:%M')"`
   - Run `git -C ~/claude-code-settings push`
   - If no changes, inform the user that everything is already up to date

4. Report the sync result, including which files were synced.
