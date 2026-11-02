# Security policy

## Reporting a vulnerability

Please do not open a public issue. Report it privately through GitHub: **Security → Report a vulnerability** on this repository. You should get an answer within a week.

Problems in Handy, dotool or the model belong to their own projects (see [THIRD_PARTY.md](THIRD_PARTY.md)).

## Scope

stt-local runs commands with `sudo`, installs a udev rule that grants keyboard and `/dev/uinput` access to the active session user, and downloads files that it verifies with pinned checksums. Reports about any of these are in scope.
