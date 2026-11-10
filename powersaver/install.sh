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

if [ -z "$DESTDIR" ] && [ "$(id -u)" -ne 0 ]; then
    die "Please run the installer with sudo: sudo $0"
fi

[ -f "$SCRIPT_DIR/bin/tammo-power-saver" ] || die "bin/tammo-power-saver is missing."
[ -d "$SCRIPT_DIR/share/applications" ] || die "share/applications is missing."

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
    # Install the backend and the small optional dependencies used by the GUI.
    if ! command -v powerprofilesctl >/dev/null 2>&1; then
        if command -v apt-get >/dev/null 2>&1; then
            say "Installing power-profiles-daemon (the backend used by Zorin OS)..."
            if ! DEBIAN_FRONTEND=noninteractive apt-get install -y power-profiles-daemon; then
                warn "power-profiles-daemon is not available on this tammoOS version."
                warn "The legacy CPU-governor fallback will be used instead."
            fi
        else
            warn "apt-get was not found. Install power-profiles-daemon manually."
        fi
    else
        say "power-profiles-daemon is already installed."
    fi

    missing=()
    command -v zenity >/dev/null 2>&1 || missing+=(zenity)
    command -v notify-send >/dev/null 2>&1 || missing+=(libnotify-bin)
    if [ "${#missing[@]}" -gt 0 ] && command -v apt-get >/dev/null 2>&1; then
        say "Installing optional GUI helpers: ${missing[*]}"
        DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing[@]}" || warn "Could not install ${missing[*]}; the terminal menu still works."
    fi

    if command -v systemctl >/dev/null 2>&1; then
        if systemctl list-unit-files 2>/dev/null | grep -q '^power-profiles-daemon\.service'; then
            systemctl enable --now power-profiles-daemon.service 2>/dev/null \
                || warn "Could not start power-profiles-daemon. Try: sudo systemctl enable --now power-profiles-daemon"
        fi
    fi

    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$APPDIR" >/dev/null 2>&1 || true
    fi
fi

say ""
say "tammoOS Power Saver was installed successfully."
say ""
say "Open \"Power Mode\" from the application menu, or use:"
say "  tammo-power-saver gui              # graphical switcher"
say "  tammo-power-saver menu             # terminal menu"
say "  tammo-power-saver set power-saver  # one-shot command"
say "  tammo-power-saver toggle           # Power Saver <-> Balanced"
say ""
say "A \"Power Saver\" launcher was also added to the application menu."
