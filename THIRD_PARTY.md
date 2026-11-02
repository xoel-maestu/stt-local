# Third-party software and models

stt-local does not include or redistribute any of these components. It installs or downloads them from their official sources, and each one is governed by its own license.

| Component | Used for | License | Source |
|---|---|---|---|
| Handy | Dictation app | MIT | https://github.com/cjpais/Handy |
| handy-keys | Handy's global shortcut (part of Handy) | MIT | https://github.com/handy-computer/handy-keys |
| handy-bin (AUR PKGBUILD) | Handy package for Arch | See AUR | https://aur.archlinux.org/packages/handy-bin |
| dotool | Typing the text on Wayland | GPL-3.0 | https://git.sr.ht/~geb/dotool |
| dotool (AUR PKGBUILD, Fedora package) | dotool package for Arch and Fedora | See each package | https://aur.archlinux.org/packages/dotool, https://packages.fedoraproject.org/pkgs/dotool/ |
| Go | Building dotool on Debian and Ubuntu (temporary, removed after the build) | BSD-3-Clause | https://go.dev |
| Parakeet TDT 0.6B v3 | Speech recognition model | CC-BY-4.0 | https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3 |
| parakeet-tdt-0.6b-v3-gguf | GGUF conversion of the model | CC-BY-4.0 | https://huggingface.co/handy-computer/parakeet-tdt-0.6b-v3-gguf |

stt-local only runs dotool as a separate program (through Handy); it does not link to, modify or distribute it.

## Model attribution

Parakeet TDT 0.6B v3 by NVIDIA, licensed under Creative Commons Attribution 4.0 (https://creativecommons.org/licenses/by/4.0/). GGUF conversion by handy-computer. stt-local does not modify the model.

"Handy", "NVIDIA" and "Parakeet" belong to their respective owners. This project is not affiliated with them.
