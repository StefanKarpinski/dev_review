# dev_review

Scripts and Claude instructions for periodically cleaning up `~/dev`.

## How it works

The process has three phases, all driven by instructions in `CLAUDE.md` which
Claude Code reads automatically when invoked in `~/dev`.

### Investigate Phase

Claude runs `check_dirty.sh` to classify every item in `~/dev` as `git-clean`,
`git-dirty`, or `non-git`, then inspects each one and produces:

- `cleanup.sh` — idempotent `mv` script sorting items into `.delete/` or `.review/`
- `.delete/NOTES.md` — terse reason for each proposed deletion
- `.review/NOTES.md` — detailed context for each item needing human review
- `NOTES.md` — record of items being kept in place

### Review Phase

Claude presents each item in `.review/` interactively, one at a time:

```
**`dirname/`** — one-line summary
key details about dirty state, unpushed commits, etc.

archive / delete / keep / next / shell / edit / web ?
```

Choices: **archive** (move to `.archive/`), **delete** (move to `.delete/`),
**keep** (move back to `~/dev/`), **next** (skip for now), **shell** (open
iTerm2 tab in directory), **edit** (open in VS Code), **web** (open GitHub).

### Cleanup Phase

Claude verifies `.review/` is empty, prompts the user to `rm -rf .delete/`,
and checks that all `NOTES.md` files are consistent with actual directory
contents.

## Files

- **`CLAUDE.md`** — full instructions for Claude (all three phases)
- **`check_dirty.sh`** — classifies `~/dev` items as git-clean/git-dirty/non-git
