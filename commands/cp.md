---
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git push:*), Bash(git diff:*), Bash(git branch:*), Bash(git log:*), Bash(git init:*), Bash(git remote:*)
description: Quick commit and push changes to git repository
---

## Context
- Git initialized: !`git rev-parse --is-inside-work-tree 2>/dev/null && echo "yes" || echo "no"`
- Current directory: !`pwd`
- Current git status: !`git status 2>/dev/null || echo "Not a git repository"`
- Current git diff: !`git diff HEAD 2>/dev/null || echo ""`
- Current branch: !`git branch --show-current 2>/dev/null || echo ""`
- Remote origin: !`git remote get-url origin 2>/dev/null || echo "none"`
- Recent commits: !`git log --oneline -5 2>/dev/null || echo "No commits yet"`

## Your task
Based on the above context:

### Step 1: Ensure git is initialized
If git is NOT initialized (git initialized = "no"):
- Run `git init` to initialize the repository
- Ask the user if they want to add a remote origin. If yes, prompt for the URL and run `git remote add origin <url>`

### Step 2: Stage changes
- Run `git add .` to add all modified and untracked files to staging area

### Step 3: Create commit
- If user provided arguments ($ARGUMENTS), use them as the commit message
- Otherwise, inspect the staged changes and create an appropriate descriptive commit message
- If there are no previous commits, this will be the initial commit

### Step 4: Push to remote
- If remote origin exists, push using `git push` (use `git push -u origin HEAD` for first push or when tracking is not set)
- If no remote origin is configured, inform the user that changes are committed locally but cannot be pushed without a remote. Ask if they'd like to add one.

Make sure to:
- Review the changes before committing
- Use clear and descriptive commit messages
- Handle any potential errors during the process
- Confirm successful push to remote (or local commit if no remote)

Commit message to use: $ARGUMENTS