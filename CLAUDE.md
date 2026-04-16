# ~/dev Cleanup Instructions

This directory contains scripts for organizing `~/dev`. The goal is to produce
a `~/dev/cleanup.sh` script containing only `mv` commands that sorts the
contents of ~/dev into three buckets:

- **Keep in place** — actively used, no `mv` line needed
- **Move to `.delete/`** — safe to remove (will be `rm -rf`'d later by the user)
- **Move to `.review/`** — has local-only work that needs human review before
  deletion

## Investigate Phase

### Step 1: Run `check_dirty.sh`

Run `dev_review/check_dirty.sh` from `~/dev`. It outputs CSV lines:

    git-clean,dirname
    git-dirty,dirname
    non-git,dirname

- `git-clean` = no uncommitted changes, no unpushed commits, remote is in sync
- `git-dirty` = has uncommitted changes, unpushed commits, no remote, or branch
  not on remote
- `non-git` = not a git repository

### Step 2: Classify each item

For each directory (and any loose files like `.tar.gz`), determine the action:

#### KEEP (no line in `cleanup.sh`)

- Recently active (commits or meaningful file changes in the last ~12 months)
- The `dev_review/` directory itself — never move or delete this
- `CLAUDE.md` symlink — never move or delete this
- Always keep regardless of activity: `julia`, `juliaup`, `karpinski.org`,
  `julialang.org`

#### MOVE TO `.delete/`

All of these conditions must be met:
- `git-clean` status from `check_dirty.sh`
- Not recently active
- Is a clone of someone else's repo (check the git remote URL — if it's not
  under `StefanKarpinski/` or `JuliaComputing/` on GitHub, it's third-party)
- OR: is a `non-git` directory that's clearly an extracted open-source tarball
  (look for configure scripts, `LICENSE` files from known projects, version
  numbers in directory names like `wget-1.20.3/`)
- OR: is an empty directory
- OR: is a loose `.tar.gz` of a downloadable open-source package

#### MOVE TO `.review/`

- `git-dirty` repos that are NOT recently active — these have local work that
  would be lost
- `non-git` directories that contain original work (scripts, data, projects)
  that aren't clearly re-downloadable
- Items where you're unsure — when in doubt, `.review/` is safer than `.delete/`

#### Special judgment calls

- **Stefan's own repos** (`StefanKarpinski/*` remote): if `git-clean` and old,
  these can go to `.delete/` since they're fully pushed. If `git-dirty`, they
  MUST go to `.review/`.
- **JuliaComputing/JuliaHub repos**: same rule as Stefan's own repos.
- **Duplicate clones** (e.g. two checkouts of the same repo): the older/inactive
  one can go to .delete/ if clean. However, you should check if one of them is a
  git worktree of the other; if so, deleting one of them could break the other.
  In that case, special action may need to be taken.
- **`Dyad/` directory:** This is a collection of repos, not a single project.
  Treat each subdirectory inside `Dyad/` as if it were a top-level item and
  classify it individually. When moving, use `move "Dyad/subdir" .delete/` or
  `move "Dyad/subdir" .review/` — it's fine to drop the `Dyad/` prefix (the
  subdirectory lands directly in `.delete/` or `.review/`). If all subdirectories
  are moved out, delete the empty `Dyad/` directory too.

### Step 3: Investigate dirty repos

For each `git-dirty` repo, examine what's dirty to inform the keep/review
decision:

- `git status --short` — what files are modified?
- `git log --oneline -5` — what are the recent commits?
- `git log --oneline @{upstream}..HEAD 2>/dev/null` — what's unpushed?
- `git remote -v` — who owns it?
- `git log -1 --format=%ci` — when was the last commit?

If the dirty state is just build artifacts or .DS_Store in a third-party repo
that's otherwise clean and old, it can go to `.delete/`. Use judgment; if in
doubt, put it in `.review/`.

### Step 4: Generate `cleanup.sh`

Write `~/dev/cleanup.sh` with this structure:

```bash
#!/bin/bash
# Generated cleanup script for ~/dev
# Review before running! Lines can be commented out to skip items.

cd ~/dev

# Create target directories
mkdir -p .delete .review

# Idempotent move: skip items that no longer exist (already moved or removed)
move() { [ -e "$1" ] && mv -n "$1" "$2"; }

# --- Items proposed for deletion ---
move "item1" .delete/
move "item2" .delete/
# ... etc

# --- Items that need review ---
move "item3" .review/
move "item4" .review/
# ... etc
```

Rules for the script:
- Use the `move` helper for all moves (not bare `mv`)
- Always quote item names
- Add a brief comment before groups explaining why
  (e.g. `# Third-party clean clones`)
