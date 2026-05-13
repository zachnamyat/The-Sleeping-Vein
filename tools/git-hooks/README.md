# Git hooks (ticket 0.19)

These hooks gate commits on basic correctness. Install once per clone:

```sh
git config core.hooksPath tools/git-hooks
```

That points git at this directory instead of `.git/hooks/`. The hooks run on every commit.

## `pre-commit`

Runs `godot --headless --check-only --script <file>` against every staged `.gd` file.
Fails the commit on any GDScript parse error. Silent on success.

Bypass once with `git commit --no-verify` if needed.

Requires `godot` on `PATH` (or `~/bin/godot{,.exe}`). On Windows under PowerShell, the
hook still runs through Git Bash, which is what `git` ships with.
