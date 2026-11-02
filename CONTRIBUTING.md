# Contributing

Thanks for helping. Issues and pull requests are welcome.

## Reporting a problem

Open an issue with the output of `./stt.sh doctor`, your distro and version, and your desktop environment.

## Changing the code

- Keep it small and plain Bash. Each module in `modules/` defines `<name>_install`, `<name>_uninstall` and `<name>_status`; `uninstall` must undo exactly what `install` did.
- Pin versions and checksums for anything downloaded.
- Run before opening a pull request:

  ```sh
  shellcheck -x stt.sh modules/*.sh lib/*.sh tests/*.sh
  tests/distro.sh debian:13   # also archlinux:latest, fedora:43, ubuntu:24.04
  ```

  `tests/distro.sh` needs Docker. It installs and uninstalls inside a container and fails if anything is left behind.
- Never commit secrets, tokens or personal data, including in test fixtures.

By contributing you agree that your contributions are licensed under the [MIT License](LICENSE) and that you follow the [Code of Conduct](CODE_OF_CONDUCT.md).
