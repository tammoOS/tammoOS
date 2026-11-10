#!/usr/bin/env bash
#
# Install the Zorin OS-style Power Saver switcher on tammoOS.
#
#   sudo ./install.sh
#
# Optional environment variables (mainly for packaging/tests):
#   PREFIX=/usr/local
#   DESTDIR=/tmp/package-root

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PREFIX=${PREFIX:-/usr/local}
DESTDIR=${DESTDIR:-}
BINDIR="$PREFIX/bin"
APPDIR="$PREFIX/share/applications"

say()  { printf '%s\n' "$*"; }
warn() { printf 'Warning: %s\n' "$*" >&2; }
die()  { printf 'Error: %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<EOF
tammoOS Power Saver installer

Usage:
  sudo ./install.sh

Options:
  -h, --help    Show this help

Environment:
  PREFIX        Install prefix (default: /usr/local)
  DESTDIR       Package staging directory (for tests/packaging)
EOF
}

apt_get() {
    DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=120 "$@"
}

has_legacy_backend() {
    compgen -G '/sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_governor' >/dev/null 2>&1
}

install_backend() {
    if command -v powerprofilesctl >/dev/null 2>&1; then
        say "power-profiles-daemon is already installed."
    else
        case "${VERSION_CODENAME:-}" in
            bionic)
                warn "tammoOS 1.x uses Ubuntu 18.04, which does not provide power-profiles-daemon."
                warn "The legacy CPU-governor fallback will be used instead."
                return 0
                ;;
        esac

        if ! command -v apt-get >/dev/null 2>&1; then
            warn "apt-get was not found. Install power-profiles-daemon manually."
            return 0
        fi

        say "Installing power-profiles-daemon (the backend used by Zorin OS)..."
        if ! apt_get install -y power-profiles-daemon; then
            warn "The first install attempt failed. Refreshing package lists and retrying..."
            if apt_get update; then
                apt_get install -y power-profiles-daemon \
                    || warn "Could not install power-profiles-daemon."
            else
                warn "Could not refresh the package lists."
            fi
        fi
    fi

    if command -v systemctl >/dev/null 2>&1; then
        systemctl daemon-reload >/dev/null 2>&1 || true
        if ! systemctl enable --now power-profiles-daemon.service 2>/dev/null; then
            warn "Could not start power-profiles-daemon."
            warn "Try: sudo systemctl enable --now power-profiles-daemon"
        fi
    fi
}

install_gui_helpers() {
    local missing=()

    if ! command -v zenity >/dev/null 2>&1; then
        missing+=(zenity)
    fi
    if ! command -v notify-send >/dev/null 2>&1; then
        missing+=(libnotify-bin)
    fi

    [ "${#missing[@]}" -gt 0 ] || return 0

    if ! command -v apt-get >/dev/null 2>&1; then
        warn "Install ${missing[*]} manually for the graphical switcher."
        return 0
    fi

    say "Installing optional GUI helpers: ${missing[*]}"
    apt_get install -y "${missing[@]}" \
        || warn "Could not install ${missing[*]}; the terminal menu still works."
}

warn_about_tlp() {
    command -v systemctl >/dev/null 2>&1 || return 0
    if systemctl is-active --quiet tlp.service 2>/dev/null; then
        warn "TLP is running and can conflict with power-profiles-daemon."
        warn "If profiles do not change, run: sudo systemctl disable --now tlp"
    fi
}

report_backend() {
    local backend="none" current=""

    if command -v powerprofilesctl >/dev/null 2>&1; then
        current=$(powerprofilesctl get 2>/dev/null || true)
        if [ -n "$current" ]; then
            backend="power-profiles-daemon (current: $current)"
        elif has_legacy_backend; then
            backend="power-profiles-daemon not responding; legacy CPU governor available"
        else
            backend="power-profiles-daemon installed but not responding"
        fi
    elif has_legacy_backend; then
        backend="legacy CPU governor"
    fi

    say "Power backend: $backend"

    if [ "$backend" = "none" ]; then
        warn "The switcher files were installed, but no working power backend was found."
        warn "Run 'tammo-power-saver doctor' for diagnostics."
        return 1
    fi

    if [ "$backend" = "power-profiles-daemon installed but not responding" ]; then
        warn "The power-profiles-daemon service is not responding."
        warn "Run 'tammo-power-saver doctor' and try: sudo systemctl restart power-profiles-daemon"
        return 1
    fi

    return 0
}

[ -f "$SCRIPT_DIR/bin/tammo-power-saver" ] || die "bin/tammo-power-saver is missing."
[ -d "$SCRIPT_DIR/share/applications" ] || die "share/applications is missing."

case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
    "")
        ;;
    *)
        die "Unknown option '$1'. Run '$0 --help'."
        ;;
esac

if [ -z "$DESTDIR" ] && [ "$(id -u)" -ne 0 ]; then
    die "Please run the installer with sudo: sudo $0"
fi

if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
fi

say "Installing tammoOS Power Saver..."
install -d "$DESTDIR$BINDIR" "$DESTDIR$APPDIR"
install -m 0755 "$SCRIPT_DIR/bin/tammo-power-saver" "$DESTDIR$BINDIR/tammo-power-saver"

for template in "$SCRIPT_DIR"/share/applications/*.desktop; do
    [ -e "$template" ] || continue
    name=$(basename "$template")
    sed "s|@BINDIR@|$BINDIR|g" "$template" > "$DESTDIR$APPDIR/$name"
    chmod 0644 "$DESTDIR$APPDIR/$name"
done

if [ -z "$DESTDIR" ]; then
    install_backend
    install_gui_helpers
    warn_about_tlp

    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$APPDIR" >/dev/null 2>&1 || true
    fi
fi

say ""
say "tammoOS Power Saver is installed."
say ""
say "Open \"Power Mode\" from the application menu, or use:"
say "  tammo-power-saver gui              # graphical switcher"
say "  tammo-power-saver menu             # terminal menu"
say "  tammo-power-saver set power-saver  # one-shot command"
say "  tammo-power-saver toggle           # Power Saver <-> Balanced"
say "  tammo-power-saver doctor           # diagnostics"
say ""
say "If the application menu was open, log out and back in once to refresh it."

if [ -z "$DESTDIR" ]; then
    say ""
    report_backend || exit 1
fi
