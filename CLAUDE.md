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

# --- Items proposed for deletion ---
mv "item1" .delete/
mv "item2" .delete/
# ... etc

# --- Items that need review ---
mv "item3" .review/
mv "item4" .review/
# ... etc
```

Rules for the script:
- Only `mv` commands (plus mkdir and cd at the top)
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

### Summary of Investigate Phase outputs

Running the Investigate Phase should produce exactly three artifacts:

1. `~/dev/cleanup.sh` — the move script
2. `~/dev/.delete/NOTES.md` — terse deletion reasons
3. `~/dev/.review/NOTES.md` — detailed review context

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

delete / open / archive / skip ?
```

Only treat the response as a menu choice if it is exactly one of the words
`delete`, `open`, `archive`, or `skip` (case-insensitive, possibly abbreviated
to a single letter only if it's the entire message). Anything else is a
freeform question or instruction — handle it normally, then re-present the
choice menu afterward.

Handle the user's choice using `dev_review/review_action.sh`:

- **delete:** Move to `~/dev/.delete/` and log the decision.
  ```
  dev_review/review_action.sh delete dirname "approved by user"
  ```

- **open:** Open in VS Code and wait for it to close, then ask again.
  ```
  code -w ~/dev/.review/dirname
  ```
  After the editor closes, re-present the same item and ask for a decision
  (delete / archive / skip). Do not offer "open" again.

- **archive:** Move to `~/dev/.archive/` for long-term storage.
  ```
  dev_review/review_action.sh archive dirname "archived by user"
  ```

- **skip:** Leave it in `.review/` and move on. No action needed.

The user may also:
- Ask questions about the item — investigate on the fly (read files, check git
  log, etc.) and then re-present the choice menu.
- Give a freeform instruction (e.g. "push it to GitHub first") — carry it out,
  then re-present the choice menu.

### After all items

Report a summary: how many deleted, archived, skipped. Note any items still
remaining in `.review/` for future sessions.