- Include `.tar.gz` files as well as directories
- Do NOT include any `rm` commands — the user will delete `.delete/` manually
- Do NOT move `dev_review/` or the `CLAUDE.md` symlink
- Sort entries alphabetically within each group for easy scanning

### Step 5: Generate `NOTES.md` files

Write two notes files alongside `cleanup.sh`. These will end up inside
`.delete/` and `.review/` after the script runs, so write them to those paths.

#### `.delete/NOTES.md`

One line per item. Keep it terse — just the reason it's proposed for deletion.
Format:

```markdown
# Proposed Deletions

- `dirname/` — third-party clone, clean (remote: org/repo)
- `other.tar.gz` — downloadable open-source tarball
- `emptydir/` — empty directory
```

#### `.review/NOTES.md`

A few lines per item. Include enough context that a separate Claude session
(or the user) can make a decision without re-investigating from scratch:

- What the item is (repo, script, data, etc.)
- Who owns it (remote URL or "local-only")
- What's dirty (unpushed commits, uncommitted files, no remote)
- Summary of the local-only work (unpushed commit messages, description of
  modified files)
- A suggested action (push then delete, keep, inspect specific files, etc.)

Format:

```markdown
# Items Needing Review

## `dirname/`
- **What:** Julia package for X
- **Remote:** git@github.com:StefanKarpinski/Foo.jl (or "none — local only")
- **Dirty state:** 3 unpushed commits, 2 uncommitted files
- **Unpushed commits:** `abc1234 add feature X`, `def5678 wip refactor`
- **Uncommitted files:** `src/bar.jl` (modified), `test/runtests.jl` (new)
- **Suggested action:** push to remote then delete / inspect src/bar.jl for
  unfinished work / probably safe to delete, changes are trivial
```

Create `~/dev/.delete/` and `~/dev/.review/` directories and write the NOTES.md
files into them immediately. The cleanup.sh script's `mkdir -p` is harmless if
they already exist. This way the notes are in place before the user runs the
script and starts moving items in.

### Step 6: Generate `NOTES.md`

Write `~/dev/NOTES.md` with one line per item that is being **kept** in place
(i.e. not moved to `.delete/` or `.review/`). Each line should give the reason
it's being kept. Format:

```markdown
# Kept Items

- `dirname/` — active: last commit 2026-04-13, on branch sk/feature
- `other/` — active: JuliaComputing work repo, last commit 2025-09-23
- `dev_review/` — cleanup tooling (never move)
```

This serves as both documentation and a completeness check (see Step 7).

### Step 7: Verify completeness

After generating all outputs, verify that **every item** in `~/dev` is accounted
for in exactly one of:

- `cleanup.sh` (moved to `.delete/` or `.review/`)
- `NOTES.md` (kept in place)

To verify, run:

```bash
# Items in ~/dev (excluding hidden dirs and the CLAUDE.md symlink)
ls -1 ~/dev | grep -v '^\.' | sort > /tmp/dev_all.txt

# Items accounted for in cleanup.sh and NOTES.md
grep -oP '(?<=move ")[^"]+' ~/dev/cleanup.sh | sort > /tmp/dev_moved.txt
grep -oP '(?<=^- `)[^`]+(?=/?`)' ~/dev/NOTES.md | sort > /tmp/dev_kept.txt
sort -u /tmp/dev_moved.txt /tmp/dev_kept.txt > /tmp/dev_accounted.txt

# Show any gaps
comm -23 /tmp/dev_all.txt /tmp/dev_accounted.txt
```

If any items are unaccounted for, go back and classify them. Do not consider the
Investigate Phase complete until this check passes with no output.

### Summary of Investigate Phase outputs

Running the Investigate Phase should produce exactly four artifacts:

1. `~/dev/cleanup.sh` — the move script
2. `~/dev/.delete/NOTES.md` — terse deletion reasons
3. `~/dev/.review/NOTES.md` — detailed review context
4. `~/dev/NOTES.md` — kept items with reasons

After the Investigate Phase, the user will review and possibly edit these files,
then run `cleanup.sh`. The Investigate Phase may be repeated if the user makes
changes to this `CLAUDE.md` or wants a fresh pass.

---

## Review Phase

The Review Phase is interactive. It happens after `cleanup.sh` has been run and
items have been moved into `~/dev/.review/`. The goal is to go through each item
in `.review/` with the user and reach a decision.

### Setup

1. Read `~/dev/.review/NOTES.md` for context on each item.
2. List the items in `~/dev/.review/` to confirm what's there.

### For each item

Present the item to the user with its notes from `NOTES.md`, then ask:

```
**`dirname/`** — [one-line summary from notes]
[key details: dirty state, unpushed commits, etc.]

