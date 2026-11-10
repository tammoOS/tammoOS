#!/usr/bin/env bash
#
# Smoke tests for tammo-power-saver.  No root privileges and no real
# power-profiles-daemon are required: a fake powerprofilesctl is placed in PATH.
#
# The bash -c snippets intentionally use single quotes so that the test command
# expands variables at runtime rather than in the parent shell.
# shellcheck disable=SC2016

set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/tammo-power-saver-tests.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

TOTAL=0
FAIL=0

pass() { TOTAL=$((TOTAL + 1)); printf 'ok %d - %s\n' "$TOTAL" "$1"; }
fail() { TOTAL=$((TOTAL + 1)); FAIL=$((FAIL + 1)); printf 'not ok %d - %s\n' "$TOTAL" "$1" >&2; }
check() {
    local description=$1
    shift
    if "$@"; then pass "$description"; else fail "$description"; fi
}

export TAMMO_TEST_STATE="$WORK/state"
printf 'balanced\n' > "$TAMMO_TEST_STATE"

mkdir -p "$WORK/bin"
cat > "$WORK/bin/powerprofilesctl" <<'FAKE'
#!/usr/bin/env bash
set -u
state=${TAMMO_TEST_STATE:?}
case "${1:-}" in
    get)
        cat "$state"
        ;;
    version)
        echo "0.21-test"
        ;;
    set)
        if [ "${TAMMO_TEST_FAIL:-0}" = "1" ]; then
            echo "simulated power driver error" >&2
            exit 1
        fi
        case "${2:-}" in
            balanced|power-saver|performance) printf '%s\n' "$2" > "$state" ;;
            *) echo "Unknown profile" >&2; exit 1 ;;
        esac
        ;;
    list)
        printf '  performance:\n    CpuDriver:\tfake\n\n'
        printf '%s balanced:\n    CpuDriver:\tfake\n\n' "$([ "$(cat "$state")" = balanced ] && printf '*' || printf ' ')"
        printf '%s power-saver:\n    CpuDriver:\tfake\n' "$([ "$(cat "$state")" = power-saver ] && printf '*' || printf ' ')"
        ;;
    *)
        exit 1
        ;;
esac
FAKE
chmod +x "$WORK/bin/powerprofilesctl"

cat > "$WORK/bin/zenity" <<'FAKE'
#!/usr/bin/env bash
set -u
if [ "${1:-}" = "--version" ]; then
    echo "3.44.0"
    exit 0
fi
if [ "${1:-}" = "--error" ]; then
    if [ -n "${TAMMO_TEST_LOG:-}" ]; then
        printf '%s\n' "$*" >> "$TAMMO_TEST_LOG"
    fi
    exit 0
fi
printf 'Power Saver|power-saver\n'
FAKE
chmod +x "$WORK/bin/zenity"

export PATH="$WORK/bin:$PATH"

# Shell syntax checks.
check "bin/tammo-power-saver has valid bash syntax" bash -n "$ROOT/bin/tammo-power-saver"
check "install.sh has valid bash syntax" bash -n "$ROOT/install.sh"
check "uninstall.sh has valid bash syntax" bash -n "$ROOT/uninstall.sh"
check "diagnose.sh has valid bash syntax" bash -n "$ROOT/diagnose.sh"

# Fake backend behaviour.
check "get returns the initial profile" \
    test "$("$ROOT/bin/tammo-power-saver" get | tail -n 1)" = "balanced"

check "list shows three profiles" \
    test "$("$ROOT/bin/tammo-power-saver" list | wc -l)" -eq 3

check "set power-saver changes the state" \
    bash -c '"$1" set power-saver >/dev/null && test "$(cat "$TAMMO_TEST_STATE")" = power-saver' _ "$ROOT/bin/tammo-power-saver"

check "status includes the current mode" \
    bash -c '"$1" status | grep -q "Power Saver"' _ "$ROOT/bin/tammo-power-saver"

check "toggle returns to balanced" \
    bash -c '"$1" toggle >/dev/null && test "$(cat "$TAMMO_TEST_STATE")" = balanced' _ "$ROOT/bin/tammo-power-saver"

