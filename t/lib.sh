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

t_summary() {
    printf '  %s passed, %s failed\n' "$T_PASS" "$T_FAIL"
    [ "$T_FAIL" -eq 0 ]
}
