# tammoOS Power Saver (Zorin OS style)

Adds Zorin OS' **Power Saver / Balanced / Performance** switch to tammoOS.

Zorin OS' Power Modes are not a proprietary Zorin component: they come from
`power-profiles-daemon`, which is also available on Ubuntu. This installer
enables that backend on tammoOS and adds a simple switcher for people who do
not want to dig through settings.

## What it does

- Installs and enables `power-profiles-daemon` (the same backend Zorin OS uses).
- Adds **Power Mode** and **Power Saver** entries to the application menu.
- Adds a small `tammo-power-saver` command for the terminal.
- On tammoOS 2.x / Ubuntu 24.04, GNOME's own Power Mode menu appears in Quick
  Settings automatically once the backend is installed.
- On tammoOS 1.x / 32-bit Ubuntu 18.04, where `power-profiles-daemon` is not
  available, it falls back to switching the CPU governor (`powersave`).

## Requirements

- tammoOS 2.x (64-bit, Ubuntu 24.04) is recommended.
- tammoOS 1.x (32-bit, Ubuntu 18.04) works through the legacy fallback.
- `sudo` rights to install.
- Internet access if `power-profiles-daemon` or `zenity` is not installed yet.

## Install

```bash
git clone https://github.com/tammoOS/tammoOS.git
cd tammoOS/powersaver
sudo bash install.sh
```

Then open **Power Mode** from the application menu.

> `sudo bash install.sh` also works if the executable bit was lost (for
> example after downloading a ZIP).

### No git installed?

Download the repository archive instead:

```bash
wget -O tammoOS.tar.gz https://github.com/tammoOS/tammoOS/archive/refs/heads/main.tar.gz
tar xzf tammoOS.tar.gz
cd tammoOS-main/powersaver
sudo bash install.sh
```

If `wget` is missing too, install it with `sudo apt install wget`, or use the
**Code → Download ZIP** button on GitHub and extract the archive.

## Use

### Application menu

- **Power Mode** – opens a small window with Balanced, Power Saver and
  Performance (only modes supported by your hardware are listed).
- **Power Saver** – toggles between Power Saver and Balanced with one click.

### Terminal

```bash
tammo-power-saver                 # interactive menu
tammo-power-saver gui             # graphical switcher
tammo-power-saver status          # current mode + backend
tammo-power-saver doctor          # diagnostics for troubleshooting
tammo-power-saver set power-saver # switch directly
tammo-power-saver set balanced
tammo-power-saver set performance # only if your CPU supports it
tammo-power-saver toggle          # Power Saver <-> Balanced
tammo-power-saver list            # available modes
```

If `power-profiles-daemon` is installed but cannot switch on your hardware,
force the CPU-governor fallback:

```bash
sudo tammo-power-saver legacy power-saver
```

## A note about "Power Saver"

Like Zorin, this changes the system power profile. It does **not** reduce screen
brightness, disable animations, or change Wi-Fi power saving. Zorin OS' Power
Mode feature itself is the `power-saver` profile from
`power-profiles-daemon`; GNOME handles the rest.

## Uninstall

```bash
cd powersaver
sudo bash uninstall.sh
```

`power-profiles-daemon` is intentionally left installed because GNOME and other
system components can use it.

## Troubleshooting

**First, run the diagnostic command and include its output when asking for help**

```bash
tammo-power-saver doctor
```

If the installer itself failed, you can still run the standalone diagnostic
script from the repository:

```bash
bash powersaver/diagnose.sh
```

It is read-only and safe to run without root.

**`git: command not found`**

```bash
sudo apt update && sudo apt install -y git
```

Or use the archive download described under [Install](#install).

**`sudo: ./install.sh: command not found` / `Permission denied`**

Make sure you are in the `powersaver` folder and run the script through bash:

```bash
cd tammoOS/powersaver
sudo bash install.sh
```

**The installer finishes but no profile changes**

Run:

```bash
tammo-power-saver doctor
tammo-power-saver status
```

If `PPD service` is not active:

```bash
sudo systemctl enable --now power-profiles-daemon
sudo systemctl status power-profiles-daemon --no-pager
```

**"Failed to activate CPU driver" / profile does not change**

Some laptops/BIOSes do not expose all profiles. The tool will report the error
and list the modes that are available. You can try:

```bash
sudo tammo-power-saver legacy power-saver
```

**The installer reports no working power backend**

The installer now stops with an error instead of silently succeeding. Check the
diagnostics above. On tammoOS 1.x / Ubuntu 18.04, `power-profiles-daemon` does
not exist and the legacy CPU-governor fallback should be used.

**TLP is installed**

TLP and `power-profiles-daemon` can fight over the CPU. If profiles do not
change:

```bash
sudo systemctl disable --now tlp
sudo systemctl enable --now power-profiles-daemon
```

**The Power Mode menu entry is missing**

Log out and back in once so the application menu refreshes. You can always use
the terminal in the meantime:

```bash
tammo-power-saver menu
```

**The graphical switcher does not open**

```bash
sudo apt install zenity libnotify-bin
```

The terminal menu (`tammo-power-saver menu`) works without them.

**Nothing changes on a desktop PC**

Power profiles mainly affect laptops. On desktops without CPU frequency scaling
or battery hardware, the available modes can be limited.

## Files installed

| Path | Purpose |
|---|---|
| `/usr/local/bin/tammo-power-saver` | CLI and graphical switcher |
| `/usr/local/share/applications/tammo-power-saver.desktop` | "Power Mode" menu entry |
| `/usr/local/share/applications/tammo-power-saver-toggle.desktop` | "Power Saver" toggle entry |

No sudoers rules are added. Normal profile changes use the existing polkit
policy of `power-profiles-daemon`; the legacy fallback asks for administrator
authentication through `pkexec`.

## Credits

- Zorin OS for the Power Modes idea and UI inspiration.
- The `power-profiles-daemon` project, which provides the actual power profiles.
