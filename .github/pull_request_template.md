**What this changes and why**

**Checklist**

- [ ] `shellcheck -x stt.sh modules/*.sh lib/*.sh tests/*.sh` passes
- [ ] `tests/distro.sh` passes for the affected distros
- [ ] `uninstall` still undoes exactly what `install` does
- [ ] No secrets or personal data
