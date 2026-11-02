# Changelog

All notable changes to this project are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `install`, `uninstall`, `status` and `doctor` commands.
- Modules `packages`, `input`, `model` and `config`, with atomic install (rollback of the current run on failure) and clean uninstall.
- Support for Arch, Fedora, Debian and Ubuntu (x86_64).
- Handy 0.9.8 with Parakeet TDT 0.6B v3 (Q4_K_M), Right Ctrl shortcut and dotool typing.
- CI: shellcheck and install/uninstall tests in containers for each supported distro.
