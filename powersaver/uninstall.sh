#!/usr/bin/env bash
#
# Remove the tammoOS Power Saver switcher.
#
#   sudo ./uninstall.sh
#
# Optional environment variables:
#   PREFIX=/usr/local
#   DESTDIR=/tmp/package-root

set -euo pipefail

PREFIX=${PREFIX:-/usr/local}
DESTDIR=${DESTDIR:-}
BINDIR="$PREFIX/bin"
APPDIR="$PREFIX/share/applications"

say() { printf '%s\n' "$*"; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

if [ -z "$DESTDIR" ] && [ "$(id -u)" -ne 0 ]; then
    die "Please run the uninstaller with sudo: sudo $0"
fi

say "Removing tammoOS Power Saver..."

rm -f "$DESTDIR$BINDIR/tammo-power-saver"
for name in tammo-power-saver.desktop tammo-power-saver-toggle.desktop; do
    rm -f "$DESTDIR$APPDIR/$name"
done

if [ -z "$DESTDIR" ] && command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$APPDIR" >/dev/null 2>&1 || true
fi

say "Removed."
say ""
say "power-profiles-daemon was left installed because other parts of the system"
say "(including GNOME's own Power Mode menu) may use it."