check "toggle returns to power-saver" \
    bash -c '"$1" toggle >/dev/null && test "$(cat "$TAMMO_TEST_STATE")" = power-saver' _ "$ROOT/bin/tammo-power-saver"

check "invalid profile is rejected" \
    bash -c '! "$1" set turbo >/dev/null 2>&1 && test "$(cat "$TAMMO_TEST_STATE")" = power-saver' _ "$ROOT/bin/tammo-power-saver"

check "backend failure is reported" \
    bash -c '! TAMMO_TEST_FAIL=1 "$1" set power-saver >/dev/null 2>&1' _ "$ROOT/bin/tammo-power-saver"

check "backend failure leaves the profile unchanged" \
    bash -c 'TAMMO_TEST_FAIL=1 "$1" set balanced >/dev/null 2>&1 || true; test "$(cat "$TAMMO_TEST_STATE")" = power-saver' _ "$ROOT/bin/tammo-power-saver"

check "doctor prints backend details" \
    bash -c '"$1" doctor | grep -q "PPD binary"' _ "$ROOT/bin/tammo-power-saver"

printf 'balanced\n' > "$TAMMO_TEST_STATE"
check "gui applies the selected profile" \
    bash -c 'DISPLAY=:99 "$1" gui >/dev/null 2>&1 && test "$(cat "$TAMMO_TEST_STATE")" = power-saver' _ "$ROOT/bin/tammo-power-saver"

: > "$WORK/zenity.log"
check "gui shows an error dialog when the backend fails" \
    bash -c 'TAMMO_TEST_FAIL=1 TAMMO_TEST_LOG="$1" DISPLAY=:99 "$2" gui >/dev/null 2>&1 || true; grep -q -- "--error" "$1"' _ "$WORK/zenity.log" "$ROOT/bin/tammo-power-saver"

check "gui without a display fails clearly" \
    bash -c '! env -u DISPLAY -u WAYLAND_DISPLAY "$1" gui </dev/null >/dev/null 2>&1' _ "$ROOT/bin/tammo-power-saver"

check "help exits successfully" \
    bash -c '"$1" --help >/dev/null' _ "$ROOT/bin/tammo-power-saver"

check "unknown command fails" \
    bash -c '! "$1" nonsense >/dev/null 2>&1' _ "$ROOT/bin/tammo-power-saver"

# Installer/uninstaller with DESTDIR (no root, no system changes).
DEST="$WORK/dest"
check "installer succeeds with DESTDIR" \
    bash -c 'env DESTDIR="$1" PREFIX=/usr/local bash "$2" >/dev/null' _ "$DEST" "$ROOT/install.sh"

check "installer adds the CLI" \
    test -x "$DEST/usr/local/bin/tammo-power-saver"

check "installer adds the Power Mode desktop entry" \
    test -f "$DEST/usr/local/share/applications/tammo-power-saver.desktop"

check "desktop entry points at the installed binary" \
    grep -q '^Exec=/usr/local/bin/tammo-power-saver gui$' \
        "$DEST/usr/local/share/applications/tammo-power-saver.desktop"

check "desktop entry points at the installed toggle" \
    grep -q '^Exec=/usr/local/bin/tammo-power-saver toggle$' \
        "$DEST/usr/local/share/applications/tammo-power-saver-toggle.desktop"

check "uninstaller succeeds with DESTDIR" \
    bash -c 'env DESTDIR="$1" PREFIX=/usr/local bash "$2" >/dev/null' _ "$DEST" "$ROOT/uninstall.sh"

check "uninstaller removes the CLI" \
    test ! -e "$DEST/usr/local/bin/tammo-power-saver"

check "uninstaller removes the desktop entries" \
    bash -c 'test ! -e "$1/usr/local/share/applications/tammo-power-saver.desktop" && test ! -e "$1/usr/local/share/applications/tammo-power-saver-toggle.desktop"' _ "$DEST"

printf '\n%d passed, %d failed\n' "$((TOTAL - FAIL))" "$FAIL"
[ "$FAIL" -eq 0 ]
