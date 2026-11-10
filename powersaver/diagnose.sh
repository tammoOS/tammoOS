#!/usr/bin/env bash
#
# Collect read-only diagnostics for the tammoOS Power Saver.
# Safe to run without root:
#
#   bash powersaver/diagnose.sh
#
# Paste the output when reporting a problem.

set -u

section() {
    printf '\n===== %s =====\n' "$*"
}

section "System"
if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    printf 'OS:      %s\n' "${PRETTY_NAME:-unknown}"
    printf 'ID:      %s\n' "${ID:-unknown}"
    printf 'Version: %s\n' "${VERSION_ID:-unknown}"
    printf 'Codename:%s\n' "${VERSION_CODENAME:-unknown}"
else
    echo "/etc/os-release not available"
fi
printf 'Kernel:  %s\n' "$(uname -r 2>/dev/null || echo unknown)"
printf 'Arch:    %s\n' "$(uname -m 2>/dev/null || echo unknown)"
printf 'Desktop: %s\n' "${XDG_CURRENT_DESKTOP:-unknown}"
printf 'Session: %s\n' "${XDG_SESSION_TYPE:-unknown}"
printf 'User:    %s (uid %s)\n' "$(id -un)" "$(id -u)"
printf 'DBus:    %s\n' "${DBUS_SESSION_BUS_ADDRESS:-missing}"

section "Commands"
for command in git wget curl powerprofilesctl systemctl zenity notify-send pkexec sudo; do
    path=$(command -v "$command" 2>/dev/null || true)
    printf '%-20s %s\n' "$command" "${path:-MISSING}"
done

section "power-profiles-daemon"
if command -v powerprofilesctl >/dev/null 2>&1; then
    printf 'Version: '
    powerprofilesctl version 2>&1 || true
    printf 'Current: '
    powerprofilesctl get 2>&1 || true
    echo "Profiles:"
    powerprofilesctl list 2>&1 || true
else
    echo "powerprofilesctl is not installed"
fi

if command -v systemctl >/dev/null 2>&1; then
    echo "Service:"
    systemctl status power-profiles-daemon.service --no-pager 2>&1 | sed -n '1,15p' || true
    echo "Recent service log:"
    journalctl -u power-profiles-daemon.service -n 15 --no-pager 2>&1 | tail -n 15 || true
fi

section "TLP"
if command -v systemctl >/dev/null 2>&1; then
    systemctl is-active tlp.service 2>&1 || true
    systemctl is-enabled tlp.service 2>&1 || true
else
    echo "systemctl not available"
fi

section "CPU frequency scaling"
if compgen -G '/sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_available_governors' >/dev/null; then
    for file in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_available_governors; do
        printf '%s: ' "$file"
        cat "$file" 2>/dev/null || true
    done
    echo "Current governor:"
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo unknown
    echo "Energy performance preference:"
    cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference 2>/dev/null || echo unavailable
else
    echo "No cpufreq scaling interfaces found"
fi

section "Installed files"
for file in \
    /usr/local/bin/tammo-power-saver \
    /usr/local/share/applications/tammo-power-saver.desktop \
    /usr/local/share/applications/tammo-power-saver-toggle.desktop \
    /usr/share/applications/tammo-power-saver.desktop \
    /usr/share/applications/tammo-power-saver-toggle.desktop; do
    if [ -e "$file" ]; then
        ls -l "$file" 2>&1 || true
    else
        echo "MISSING: $file"
    fi
done

section "tammo-power-saver doctor"
if command -v tammo-power-saver >/dev/null 2>&1; then
    tammo-power-saver doctor 2>&1 || true
else
    echo "tammo-power-saver is not in PATH"
fi

section "Application menu lookup"
if command -v gtk-launch >/dev/null 2>&1; then
    gtk-launch --help >/dev/null 2>&1 || true
fi
if command -v desktop-file-validate >/dev/null 2>&1; then
    for file in /usr/local/share/applications/tammo-power-saver*.desktop; do
        [ -e "$file" ] || continue
        desktop-file-validate "$file" 2>&1 || true
    done
fi

section "Done"
echo "Please paste this whole output when reporting the problem."
