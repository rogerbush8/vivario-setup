# vivario-setup shared helpers.
#
# Sourced by the dispatcher and by any leaf run on its own. Targets bash 3.2 --
# the version Apple ships and the floor this whole tree is written to. No
# associative arrays, no mapfile, no ${v,,}: see vivario-internal/README.md.

# have_cmd NAME -- true if NAME is runnable.
have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

# vs_vercmp A B -- 0 if equal, 1 if A > B, 2 if A < B.
#
# Pure builtins on purpose: `sort -V` is a GNU extension that older macOS
# lacks, and shelling out would add a dependency this tree is meant not to
# have. Compares dot-separated fields numerically, so 3.10 > 3.9 (which plain
# string comparison gets backwards). A field's non-numeric suffix is dropped,
# so 1.2.0rc1 compares as 1.2.0.
vs_vercmp() {
    if [ "$1" = "$2" ]; then
        return 0
    fi
    local IFS=. i a b
    local -a A B
    A=($1)
    B=($2)
    i=0
    while [ "$i" -lt "${#A[@]}" ] || [ "$i" -lt "${#B[@]}" ]; do
        a=${A[$i]:-0}
        b=${B[$i]:-0}
        a=${a%%[^0-9]*}
        b=${b%%[^0-9]*}
        # 10# forces base ten, so a field like 08 is not read as bad octal.
        a=$((10#${a:-0}))
        b=$((10#${b:-0}))
        if [ "$a" -gt "$b" ]; then
            return 1
        fi
        if [ "$a" -lt "$b" ]; then
            return 2
        fi
        i=$((i + 1))
    done
    return 0
}

# vs_vercmp_lt A B -- true if A is older than B.
vs_vercmp_lt() {
    local rc=0
    vs_vercmp "$1" "$2" || rc=$?
    [ "$rc" -eq 2 ]
}

# Result reporting. Every leaf ends in exactly one of these so output reads
# alike and the dispatcher can aggregate on exit status alone.

vs_pass() {
    printf '  %-6s %s\n' "ok" "$1"
}

vs_skip() {
    printf '  %-6s %s\n' "skip" "$1"
}

# vs_fail MESSAGE [HINT] -- report and exit non-zero. HINT should say what to
# run to fix it.
vs_fail() {
    printf '  %-6s %s\n' "FAIL" "$1" >&2
    if [ $# -gt 1 ]; then
        printf '  %-6s %s\n' "" "$2" >&2
    fi
    exit 1
}

# ---------------------------------------------------------------------------
# Environment detection
#
# Deliberately functions rather than inherited environment: a leaf run on its
# own has no dispatcher to inherit from, so anything passed down would need a
# fallback here anyway -- and then the two paths could silently disagree. These
# are cheap enough to just call.
# ---------------------------------------------------------------------------

# vs_os -- macos | linux | unknown
vs_os() {
    case "$(uname -s)" in
        Darwin) printf 'macos\n' ;;
        Linux)  printf 'linux\n' ;;
        *)      printf 'unknown\n' ;;
    esac
}

vs_os_release() {
    if [ "$(vs_os)" = macos ]; then
        sw_vers -productVersion 2>/dev/null || printf 'unknown\n'
    else
        uname -r 2>/dev/null || printf 'unknown\n'
    fi
}

vs_arch() {
    uname -m 2>/dev/null || printf 'unknown\n'
}

# vs_brew_prefix -- Homebrew's prefix, or nothing if brew is absent.
vs_brew_prefix() {
    if have_cmd brew; then
        brew --prefix 2>/dev/null
    fi
}

# vs_install_method PATH -- how the thing at PATH got there.
#
# homebrew | standalone | app-bundle | pyenv | unknown. This drives which
# upgrade command is correct, and getting it wrong sends the user down a dead
# end: `uv self update` refuses outright on a Homebrew-installed uv.
vs_install_method() {
    local p=$1
    case "$p" in
        /opt/homebrew/*|/usr/local/Cellar/*|/home/linuxbrew/*) printf 'homebrew\n'   ;;
        "$HOME"/.pyenv/*)                                      printf 'pyenv\n'      ;;
        /Applications/*)                                       printf 'app-bundle\n' ;;
        "$HOME"/.local/*|"$HOME"/.cargo/*)                     printf 'standalone\n' ;;
        *)                                                     printf 'unknown\n'    ;;
    esac
}

# vs_resolve PATH -- follow symlinks one hop at a time.
#
# `readlink -f` is unavailable on older macOS and on true BSD, so it cannot be
# used at this baseline.
vs_resolve() {
    local p=$1 n=0
    while [ -L "$p" ] && [ "$n" -lt 16 ]; do
        local t
        t=$(readlink "$p")
        case "$t" in
            /*) p=$t ;;
            *)  p=$(dirname "$p")/$t ;;
        esac
        n=$((n + 1))
    done
    local dir base
    dir=$(dirname "$p")
    base=$(basename "$p")
    if [ -d "$dir" ]; then
        dir=$(cd "$dir" 2>/dev/null && pwd) || dir=$(dirname "$p")
    fi
    case "$dir" in
        /) printf '/%s\n' "$base" ;;
        *) printf '%s/%s\n' "$dir" "$base" ;;
    esac
}

# ---------------------------------------------------------------------------
# Reporting
#
# One formatter, so every leaf's output lines up without any leaf knowing about
# any other. Columns: name, version, status, detail.
# ---------------------------------------------------------------------------

# Exit statuses, so a caller learns what a check concluded without parsing its
# output. Keeps the plan and the action reading from the same channel.
VS_RC_OK=0          # nothing to do
VS_RC_BLOCKED=1     # needs a human; we cannot do it
VS_RC_WORK=10       # work is pending and we can do it

VS_STATUS_OK=ok
VS_STATUS_INSTALL=install
VS_STATUS_UPGRADE=upgrade
VS_STATUS_MANUAL=manual
VS_STATUS_MISSING=missing

# vs_report NAME VERSION STATUS [DETAIL]
vs_report() {
    printf '  %-11s %-10s %-9s %s\n' "$1" "${2:--}" "$3" "${4:-}"
}

# vs_info NAME STATUS [DETAIL] -- a row for something that has no version,
# aligned with vs_report so the two read as one table.
vs_info() {
    printf '  %-11s %-10s %-9s %s\n' "$1" "" "$2" "${3:-}"
}

# vs_note TEXT -- an indented continuation line under a report row.
vs_note() {
    printf '  %-11s %-10s %-9s %s\n' "" "" "" "$1"
}

vs_heading() {
    printf '\n%s\n' "$1"
}

# vs_about -- indent a prose block read from stdin, for --verbose.
#
# Explains what a thing IS and why vivario wants it, which is different from the
# diagnostic detail vs_debug carries. Both belong to --verbose: someone meeting
# this for the first time wants the former, someone debugging wants the latter.
vs_about() {
    if [ -z "${VS_VERBOSE:-}" ]; then
        cat >/dev/null
        return 0
    fi
    sed 's/^./      &/'
    printf '\n'
}

# vs_debug TEXT -- only when --verbose asked for it.
vs_debug() {
    if [ -n "${VS_VERBOSE:-}" ]; then
        printf '  [debug] %s\n' "$1" >&2
    fi
}

# vs_confirm PROMPT -- true if the user agrees.
#
# Refuses rather than guessing when there is no terminal to ask: a caller that
# wants to proceed unattended passes --yes.
vs_confirm() {
    if [ -n "${VS_ASSUME_YES:-}" ]; then
        return 0
    fi
    if [ ! -t 0 ]; then
        return 1
    fi
    local reply=""
    printf '\n%s [y/N] ' "$1"
    read -r reply || return 1
    case "$reply" in
        y|Y|yes|YES) return 0 ;;
    esac
    return 1
}

# ---------------------------------------------------------------------------
# Argument handling
#
# Shared so every leaf accepts exactly the same flags. That is not only to save
# duplication: a group forwards its flags to every child, so a flag one leaf
# did not understand would fail the whole group.
# ---------------------------------------------------------------------------

# vs_parse_args "$@" -- sets VS_ACTION (verify|install|help), VS_DRY_RUN,
# VS_VERBOSE, VS_ASSUME_YES. Returns 2 on an unknown option.
vs_parse_args() {
    VS_ACTION=verify
    VS_DRY_RUN=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --verify)    VS_ACTION=verify ;;
            --install)   VS_ACTION=install ;;
            -h|--help)   VS_ACTION=help ;;
            --dry-run)   VS_DRY_RUN=1 ;;
            --offline)   VS_OFFLINE=1 ;;
            --verbose)   VS_VERBOSE=1 ;;
            -y|--yes)    VS_ASSUME_YES=1 ;;
            *)
                printf '%s: unknown option: %s\n' "${0##*/}" "$1" >&2
                return 2
                ;;
        esac
        shift
    done
    return 0
}

# vs_flag_help -- the shared flag list, for a leaf's own --help.
vs_flag_help() {
    printf '  --verify      check only (default)\n'
    printf '  --install     install or upgrade as needed, after confirming\n'
    printf '  --dry-run     say what would happen, change nothing\n'
    printf '  --offline     skip lookups that need the network\n'
    printf '  --verbose     more detail\n'
    printf '  -y, --yes     skip the confirmation prompt\n'
    printf '  -h, --help    this message\n'
}

# ---------------------------------------------------------------------------
# Network
#
# The invariant: a network lookup never decides a verdict, it only enriches the
# report. Verdicts come from local state plus a hardcoded floor, so a check is
# always correct offline -- the network can only add "and here is what the
# newest release is". Anything unreachable therefore reads as unknown, never as
# a failure.
# ---------------------------------------------------------------------------

# vs_fetch URL -- print the body; signal how it went through EXIT STATUS.
#
#   0  fetched
#   2  offline (asked not to try)
#   3  unreachable (no curl, timeout, empty, or error)
#
# Status rather than a variable because callers write `body=$(vs_fetch URL)`,
# and a command substitution runs in a subshell -- any variable set inside would
# be discarded on return. The distinction has to survive, because "could not
# check" must never read the same as "nothing newer".
#
# Five seconds: this is decoration. A present-but-broken network is worse than an
# absent one, and neither should stall a verdict already computed locally.
vs_fetch() {
    if [ -n "${VS_OFFLINE:-}" ]; then
        vs_debug "offline: skipping $1"
        return 2
    fi
    if ! have_cmd curl; then
        vs_debug "no curl: cannot fetch $1"
        return 3
    fi
    vs_debug "fetching $1"
    local body=""
    body=$(curl -sL --max-time 5 "$1" 2>/dev/null) || body=""
    if [ -z "$body" ]; then
        vs_debug "unreachable: $1"
        return 3
    fi
    printf '%s\n' "$body"
    return 0
}

# vs_fetch_state RC -- the name for what vs_fetch returned.
vs_fetch_state() {
    case "$1" in
        0) printf 'ok\n' ;;
        2) printf 'offline\n' ;;
        *) printf 'unreachable\n' ;;
    esac
}

# vs_probe_network -- is the network usable at all? 0 yes, 2 offline, 3 no.
#
# Done ONCE by analyze and reported to the user, rather than each check
# discovering it separately: one 3-second answer instead of N timeouts, and the
# user is told plainly why enrichment is missing instead of inferring it from
# several rows saying "unknown".
VS_PROBE_URL=https://github.com
VS_PROBE_TIMEOUT=3

vs_probe_network() {
    if [ -n "${VS_OFFLINE:-}" ]; then
        return 2
    fi
    if ! have_cmd curl; then
        return 3
    fi
    if curl -sI --max-time "$VS_PROBE_TIMEOUT" "$VS_PROBE_URL" >/dev/null 2>&1; then
        return 0
    fi
    return 3
}

# vs_probe_description -- what the probe actually does, for --verbose. A report
# that says "ok" without saying what was tested is not checkable.
vs_probe_description() {
    printf 'curl -sI %s, %ss timeout\n' "$VS_PROBE_URL" "$VS_PROBE_TIMEOUT"
}
