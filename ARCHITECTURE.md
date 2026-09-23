# Architecture

For someone changing the design, not someone running it. Run-time usage is in
[README.md](README.md); the rules for writing a check are in
[vivario-internal/README.md](vivario-internal/README.md), which ships with
the payload.

## What this is

A pre-vivario bootstrapper. It gets a laptop to the point where `vivo` can be
installed and run, then stops. It sits strictly *before* vivario, so none of that
codebase is available to it — not the config core, not the filespace layer, not
the click CLI it deliberately imitates.

Target is a laptop or dev machine. Other install targets are out of scope.

## The shape

```
vivario-setup                      the only entrypoint
vivario-internal/
  commands/
    _default                    what bare `vivario-setup` does
    analyze                     report; changes nothing
    install                     plan, ask, act
    prerequisite/
      _group                    group description for help
      uv                        one file owns all uv knowledge
      cmux
  lib/common.sh                 detection, comparison, reporting, confirmation
  install-sequence/             order, and nothing else
  VERSION
```

The dispatcher resolves a command by walking the argument list against
`commands/`: a name matching a directory descends into it, a name matching an
executable runs it with whatever arguments remain, and the first `-`-prefixed
token ends the walk. So **the filesystem is the command table** — which is also
why the dispatcher needs no hash map, and therefore never reaches for the one
bash 4 construct that fails silently on the floor.

## Invariants

Each of these has a concrete failure behind it. They are not preferences.

### bash 3.2 is the floor

macOS ships `/bin/bash` 3.2.57 and always will — Apple will not ship bash 4+
because those are GPLv3. Requiring a newer bash would mean requiring an install
in order to run the installer.

What makes this sharp is not the constructs that fail loudly but the two that
**fail silently with wrong answers and exit 0**: `declare -A` degrades into an
ordinary indexed array where every key collapses onto index 0, and `${a[@]@Q}`
returns unquoted output. A passing smoke test therefore does not prove 3.2
compatibility. The full list is in the internal README.

### Tests invoke `/bin/bash` explicitly, never `env bash`

The moment anyone runs `brew install bash`, `env bash` resolves to 5.x and the
floor stops being tested at all — silently, with everything still passing. The
shebang stays `#!/usr/bin/env bash` for portability (FreeBSD puts bash in
`/usr/local/bin`, NixOS has no `/bin/bash`), but verification must name the floor.

### Every top-level payload entry carries the `vivario-setup` prefix

The payload extracts as exactly two entries, directly into whatever directory the
user is in — which may already be their first project. An unprefixed `README.md`
or `VERSION` at the top level would **overwrite the user's own**. The prefix is
correctness, not style, and anything generic belongs inside
`vivario-internal/`.

### A network lookup never decides a verdict

Verdicts come from local state plus a hardcoded floor, so every check is correct
with no network at all. The network only *enriches* — "and 0.64.25 is available".
Two consequences: a broken network must never stall a verdict already computed
locally (hence short timeouts, and `analyze` probing once rather than each check
discovering it), and "could not check" must read differently from "nothing newer",
or an unreachable feed silently implies everything is current.

### One file owns one prerequisite, not one verb

Checking, the skip/upgrade/unchanged decision, and hint generation all need the
same detection. Splitting by verb (`verify/uv` plus `install/uv`) forces that into
a shared library which then grows a section per tool — the cohesion problem
inverted. It also makes it possible for verify and the post-install check to
drift, when they must be one implementation.

Actions are selected by flags, not a positional word, because a `-`-prefixed
token is the visible boundary where the command tree ends and a command's own
interface begins.

### Command names are never positional; order lives only in `install-sequence/`

A command invoked by `install` is still an ordinary command a person calls
directly, so it is named for what it is: `prerequisite uv`, never `10-uv`.
Ordering is a separate concern in a separate directory, where an entry `NN-<name>`
means "run `prerequisite/<name>` at this position". Anything with no entry runs
last, alphabetically, so a new command is never silently skipped.

An ordering manifest *inside* the command tree was rejected: it reintroduces the
parent edit the structure exists to eliminate.

### Adding a check requires no edit above it

One executable file in `commands/prerequisite/`. Group help is read from each
child's own `# description:` header, so there is no registry to update. This is
the property the directory-modelled tree exists to provide, and it is the first
thing a convenience shortcut would quietly cost.

### Every leaf runs standalone

Not only through the dispatcher. That is why a leaf locates `lib/common.sh` by
relative path rather than an inherited variable — a leaf run alone has no
dispatcher to inherit from, and a variable with a fallback lets the two paths
diverge silently.

The same reasoning is why environment detection is a function call rather than
exported state, while `--verbose` *is* inherited: if verbosity is missing the
default is correctly "off", but if detection were missing a leaf would behave
differently. One is a preference, the other is correctness.

### Upgrade uses the method the tool was installed with

`uv self update` refuses outright on a Homebrew-installed uv; `brew upgrade` is
meaningless for a standalone one. These act on *different installations*, so
trying one and falling back to the other is incoherent — that is how a machine
ends up with two copies of a tool on its PATH. Detect the method and use the
matching command; when the method is unknown, **fail and say so rather than
guessing**.

A choice exists only for a *fresh* install: Homebrew when it is present, the
tool's own installer otherwise. Homebrew is never installed for the user — it is
a heavy prerequisite for a tool whose purpose is to have almost none.

### Nothing mutates without showing the plan and asking

Bare invocation and `install` both report, then ask. `--yes` is how a script
proceeds unattended; **no terminal means decline, never assume**.

The plan is the dry run, not a separate computation — the same code with mutation
suppressed. A plan derived from separate logic would drift from what install
actually does, and that drift would be invisible.

### The core package list is embedded, not read

A bootstrap cannot parse `[tool.vivo] required_packages` out of a
`pyproject.toml`, because on a clean install no such file exists yet — a
bootstrap that read one would only work where it was already unnecessary. So the
list is carried here, and this tree is the authority at bootstrap time.

Because that copy is necessary rather than accidental, the protection is a **sync
check**, not de-duplication. This has already caused one outage: `vivo` and
`vivo-index` went missing when a duplicated list was not updated after a package
split. Where a `pyproject.toml` *is* reachable — the upgrade case — the tree can
cross-check and warn.

## Deliberate non-goals

**Installing cmux.** It is a macOS `.app` with no package manager and no CLI
installer, updating itself through Sparkle. Installing it means downloading a
signed 225 MB disk image, verifying an EdDSA signature, mounting and copying.
Sparkle already does that correctly, and doing it a second time worse is not an
improvement. Report and advise.

**A run directory or resume state.** Every operation is idempotent, so re-running
is safe and cheap, and "you were mid-install, continue?" is a question whose
answer is always "just re-run". It earns its place only for a step that is
expensive *and* not resumable by the tool doing the work — and note that cloning,
the obvious candidate, resumes better under git than under anything written here.

**A menu.** While the choice is binary, one question is enough. Navigation earns
its place if per-item choices appear.

## Where this stops

At a suggestion to run `vivo-start`. Starting services and launching the
orchestrator is vivo's concern, and this tool holds no runtime responsibility.
