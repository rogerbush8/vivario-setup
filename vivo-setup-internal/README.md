# vivo-setup-internal

The machinery. Nothing here is meant to be run by hand except the command leaves
under `commands/`, each of which works on its own as well as through the
dispatcher.

## Why the name is prefixed

The payload extracts as exactly two entries -- `vivo-setup` and
`vivo-setup-internal/` -- directly into whatever directory the user is in, which
may already be their first project. Every top-level entry therefore carries the
`vivo-setup` prefix so nothing can collide with the user's own files. A generic
`README.md` or `VERSION` at the top level would overwrite theirs.

**That prefix is a correctness rule, not a style choice.** Any future top-level
payload entry must carry it.

## Layout

    commands/           the command tree: directories are groups, files are commands
      verify/             -> vivo-setup verify
        uv                -> vivo-setup verify uv
    lib/
      common.sh         sourced by the dispatcher and by leaves run standalone
    install-sequence/   install ordering, kept out of the command tree
    VERSION

## bash 3.2 is the floor

macOS ships `/bin/bash` 3.2.57 (2007) and always will -- Apple will not ship
bash 4+ because those are GPLv3. A tool whose job is to prepare a machine before
anything is installed on it cannot require a newer bash, so everything here is
written to 3.2.

Do not use: `declare -A`, `mapfile`/`readarray`, `${v,,}`/`${v^^}`, `globstar`,
`${a[-1]}`, `declare -n`, `wait -n`, `coproc`, `&>>`, `EPOCHSECONDS`,
`${a[@]@Q}`.

Two of those fail **silently with wrong answers** rather than erroring, which is
why they matter more than the rest. `declare -A` degrades into a normal indexed
array where every key collapses to index 0, printing a usage message to stderr
and then exiting 0 with wrong data. `${a[@]@Q}` returns unquoted output and also
exits 0. A passing smoke test does not prove 3.2 compatibility.

Also 3.2-specific:

- Expanding an empty array under `set -u` is a hard error (fixed in 4.4). Write
  every array expansion as `${a[@]+"${a[@]}"}`.
- Never quote the right-hand side of `[[ =~ ]]`; quoting makes the pattern a
  literal and the match silently fails.
- `sort -V`, `readlink -f`, `grep -P`, `sed -i` without an argument, `date -d`
  and `stat -c` are all unavailable or differently spelled on a stock macOS. The
  userland is BSD, and GNU coreutils cannot be assumed either.

Verify against the real floor with `/bin/bash`, explicitly. Do not rely on
`env bash` for that check: the moment anyone runs `brew install bash`, `env bash`
resolves to 5.x and the floor stops being tested at all.

## Writing a command

Four lines of preamble, then the check:

    #!/usr/bin/env bash
    # description: what this checks, in one line
    set -euo pipefail
    . "$(dirname "$0")/../../lib/common.sh"

The `# description:` line is not a comment for readers -- the dispatcher reads it
to build `--help` for the group. The relative path to `common.sh` resolves
whether the leaf is run by the dispatcher, by absolute path, from its own
directory, or relatively from the payload root.

End in exactly one of `vs_pass`, `vs_skip` or `vs_fail`, so output reads alike
and the dispatcher can aggregate on exit status. `vs_fail` takes an optional
second argument: the command that would fix it.
