#!/usr/bin/env bash
set -euo pipefail

# Initialize repo if not already
git init

# Build list of unique YYYY-MM-DD days from file mtimes
days=$(
  find . -type f ! -path "./.git/*" -print0 \
  | while IFS= read -r -d '' f; do
      stat -f "%Sm" -t "%Y-%m-%d" "$f"
    done | sort -u
)

# Iterate days in ascending order
for day in $days; do
  echo "Creating commit for $day"

  # Clear staged set (no-op if none)
  git reset >/dev/null 2>&1 || true

  # Stage only files modified on this day
  git reset >/dev/null 2>&1 || true
  find . -type f ! -path "./.git/*" -print0 \
|   while IFS= read -r -d '' f; do
      fday=$(stat -f "%Sm" -t "%Y-%m-%d" "$f")
      if [[ "$fday" == "$day" ]]; then
        git add -- "$f" 2>/dev/null || true
      fi
    done

  # Skip if nothing was staged for this day
  if git diff --cached --quiet; then
    continue
  fi

  commitdate="$day 23:59:59"
  GIT_COMMITTER_DATE="$commitdate" git commit --date="$commitdate" -m "Project state on $day"
done
