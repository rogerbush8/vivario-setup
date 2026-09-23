# vivario-setup

Gets a laptop ready to run [vivo](https://github.com/vivario), then gets out of the
way.

It checks and installs the prerequisites vivo needs — cmux, uv, python — and
prepares a project directory. It runs *before* vivo exists, so it shares no code
with it: no Python, no packages, no dependencies beyond a shell and the tools it
is checking for.

```
$ ./vivario-setup
vivario-setup 0.1.0

VIVARIO INSTALL PLAN
--------------------------------------------------------------------------------
system
  os          26.0.1   ok     -           macos (arm64)
  homebrew             ok     -           /opt/homebrew
  network              ok     -

--------------------------------------------------------------------------------
prerequisites
  uv          0.9.7    ok     -           via homebrew (0.12.18 available)
  python      3.12.12  ok     -           uv-managed (~/.local/share/uv/python)
  cmux        0.64.22  ok     -           as a macOS app (0.64.25 available)

--------------------------------------------------------------------------------
vivo
  vivo                 ok     -           uv tool vivario-core, python 3.12.12

--------------------------------------------------------------------------------
project
  .vivario/            ok     -           ~/Work/Projects/ws-voice-agent-system
    project.toml       ok     -           created 2026-04-01

--------------------------------------------------------------------------------
summary
  Prerequisites:       ok     -           already installed
  Vivo:                ok     -           already installed
  Project:             ok     -           already initialized

  **Vivario is ready to run!**  To start:  % ./vivario-start
```

Before anything is installed it also prints **pre-install notes** -- situational,
not general. They appear only when they apply to what is about to happen on this
machine: that uv was installed by Homebrew and so must be used to upgrade it, that
a uv-managed interpreter is about to appear, that cmux updates itself from inside
the app. A machine with nothing to do prints none.

Two columns carry the state: **state** answers "is this fine?", and **action**
answers "what needs doing, or what was done". A clean run shows `-` in every
action column, so the rows that do need something stand out instead of every row
carrying similar-looking text -- which is how you see at a glance that nothing was
changed, rather than inferring it from the absence of an error.

Nothing is changed without showing you the plan and asking first.

## Running it

There is no install step. Extract it and run it where it landed:

```
tar xzf vivario-setup.tar.gz
./vivario-setup
```

That leaves exactly two entries — `vivario-setup` and `vivario-internal/` — so it
is safe to extract straight into a directory that already has your own files in
it, including the project you are about to set up. Everything it writes carries
the `vivario-setup` prefix; nothing generic like `README.md` or `VERSION` is placed
at the top level where it could overwrite yours.

## Commands

```
vivario-setup                      report, ask, then act
vivario-setup analyze              report only; changes nothing
vivario-setup install              same as bare, said explicitly
vivario-setup system               the machine: OS, Homebrew, network
vivario-setup prerequisite         check every prerequisite
vivario-setup prerequisite uv      check one
vivario-setup prerequisite uv --install
vivario-setup vivo                 the vivo CLI itself
vivario-setup project              is this directory inside a project?
```

Every command takes the same flags:

```
--verify      check only (default)
--install     install or upgrade as needed, after confirming
--dry-run     say what would happen, change nothing
--offline     skip lookups that need the network
--verbose     explain what each thing is and why it is needed
--debug       show what was run and what came back
-y, --yes     skip the confirmation prompt
-h, --help    help for that command
```

`--help` works at every level, and each command documents its own flags.

## Requirements

macOS 15 (Sequoia) or newer -- vivo is installed here too, as a single
uv tool holding the whole core package set, built against a uv-managed
interpreter. Every vivario package comes from git; none are published to PyPI.

Two reasons are known for that floor, and there are probably others. **cmux
requires macOS 14** -- it states so in its own update feed and installed bundle,
and cmux is why vivario needs macOS at all. **macOS began shipping `jq` in
`/usr/bin` with 15**, and several vivo hooks parse JSON with jq and quietly skip
that work when it is absent, so requiring 15 makes jq a given rather than a path
that silently degrades.

Other parts of vivario have not had their OS floors established, so 15 is the
highest *known* requirement rather than a tested boundary. Treat anything lower as
unsupported, not as verified.

When the OS is too old nothing else is even checked: updating macOS is the whole
job, so being told about six other things would only be noise.

## Two things it deliberately does not do

**It will not install cmux.** cmux is a macOS application bundle with no package
manager and no command-line installer, and it updates itself from inside the app.
A signed 225 MB disk image install is something its own updater already does
correctly, so this reports what it finds and tells you what to do rather than
reimplementing that badly.

**It will not upgrade something the wrong way.** How a tool is upgraded depends on
how it was installed — `uv self update` refuses outright on a Homebrew-installed
uv, for instance. So the install method is detected and the matching command
used. When the method cannot be determined, it says so instead of guessing;
guessing is how a machine ends up with two copies of a tool on its PATH.

## Working offline

Every check is correct with no network at all. Verdicts come from what is on the
machine plus a known minimum version, so nothing depends on being able to reach
anything. Network lookups only *enrich* the report — "and 0.64.25 is available" —
and when one is not possible the report says so rather than quietly implying
everything is current.

`--offline` skips the attempts entirely.

## Why bash 3.2

macOS ships `/bin/bash` 3.2.57, released in 2007, and always will: Apple will not
ship bash 4 or later because those are GPLv3. A tool whose job is to prepare a
machine before anything has been installed on it cannot require a newer bash —
that would mean requiring an install in order to run the installer.

So everything here targets 3.2. That is a real constraint, not a nominal one:
`declare -A` does not merely fail on 3.2, it silently degrades into an ordinary
array where every key collapses onto index 0, printing to stderr and then exiting
successfully with wrong data. See
[`vivario-internal/README.md`](vivario-internal/README.md) for what that
rules out and how to add a check.

## Building the tarball

```
./make-tarball.sh
```

Packages by naming what ships rather than excluding what does not, so nothing new
can leak in by accident.

## Tests

```
tests/run
```

Runs everything under `/bin/bash` explicitly rather than whatever `bash` resolves
to — the moment anyone installs a newer bash, `env bash` stops testing the floor
and starts passing things 3.2 would reject.
