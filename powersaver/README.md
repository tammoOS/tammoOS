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
sudo ./install.sh
```

Then open **Power Mode** from the application menu.

> If you downloaded a ZIP instead, extract it, open a terminal in the
> `powersaver` folder, and run `sudo ./install.sh`.

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
sudo ./uninstall.sh
```

`power-profiles-daemon` is intentionally left installed because GNOME and other
system components can use it.

## Troubleshooting

**`powerprofilesctl: command not found`**

```bash
sudo apt install power-profiles-daemon
sudo systemctl enable --now power-profiles-daemon
```

**"Failed to activate CPU driver" / profile does not change**

Some laptops/BIOSes do not expose all profiles. The tool will report the error
and list the modes that are available. You can try:

```bash
sudo tammo-power-saver legacy power-saver
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
