#!/usr/bin/env bash
#
# tammoOS - Power Saver installer (Zorin OS feature)
# ==================================================
# Adds the Power Saver feature from Zorin OS to tammoOS.
#
# tammoOS 2.x (Ubuntu 24.04 base, 64-bit)
#   Installs and enables power-profiles-daemon, the same backend Zorin OS
#   uses, and switches on the matching desktop settings:
#     - Balanced / Power Saver / Performance in Settings -> Power
#     - Power profile toggle in the Quick Settings menu
#     - Automatic switch to Power Saver when the battery runs low
#     - Battery percentage in the top bar, screen dimming, automatic suspend
#
# tammoOS 1.x (Ubuntu 18.04 base, 32-bit)
#   GNOME 3.28 predates power-profiles-daemon, so TLP is used as the power
#   backend instead. The tammo-powersaver command works the same way.
#
# Usage:
#   sudo bash install.sh
#
# Afterwards you can switch profiles with:
#   tammo-powersaver set power-saver|balanced|performance
#   tammo-powersaver status
#   tammo-powersaver toggle

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ${EUID} -ne 0 ]]; then
    echo "This installer must run as root:" >&2
    echo "  sudo bash $0" >&2
    exit 1
fi

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m ->\033[0m %s\n' "$*"; }

# gset <user> <schema> <key> <value>
# Best effort: quietly skips keys the installed desktop does not have.
gset() {
    local user=$1 schema=$2 key=$3 value=$4 uid bus
    uid="$(id -u "$user")"
    bus="unix:path=/run/user/${uid}/bus"
    if runuser -u "$user" -- env DBUS_SESSION_BUS_ADDRESS="$bus" \
        gsettings set "$schema" "$key" "$value" 2>/dev/null; then
        return 0
    fi
    runuser -u "$user" -- dbus-launch --exit-with-session \
        gsettings set "$schema" "$key" "$value" 2>/dev/null || \
        warn "  $schema $key is not available on this desktop (skipped)"
}

# Apply the Zorin-style desktop power settings for every desktop user.
apply_desktop_settings() {
    local users u
    users="${SUDO_USER:-}"
    [[ $users == root ]] && users=""
    while IFS= read -r u; do
        [[ -n $u && $u != root ]] && users+="${users:+$'\n'}${u}"
    done < <(loginctl list-users --no-legend 2>/dev/null | awk '{print $2}')

    if [[ -z $users ]]; then
        warn "No desktop user found; skipping desktop settings."
        return 0
    fi

    while IFS= read -r u; do
        [[ -z $u ]] && continue
        info "Applying power settings for user '$u'"
        gset "$u" org.gnome.desktop.interface show-battery-percentage true
        gset "$u" org.gnome.desktop.session idle-delay 300
        gset "$u" org.gnome.settings-daemon.plugins.power idle-dim true
        gset "$u" org.gnome.settings-daemon.plugins.power power-saver-profile-on-low-battery true
        gset "$u" org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'suspend'
        gset "$u" org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'suspend'
        gset "$u" org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 1800
        gset "$u" org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 900
    done <<< "$(printf '%s\n' "$users" | sort -u)"
}

# tammoOS 2.x: power-profiles-daemon, the backend Zorin OS uses.
install_ppd() {
    info "Installing power-profiles-daemon (the power backend Zorin OS uses)..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq || warn "apt update failed; trying to continue anyway"
    apt-get install -y --no-install-recommends power-profiles-daemon

    if systemctl is-active --quiet tlp 2>/dev/null; then
        warn "TLP is active and conflicts with power-profiles-daemon; disabling TLP."
        systemctl disable --now tlp 2>/dev/null || true
    fi

    systemctl enable power-profiles-daemon.service
    systemctl restart power-profiles-daemon.service
    info "power-profiles-daemon is installed and running."
}

# Ubuntu 18.04 reached end of standard support; its packages moved to
# old-releases.ubuntu.com. Point sources.list there and refresh.
switch_to_old_releases() {
    warn "Ubuntu 18.04 reached end of standard support; switching package sources to old-releases.ubuntu.com..."
    sed -i -E \
        -e 's|http://[a-z.]*archive\.ubuntu\.com/ubuntu|http://old-releases.ubuntu.com/ubuntu|g' \
        -e 's|http://[a-z.]*security\.ubuntu\.com/ubuntu|http://old-releases.ubuntu.com/ubuntu|g' \
        /etc/apt/sources.list
    apt-get update -qq
}

# tammoOS 1.x: TLP as power backend (GNOME 3.28 has no power-profiles-daemon).
install_tlp() {
    info "Ubuntu 18.04 base detected (tammoOS 1.x); using TLP as the power backend..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq || true
    if ! apt-get install -y --no-install-recommends tlp; then
        switch_to_old_releases
        apt-get install -y --no-install-recommends tlp
    fi
    systemctl enable tlp.service 2>/dev/null || true
    systemctl start tlp.service 2>/dev/null || true
    tlp start 2>/dev/null || true
    info "TLP is installed and started."
}

install_cli() {
    info "Installing the tammo-powersaver command..."
    install -m 0755 "${SCRIPT_DIR}/tammo-powersaver" /usr/local/bin/tammo-powersaver
    install -m 0644 "${SCRIPT_DIR}/tammo-powersaver.desktop" \
        /usr/local/share/applications/tammo-powersaver.desktop
    mkdir -p /var/lib/tammo-powersaver
    [[ -f /var/lib/tammo-powersaver/profile ]] || echo balanced > /var/lib/tammo-powersaver/profile
}

main() {
    # shellcheck disable=SC1091
    . /etc/os-release
    local base_major="${VERSION_ID%%.*}"

    case "${base_major}" in
        24) install_ppd ;;
        18) install_tlp ;;
        *)
            warn "Unrecognised Ubuntu base (VERSION_ID=${VERSION_ID:-unknown}); guessing..."
            if have_bin powerprofilesctl; then install_ppd; else install_tlp; fi
            ;;
    esac

    install_cli
    apply_desktop_settings

    echo
    info "tammoOS Power Saver installed."
    echo "  Switch profiles: tammo-powersaver set power-saver|balanced|performance"
    echo "  Check status:    tammo-powersaver status"
    echo "  On tammoOS 2.x the profiles also appear in Settings -> Power and in"
    echo "  the Quick Settings menu, exactly like in Zorin OS."
}

have_bin() { command -v "$1" >/dev/null 2>&1; }

main "$@"
