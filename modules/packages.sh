# shellcheck shell=bash
# packages: Handy and dotool (types the text on Wayland).
#   Arch and derivatives:  AUR (handy-bin, dotool)
#   Fedora:                official Handy .rpm + dotool from the Fedora repos
#   Debian and Ubuntu:     official Handy .deb + dotool built from source
# Uninstall only removes what this script installed, as recorded in $PACKAGES_STATE.

PACKAGES_STATE="$STATE_DIR/packages"

HANDY_VERSION=0.9.8
HANDY_URL="https://github.com/cjpais/Handy/releases/download/v$HANDY_VERSION"
HANDY_DEB="Handy_${HANDY_VERSION}_amd64.deb"
HANDY_DEB_SHA256=4efe1fdcc2b68e95612e866810ccb23e06bbdf004a4e857de0862b0c6927caa8
HANDY_RPM="Handy-$HANDY_VERSION-1.x86_64.rpm"
HANDY_RPM_SHA256=7038045edb560bb5497503541b1c43ce6b467b796169d20accd4e17210c60baf

DOTOOL_VERSION=1.6
DOTOOL_URL="https://git.sr.ht/~geb/dotool/archive/$DOTOOL_VERSION.tar.gz"
DOTOOL_SHA512=8a1439db938807574cafde61c6f68249e11cd7f5250db032d547629ed77cbe4e06e4fa6217c6ac823ed85b88d81c82a2172fd9456b938c9f7193a104d7c458ad
GO_TARBALL=go1.27.3.linux-amd64.tar.gz
GO_SHA256=65efbc80fdc1fa2cd2631cad5b481777a68e8725f34e89f50fc6ac714e379b40
DOTOOL_BINS=(/usr/local/bin/dotool /usr/local/bin/dotoolc /usr/local/bin/dotoold)

# Distro family: arch, fedora or debian. Empty when unsupported.
distro_family() {
	[ -r /etc/os-release ] || return 0
	local w
	# shellcheck source=/dev/null
	for w in $(. /etc/os-release; echo "${ID:-} ${ID_LIKE:-}"); do
		case "$w" in
		arch) echo arch; return ;;
		fedora) echo fedora; return ;;
		debian | ubuntu) echo debian; return ;;
		esac
	done
}

pkg_installed() {
	case "$(distro_family)" in
	arch) pacman -Q "$1" &>/dev/null ;;
	fedora) rpm -q "$1" &>/dev/null ;;
	debian) dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'ok installed' ;;
	esac
}

# What is missing, space separated, using the generic names 'handy' and 'dotool'.
packages_missing() {
	local out=""
	case "$(distro_family)" in
	arch) out=$(pacman -T handy dotool || true) ;;
	*)
		pkg_installed handy || out="handy"
		command -v dotool >/dev/null || out="$out dotool"
		;;
	esac
	echo "$out" | xargs
}

packages_status() {
	[ -n "$(distro_family)" ] && [ -z "$(packages_missing)" ]
}

record() {
	mkdir -p "$STATE_DIR"
	printf '%s\n' "$@" >>"$PACKAGES_STATE"
}

installed_names() {
	case "$(distro_family)" in
	fedora) rpm -qa --qf '%{NAME}\n' ;;
	debian) dpkg-query -W -f='${Package}\n' ;;
	esac | sort -u
}

# Runs "$@" and records every package it pulled in as a dependency, even if it
# fails half way, so that a rollback removes exactly those.
install_tracking_deps() {
	local before after p rc=0
	before=$(installed_names)
	"$@" || rc=$?
	after=$(installed_names)
	for p in $(comm -13 <(echo "$before") <(echo "$after")); do
		case "$p" in handy | dotool) ;; *) record "dep $p" ;; esac
	done
	return $rc
}

# Packages nothing needs any more (recommends do not count as a need).
unneeded_names() {
	case "$(distro_family)" in
	fedora) dnf repoquery --unneeded --qf '%{name}\n' 2>/dev/null ;;
	debian)
		apt-get -s -o APT::AutoRemove::RecommendsImportant=false \
			-o APT::AutoRemove::SuggestsImportant=false autoremove |
			sed -n 's/^Remv \([^ :]*\).*/\1/p'
		;;
	esac
}

packages_install() {
	local family
	family=$(distro_family)
	[ -n "$family" ] || { err "unsupported distro (Arch, Fedora, Debian, Ubuntu and derivatives)"; return 1; }
	[ "$family" = arch ] || [ "$(uname -m)" = x86_64 ] || { err "only x86_64 is supported on Fedora and Debian"; return 1; }
	"packages_install_$family" "$(packages_missing)"
}

packages_install_arch() {
	local helper="" h p pkgs=()
	for h in yay paru; do command -v "$h" >/dev/null && { helper=$h; break; }; done
	[ -n "$helper" ] || { err "an AUR helper is required (yay or paru)"; return 1; }
	for p in $1; do
		[ "$p" = handy ] && p=handy-bin
		pkgs+=("$p")
	done
	# Recorded before installing so that a half-finished install is rolled back too.
	# makepkg's default 'debug' option also builds and installs <pkg>-debug.
	for p in "${pkgs[@]}"; do record "pkg $p" "pkg $p-debug"; done
	"$helper" -S --needed --noconfirm --removemake "${pkgs[@]}"
}