archive / delete / keep / next / shell / edit / web ?
```

If the item has an upstream remote, also offer `web` in the prompt. Derive the
HTTPS URL from the remote (convert `ssh://git@github.com/org/repo` or
`git@github.com:org/repo` to `https://github.com/org/repo`).

Only treat the response as a menu choice if it matches one of the valid choices
(case-insensitive). Abbreviations are allowed only when unambiguous:
- `a` → archive, `d` → delete, `k` → keep, `n` → next, `e` → edit, `w` → web
- `s` or `sh` → shell
- Full words always accepted: `archive`, `delete`, `keep`, `next`, `shell`, `edit`, `web`

Anything else is a freeform question or instruction — handle it normally, then
re-present the choice menu afterward.

**After every action that moves an item, keep the NOTES.md files in sync:**
- Remove the item's entry from `.review/NOTES.md`
- Add an entry to the destination's NOTES.md:
  - `.delete/NOTES.md` for delete
  - `.archive/NOTES.md` for archive
  - `~/dev/NOTES.md` for keep

- **delete:** Move to `~/dev/.delete/` and update NOTES.md files.
  ```
  mv ~/dev/.review/dirname ~/dev/.delete/
  ```

- **edit:** Open in VS Code with the repo folder plus all dirty files as tabs,
  then wait for it to close, then ask again.
  ```
  dir=~/dev/.review/dirname
  cd "$dir" && code -n -w . $(
    { git status --short | awk '{print $2}';
      git diff "@{upstream}..HEAD" --name-only 2>/dev/null; } | sort -u
  )
  ```
  For non-git items, just open the directory: `code -n -w ~/dev/.review/dirname`
  After the editor closes, re-present the same item and ask for a decision
  (delete / archive / next). Do not offer "edit" again.

- **web:** Open the upstream remote in the browser (GitHub/GitLab), then
  re-present the choice menu.
  ```
  open https://github.com/org/repo
  ```

- **shell:** Open a new iTerm2 tab in the item's directory via AppleScript,
  then re-present the choice menu.
  ```
  osascript -e '
  tell application "iTerm2"
    tell current window
      create tab with default profile
      tell current session of current tab
        write text "cd ~/dev/.review/dirname"
      end tell
    end tell
  end tell'
  ```

- **keep:** Move back to `~/dev/` and update NOTES.md files.
  ```
  mv ~/dev/.review/dirname ~/dev/
  ```
  Remove from `.review/NOTES.md` and append to `~/dev/NOTES.md`:
  `- \`dirname/\` — [one-line reason for keeping]`

- **archive:** Move to `~/dev/.archive/` and update NOTES.md files.
  ```
  mv ~/dev/.review/dirname ~/dev/.archive/
  ```

- **next:** Leave it in `.review/` and move on. No action needed.

The user may also:
- Ask questions about the item — investigate on the fly (read files, check git
  log, etc.) and then re-present the choice menu.
- Give a freeform instruction (e.g. "push it to GitHub first") — carry it out,
  then re-present the choice menu.

### After all items

Report a summary: how many deleted, archived, skipped/nexted. Note any items still
remaining in `.review/` for future sessions.

---

## Cleanup Phase

The Cleanup Phase runs after the Review Phase is complete. It ties up loose ends
and prompts the user to perform the irreversible cleanup actions.

### Step 1: Verify `.review/` is empty

Check that `~/dev/.review/` contains nothing except `NOTES.md` (which should
itself be empty — no item entries remaining):

```bash
ls ~/dev/.review/
```

If any items remain (other than `NOTES.md`), note them for the user — they were
skipped during review and should be addressed before finalizing. If the directory
is empty aside from `NOTES.md`, prompt the user:

> `.review/` is clear. You can delete it:
> ```
> rm -rf ~/dev/.review
> ```

### Step 2: Prompt to delete `.delete/`

Remind the user to review `.delete/NOTES.md` one last time, then permanently
remove everything:

> Ready to permanently delete all items in `.delete/`? Run:
> ```
> rm -rf ~/dev/.delete
> ```

### Step 3: Verify NOTES.md files are consistent

Check that each NOTES.md is consistent with the actual contents of its directory:

- **`~/dev/NOTES.md`** — every item listed should exist in `~/dev/`; every
  non-hidden, non-symlink item in `~/dev/` (except `dev_review/`) should have
  an entry.
- **`~/dev/.archive/NOTES.md`** — every item listed should exist in
  `~/dev/.archive/`; every item in `~/dev/.archive/` should be listed.

To check, list the actual directory contents and compare against the NOTES.md
entries. Report any discrepancies (missing entries or stale entries pointing to
items that no longer exist) and fix them before declaring the Finalize Phase
complete.
