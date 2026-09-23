# Test helpers. Themselves written to bash 3.2.

T_PASS=0
T_FAIL=0

t_ok() {
    T_PASS=$((T_PASS + 1))
    printf '  ok    %s\n' "$1"
}

t_bad() {
    T_FAIL=$((T_FAIL + 1))
    printf '  FAIL  %s\n' "$1" >&2
}

# t_is LABEL GOT WANT
t_is() {
    if [ "$2" = "$3" ]; then
        t_ok "$1"
    else
        t_bad "$1 -- got '$2', want '$3'"
    fi
}

# t_rc LABEL WANT_RC CMD... -- assert exit status
t_rc() {
    local label=$1 want=$2
    shift 2
    local got=0
    "$@" >/dev/null 2>&1 || got=$?
    t_is "$label" "$got" "$want"
}

# t_contains LABEL HAYSTACK NEEDLE
t_contains() {
    case "$2" in
        *"$3"*) t_ok "$1" ;;
        *)      t_bad "$1 -- '$3' not found in output" ;;
    esac
}

# t_skip LABEL WHY -- neither pass nor fail. For an assertion that can only be
# made on a machine in a particular state; the alternative is a suite that fails
# for a legitimate host condition, which trains people to ignore it.
T_SKIP=0
t_skip() {
    T_SKIP=$((T_SKIP + 1))
    printf '  skip  %s -- %s\n' "$1" "$2"
}

t_summary() {
    if [ "$T_SKIP" -gt 0 ]; then
        printf '  %s passed, %s failed, %s skipped\n' "$T_PASS" "$T_FAIL" "$T_SKIP"
    else
        printf '  %s passed, %s failed\n' "$T_PASS" "$T_FAIL"
    fi
    [ "$T_FAIL" -eq 0 ]
}
