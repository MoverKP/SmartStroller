# Git Commands Cheat Sheet

Quick reference for daily Git operations in the SmartStroller project.

---

## Basic Workflow

```powershell
# Check current status
git status

# Add all changes
git add .

# Add specific file
git add filename.txt

# Commit with message
git commit -m "Your commit message"

# Push to remote
git push

# Pull latest changes
git pull
```

---

## Complete Daily Workflow

```powershell
# 1. Check what changed
git status

# 2. Add all changes
git add .

# 3. Commit with descriptive message
git commit -m "Add new feature: motor control UI"

# 4. Push to GitHub
git push
```

---

## Branch Operations

```powershell
# List all branches
git branch

# List remote branches
git branch -a

# Create new branch
git branch feature-name

# Switch to branch
git checkout feature-name

# Create and switch to new branch
git checkout -b feature-name

# Delete local branch
git branch -d feature-name

# Rename current branch
git branch -m new-name
```

---

## Remote Operations

```powershell
# View remote URLs
git remote -v

# Add remote
git remote add origin https://github.com/user/repo.git

# Change remote URL
git remote set-url origin https://github.com/user/new-repo.git

# Remove remote
git remote remove origin

# Fetch without merging
git fetch origin

# Fetch and prune deleted branches
git fetch --prune
```

---

## Undo Changes

```powershell
# Discard changes in working directory (not committed yet)
git restore filename.txt

# Discard all changes
git restore .

# Undo last commit (keep changes)
git reset --soft HEAD~1

# Undo last commit (discard changes)
git reset --hard HEAD~1

# Create new commit to undo previous commit
git revert <commit-hash>
```

---

## View History

```powershell
# View commit history
git log

# View compact history (one line per commit)
git log --oneline

# View last 5 commits
git log -5

# View history with graph
git log --oneline --graph --all

# View who changed a file
git blame filename.txt

# View changes in a commit
git show <commit-hash>
```

---

## Compare Changes

```powershell
# View unstaged changes
git diff

# View staged changes
git diff --staged

# Compare two branches
git diff main..feature-name

# Compare specific file
git diff filename.txt
```

---

## Stash (Temporary Save)

```powershell
# Stash current changes
git stash

# Stash with message
git stash save "Work in progress on feature X"

# List stashes
git stash list

# Apply latest stash
git stash pop

# Apply specific stash
git stash apply stash@{0}

# Drop stash
git stash drop
```

---

## Merge and Rebase

```powershell
# Merge branch into current branch
git merge feature-name

# Rebase current branch onto main
git rebase main

# Abort a merge conflict
git merge --abort

# Abort a rebase
git rebase --abort
```

---

## Force Operations (Use Carefully!)

```powershell
# Force push (overwrite remote)
git push --force

# Force push with lease (safer - checks remote first)
git push --force-with-lease

# Reset to remote state
git fetch origin
git reset --hard origin/main
```

---

## Clean Up

```powershell
# Remove untracked files (dry run - shows what would be deleted)
git clean -n

# Remove untracked files
git clean -f

# Remove untracked files and directories
git clean -fd

# Remove untracked files including ignored
git clean -fdx
```

---

## Troubleshooting

```powershell
# Fix "failed to push" - pull first
git pull --rebase
git push

# Fix detached HEAD
git checkout main

# Undo accidental git add
git restore --staged filename.txt

# Fix line ending issues (Windows)
git config --global core.autocrlf true

# View git config
git config --list

# Increase HTTP buffer (for large files)
git config --global http.postBuffer 524288000
```

---

## Useful Aliases (Optional Setup)

```powershell
# Set up shortcuts
git config --global alias.st status
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.cm "commit -m"
git config --global alias.lg "log --oneline --graph --all"

# Now you can use:
git st          # instead of git status
git co main     # instead of git checkout main
git br          # instead of git branch
git cm "msg"    # instead of git commit -m "msg"
git lg          # nice log view
```

---

## SmartStroller Project Specific

```powershell
# Daily update workflow
git add .
git commit -m "Update FYP document"
git push

# Quick status check
git status

# View recent changes
git log --oneline -10

# Check if up to date with remote
git fetch
git status
```

---

## GitHub CLI (gh) Commands

```powershell
# Install GitHub CLI first: winget install GitHub.cli

# Login to GitHub
gh auth login

# Create repo from existing folder
gh repo create SmartStroller --public --source=. --push

# View repo info
gh repo view

# Create pull request
gh pr create --title "Feature title" --body "Description"

# View PRs
gh pr list

# Clone repo
gh repo clone MoverKP/SmartStroller
```

---

## Quick Reference Card

| Task | Command |
|------|---------|
| Check status | `git status` |
| Add all | `git add .` |
| Commit | `git commit -m "msg"` |
| Push | `git push` |
| Pull | `git pull` |
| View history | `git log --oneline` |
| Undo last commit | `git reset --soft HEAD~1` |
| Discard changes | `git restore .` |
| Create branch | `git checkout -b name` |
| Switch branch | `git checkout name` |
| Merge branch | `git merge name` |

---

**Repository URL:** https://github.com/MoverKP/SmartStroller
