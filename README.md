# stt-local

[![CI](https://github.com/xoel-maestu/stt-local/actions/workflows/ci.yml/badge.svg)](https://github.com/xoel-maestu/stt-local/actions/workflows/ci.yml)

Local, private speech-to-text dictation for Linux on Wayland, set up and removed with one command.

stt-local installs [Handy](https://github.com/cjpais/Handy) with the Parakeet TDT 0.6B v3 model (25 European languages, including English and Spanish) and configures it so that you hold **Right Ctrl**, speak, and the text is typed into the focused window. Audio never leaves your machine.

This is an unofficial project, not affiliated with Handy or NVIDIA.

## Requirements

- x86_64 Linux on a Wayland session. Tested on KDE Plasma 6.
- One of:
  - Arch Linux or a derivative, with `yay` or `paru`
  - Fedora 43 or newer
  - Debian 13, Ubuntu 24.04 or newer, or a derivative
- `sudo`, `curl`, `python3`

## Usage

```sh
git clone https://github.com/xoel-maestu/stt-local.git
cd stt-local
./stt.sh install      # install everything
./stt.sh doctor       # check that everything works
./stt.sh uninstall    # remove everything
./stt.sh status       # show what is installed
```

Run it as your user from your desktop session. It asks for `sudo` when needed.

To dictate, hold **Right Ctrl** while you speak and release it. You can also tap it once to start and again to stop.

## Modules

Each module can be installed or removed on its own, for example `./stt.sh install model config`.

| Module | What it does | What it touches |
|---|---|---|
| `packages` | Installs Handy and dotool (see below) | System packages, `/usr/local/bin/dotool*` on Debian/Ubuntu |
| `input` | Lets the active session user read the keyboard (shortcut) and write to `/dev/uinput` (typing) | `/etc/udev/rules.d/70-stt-local.rules`, `/etc/udev/rules.d/90-stt-local-uinput.rules`, `/etc/modules-load.d/stt-local.conf` |
| `model` | Downloads Parakeet V3 Q4_K_M (485 MB) and verifies its sha256 | `~/.local/share/com.pais.handy/models/` |
| `config` | Sets the model, Right Ctrl shortcut, dotool typing, start on login, no update checks | `~/.local/share/com.pais.handy/settings_store.json`, `~/.config/environment.d/60-stt-local.conf` |

How `packages` gets Handy and dotool:

| Distro | Handy | dotool |
|---|---|---|
| Arch | AUR `handy-bin` | AUR `dotool` |
| Fedora | Official `.rpm` (pinned, sha256 verified) | Fedora repos |
| Debian, Ubuntu | Official `.deb` (pinned, sha256 verified) | Built from pinned source with the official Go toolchain in a temporary directory. Build dependencies are removed afterwards. |

## Atomic install, clean uninstall

- A module that is already installed is left alone.
- If a module fails, that module and every module installed in the same run are rolled back, so the system is left as it was.
- Downloads go to a temporary file and are only moved into place when the checksum matches. Settings are written to a temporary file and replaced in one step.
- `uninstall` removes only what stt-local installed: the packages and the dependencies they pulled in that nothing else needs. Packages you already had stay.
- If stt-local installed Handy, `uninstall` also deletes Handy's user data: models, history, recordings, settings and the autostart entry. If you had Handy settings before, they are restored from the backup taken at install time.

The CI installs and uninstalls on Arch, Fedora, Debian and Ubuntu containers, including a forced failure, and checks that the package list ends up identical to the one before.

## Resource usage

| | Disk | RAM |
|---|---|---|
| Parakeet V3 Q4_K_M | 485 MB | about 0.7 to 0.9 GB while transcribing (estimate) |
| Handy | about 41 MB plus dependencies (WebKitGTK) | about 100 to 200 MB idle (estimate) |

Handy unloads the model after 5 minutes without use.

## Notes

- **Keyboard access.** The shortcut works on Wayland because Handy reads the keyboard directly from `/dev/input`. The `uaccess` udev rule grants that only to the user with the active local session, not over SSH and not to other users. Reading `/dev/input` means reading the keyboard; the kernel offers nothing finer for a global shortcut like this.
- **Keyboard layout.** dotool types using your keyboard layout (detected with `localectl`) so that accented characters come out right. The variable is loaded at login; the installer starts Handy with it right away.
- **Recording overlay.** If the recording overlay misbehaves on KDE, start Handy with `HANDY_NO_GTK_LAYER_SHELL=1`.
- **Other platforms.** On Windows and macOS, Handy works natively without this extra setup: install it and pick the model and shortcut in its settings.

## Troubleshooting

Run `./stt.sh doctor`. It checks every piece (packages, permissions, model, settings, keyboard layout, running process, microphone) without changing anything, and prints the fix for each problem.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Security issues: see [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE). This repository does not include or redistribute third-party software or models; it downloads them from their official sources. See [THIRD_PARTY.md](THIRD_PARTY.md) for licenses and attribution.
