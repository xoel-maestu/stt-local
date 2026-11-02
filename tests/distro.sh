#!/usr/bin/env bash
# Container test: installs and uninstalls the given modules and checks that the
# package list and files end up exactly as they were before.
# The input module needs udev and a real session, so it is not tested here.
# Usage: tests/distro.sh <image> [modules]   (e.g. tests/distro.sh debian:13)
set -euo pipefail

IMAGE=${1:?usage: $0 <image> [modules]}
MODS=${2:-packages config}
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

docker run --rm -v "$ROOT:/src:ro" -e MODS="$MODS" "$IMAGE" bash -c '
set -euo pipefail
. /etc/os-release
case " $ID ${ID_LIKE:-} " in
*" arch "*) pacman -Syu --noconfirm --needed -q sudo curl python base-devel git diffutils >/dev/null ;;
*" fedora "*) dnf -y -q install sudo curl python3 procps-ng util-linux diffutils systemd-udev >/dev/null ;;
*" debian "* | *" ubuntu "*)
	export DEBIAN_FRONTEND=noninteractive
	apt-get -qq update
	# adduser and systemd-sysv are part of every real Debian install.
	apt-get -qq install -y sudo curl python3 ca-certificates procps diffutils udev adduser systemd-sysv >/dev/null ;;
esac
# Containers have no udev daemon and a read-only /sys; package scriptlets that
# reload udev would fail here, unlike on a real system.
printf "#!/bin/sh\nexit 0\n" >/usr/bin/udevadm
useradd -m tester
echo "tester ALL=(ALL) NOPASSWD: ALL" >/etc/sudoers.d/tester
pkgs() {
	if command -v pacman >/dev/null; then pacman -Qq
	elif command -v rpm >/dev/null; then rpm -qa --qf "%{NAME}\n"
	else dpkg-query -W -f="\${Package}\n"; fi | sort
}
as_tester() { su tester -c "cd /src && DEBIAN_FRONTEND=noninteractive $*"; }
if command -v pacman >/dev/null; then
	su tester -c "cd /tmp && git clone -q https://aur.archlinux.org/yay-bin.git && cd yay-bin && makepkg -si --noconfirm >/dev/null"
fi

fail=0
check_clean() {
	local after f
	after=$(pkgs)
	if ! diff <(echo "$before") <(echo "$after"); then echo "LEFTOVER after $1: packages"; fail=1; fi
	for f in /usr/local/bin/dotool /home/tester/.local/share/com.pais.handy \
		/home/tester/.local/state/stt-local/packages \
		/home/tester/.config/environment.d/60-stt-local.conf; do
		if [ -e "$f" ]; then echo "LEFTOVER after $1: $f"; fail=1; fi
	done
}
before=$(pkgs)

# 1. Atomic rollback: config fails (settings path is a directory), so the
#    packages installed in the same run must be removed again.
su tester -c "mkdir -p ~/.local/share/com.pais.handy/settings_store.json"
if as_tester ./stt.sh install packages config; then echo "rollback: install should have failed"; fail=1; fi
check_clean rollback

# 2. Normal install and uninstall.
as_tester ./stt.sh install $MODS
as_tester ./stt.sh status
as_tester "command -v handy dotool"
as_tester ./stt.sh doctor || true
as_tester ./stt.sh uninstall $MODS
check_clean uninstall

if [ $fail -eq 0 ]; then echo "CLEAN: $PRETTY_NAME"; fi
exit $fail
'
