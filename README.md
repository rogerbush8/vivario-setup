# vivario-setup

Gets a laptop ready to run [vivo](https://github.com/vivario), then gets out of the
way.

It checks and installs the prerequisites vivo needs — cmux, uv, python — and
prepares a project directory. It runs *before* vivo exists, so it shares no code
with it: no Python, no packages, no dependencies beyond a shell and the tools it
is checking for.

```
$ ./vivo-setup
vivo-setup 0.1.0

system
  os                     macos     26.0.1 (arm64)
  homebrew               ok        /opt/homebrew
  network                ok

prerequisites
  cmux        0.64.22    ok        app-bundle; 0.64.25 available
                                   update in-app when convenient (Sparkle)
  uv          0.9.7      ok        released 2025-10-30, via homebrew

everything is already in place. Nothing to do.
```

Nothing is changed without showing you the plan and asking first.

## Running it

There is no install step. Extract it and run it where it landed:

```
tar xzf vivo-setup.tar.gz
./vivo-setup
```

That leaves exactly two entries — `vivo-setup` and `vivo-setup-internal/` — so it
is safe to extract straight into a directory that already has your own files in
it, including the project you are about to set up. Everything it writes carries
the `vivo-setup` prefix; nothing generic like `README.md` or `VERSION` is placed
at the top level where it could overwrite yours.

## Commands

```
vivo-setup                      report, ask, then act
vivo-setup analyze              report only; changes nothing
vivo-setup install              same as bare, said explicitly
vivo-setup prerequisite         check everything
vivo-setup prerequisite uv      check one thing
vivo-setup prerequisite uv --install
```

Every command takes the same flags:

```
--verify      check only (default)
--install     install or upgrade as needed, after confirming
--dry-run     say what would happen, change nothing
--offline     skip lookups that need the network
--verbose     more detail
-y, --yes     skip the confirmation prompt
-h, --help    help for that command
```

`--help` works at every level, and each command documents its own flags.

## Two things it deliberately does not do

**It will not install cmux.** cmux is a macOS application bundle with no package
manager and no command-line installer, and it updates itself through Sparkle. A
signed 225 MB disk image install is something Sparkle already does correctly, so
this reports what it finds and tells you what to do rather than reimplementing
that badly.

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
[`vivo-setup-internal/README.md`](vivo-setup-internal/README.md) for what that
rules out and how to add a check.

## Building the tarball

```
./make-tarball.sh
```

Packages by naming what ships rather than excluding what does not, so nothing new
can leak in by accident.

## Tests

```
t/run
```

Runs everything under `/bin/bash` explicitly rather than whatever `bash` resolves
to — the moment anyone installs a newer bash, `env bash` stops testing the floor
and starts passing things 3.2 would reject.
