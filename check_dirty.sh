#!/bin/bash
# Classify directories in ~/dev as non-git, git-clean, or git-dirty
# "dirty" means any uncommitted changes OR unpushed commits OR no remote

for d in */; do
  d="${d%/}"
  [ ! -d "$d" ] && continue

  if [ ! -d "$d/.git" ]; then
    echo "non-git,$d"
    continue
  fi

  cd "$d"

  # Check for uncommitted changes (staged, unstaged, or untracked)
  if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    echo "git-dirty,$d"
    cd ..
    continue
  fi

  # Check for unpushed commits
  remote=$(git remote 2>/dev/null | head -1)
  if [ -z "$remote" ]; then
    echo "git-dirty,$d"
    cd ..
    continue
  fi

  upstream=$(git rev-parse --abbrev-ref @{upstream} 2>/dev/null)
  if [ -z "$upstream" ]; then
    # No upstream tracking — check if current branch exists on remote
    branch=$(git branch --show-current 2>/dev/null)
    remote_ref=$(git ls-remote --heads "$remote" "$branch" 2>/dev/null | head -1)
    if [ -z "$remote_ref" ]; then
      echo "git-dirty,$d"
      cd ..
      continue
    fi
    remote_sha=$(echo "$remote_ref" | awk '{print $1}')
    local_sha=$(git rev-parse HEAD 2>/dev/null)
    if [ "$local_sha" != "$remote_sha" ]; then
      echo "git-dirty,$d"
      cd ..
      continue
    fi
  else
    ahead=$(git rev-list --count "$upstream..HEAD" 2>/dev/null)
    if [ "$ahead" -gt 0 ] 2>/dev/null; then
      echo "git-dirty,$d"
      cd ..
      continue
    fi
  fi

  echo "git-clean,$d"
  cd ..
done