packages_install_fedora() {
	local tmp pkgs=()
	tmp=$(mktemp -d)
	if [[ " $1 " == *" handy "* ]]; then
		fetch_verified "$HANDY_URL/$HANDY_RPM" sha256 "$HANDY_RPM_SHA256" "$tmp/$HANDY_RPM"
		pkgs+=("$tmp/$HANDY_RPM")
		record "pkg handy"
	fi
	if [[ " $1 " == *" dotool "* ]]; then
		pkgs+=(dotool)
		record "pkg dotool"
	fi
	install_tracking_deps sudo dnf install -y "${pkgs[@]}"
	rm -rf "$tmp"
}

packages_install_debian() {
	local tmp
	tmp=$(mktemp -d)
	sudo apt-get update
	if [[ " $1 " == *" handy "* ]]; then
		fetch_verified "$HANDY_URL/$HANDY_DEB" sha256 "$HANDY_DEB_SHA256" "$tmp/$HANDY_DEB"
		record "pkg handy"
		install_tracking_deps sudo apt-get install -y "$tmp/$HANDY_DEB"
	fi
	if [[ " $1 " == *" dotool "* ]]; then
		build_dotool "$tmp"
	fi
	rm -rf "$tmp"
}

# Builds dotool with the official Go toolchain in a temporary directory. Missing
# build dependencies are installed and then removed again, exactly those.
build_dotool() {
	local tmp=$1 before after builddeps rc=0
	before=$(installed_names)
	sudo apt-get install -y --no-install-recommends gcc libc6-dev libxkbcommon-dev pkg-config
	after=$(installed_names)
	builddeps=$(comm -13 <(echo "$before") <(echo "$after"))

	fetch_verified "https://go.dev/dl/$GO_TARBALL" sha256 "$GO_SHA256" "$tmp/$GO_TARBALL"
	fetch_verified "$DOTOOL_URL" sha512 "$DOTOOL_SHA512" "$tmp/dotool.tar.gz"
	tar -xzf "$tmp/$GO_TARBALL" -C "$tmp"
	tar -xzf "$tmp/dotool.tar.gz" -C "$tmp"
	(
		cd "$tmp/dotool-$DOTOOL_VERSION"
		export GOPATH="$tmp/gopath" GOCACHE="$tmp/gocache" GOFLAGS=-modcacherw GOTOOLCHAIN=local CGO_ENABLED=1
		"$tmp/go/bin/go" build -ldflags "-X main.Version=$DOTOOL_VERSION"
	) || rc=$?
	if [ -n "$builddeps" ]; then
		# shellcheck disable=SC2086
		sudo apt-get purge -y $builddeps
	fi
	[ $rc -eq 0 ] || { err "could not build dotool"; return 1; }

	record "${DOTOOL_BINS[@]/#/file }"
	sudo install -Dm755 -t /usr/local/bin \
		"$tmp/dotool-$DOTOOL_VERSION/dotool" \
		"$tmp/dotool-$DOTOOL_VERSION/dotoolc" \
		"$tmp/dotool-$DOTOOL_VERSION/dotoold"
}

packages_uninstall() {
	[ -f "$PACKAGES_STATE" ] || return 0
	local family kind name p pkgs=() deps=() files=() installed=() orphans=()
	family=$(distro_family)
	while read -r kind name; do
		case "$kind" in
		pkg) pkgs+=("$name") ;;
		dep) deps+=("$name") ;;
		file) files+=("$name") ;;
		esac
	done < <(sort -u "$PACKAGES_STATE")

	if [ ${#files[@]} -gt 0 ]; then
		sudo rm -f "${files[@]}"
	fi
	for p in "${pkgs[@]}"; do
		if pkg_installed "$p"; then installed+=("$p"); fi
	done
	if [ ${#installed[@]} -gt 0 ]; then
		case "$family" in
		arch) sudo pacman -Rns --noconfirm "${installed[@]}" ;;
		fedora) sudo dnf remove -y "${installed[@]}" ;;
		debian) sudo apt-get purge -y "${installed[@]}" ;;
		esac
	fi
	# Dependencies we pulled in that nothing needs any more. Never anything else.
	if [ ${#deps[@]} -gt 0 ]; then
		mapfile -t orphans < <(unneeded_names | grep -Fxf <(printf '%s\n' "${deps[@]}") || true)
		if [ ${#orphans[@]} -gt 0 ]; then
			case "$family" in
			fedora) sudo dnf remove -y "${orphans[@]}" ;;
			debian) sudo apt-get purge -y "${orphans[@]}" ;;
			esac
		fi
	fi
	# If we installed Handy, its user data goes with it.
	if grep -qE '^pkg (handy|handy-bin)$' "$PACKAGES_STATE"; then
		rm -rf "$HANDY_DATA" "${XDG_CACHE_HOME:-$HOME/.cache}/com.pais.handy" \
			"${XDG_CONFIG_HOME:-$HOME/.config}/autostart/Handy.desktop"
	fi
	rm -f "$PACKAGES_STATE"
}
