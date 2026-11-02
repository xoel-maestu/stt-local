#!/usr/bin/env bash
# stt-local: local speech-to-text with Handy + Parakeet V3 on Linux.
# Usage: ./stt.sh install|uninstall|status|doctor [module...]
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
MODULES=(packages input model config)

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/stt-local"
HANDY_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/com.pais.handy"

log() { printf '==> %s\n' "$*"; }
err() { printf 'error: %s\n' "$*" >&2; }

# Downloads to a temporary file and moves it into place only if the checksum matches.
# Usage: fetch_verified URL sha256|sha512 CHECKSUM DEST
fetch_verified() {
	local url=$1 algo=$2 sum=$3 dest=$4 part="$4.stt-local.part"
	mkdir -p "$(dirname "$dest")"
	curl -fL --retry 3 --progress-bar -C - -o "$part" "$url"
	if ! echo "$sum  $part" | "${algo}sum" -c --quiet; then
		rm -f "$part"
		err "$algo mismatch: $url"
		return 1
	fi
	mv "$part" "$dest"
}

# shellcheck source=modules/packages.sh
source "$ROOT/modules/packages.sh"
# shellcheck source=modules/input.sh
source "$ROOT/modules/input.sh"
# shellcheck source=modules/model.sh
source "$ROOT/modules/model.sh"
# shellcheck source=modules/config.sh
source "$ROOT/modules/config.sh"
# shellcheck source=lib/doctor.sh
source "$ROOT/lib/doctor.sh"

usage() {
	cat <<EOF
Usage: $0 <command> [module...]

Commands:
  install     install the given modules (all of them if none is given)
  uninstall   uninstall the given modules (all of them if none is given)
  status      show which modules are installed
  doctor      check that everything works, without changing anything

Modules: ${MODULES[*]}
EOF
}

preflight() {
	[ "$(id -u)" -ne 0 ] || { err "run as your user, not root (sudo is used when needed)"; exit 1; }
	[ -n "$(distro_family)" ] || { err "unsupported distro (Arch, Fedora, Debian, Ubuntu and derivatives)"; exit 1; }
	local c
	for c in sudo curl sha256sum sha512sum python3; do
		command -v "$c" >/dev/null || { err "'$c' is required"; exit 1; }
	done
	[ "${XDG_SESSION_TYPE:-}" = wayland ] || log "warning: stt-local targets Wayland sessions"
}

# Validates module names and returns them in canonical order.
select_modules() {
	local -n out=$1
	shift
	out=()
	if [ $# -eq 0 ]; then
		out=("${MODULES[@]}")
		return
	fi
	local a m
	for a in "$@"; do
		[[ " ${MODULES[*]} " == *" $a "* ]] || { err "unknown module: $a"; exit 1; }
	done
	for m in "${MODULES[@]}"; do
		if [[ " $* " == *" $m "* ]]; then out+=("$m"); fi
	done
}

# Runs a function in a subshell where errexit is effective.
run() {
	local rc
	set +e
	(
		set -e
		"$@"
	)
	rc=$?
	set -e
	return $rc
}

handy_running() { pgrep -x handy >/dev/null; }

stop_handy() {
	handy_running || return 0
	log "stopping Handy"
	pkill -x handy || true
	local i
	for i in $(seq 20); do
		handy_running || return 0
		sleep 0.25
	done
	pkill -9 -x handy || true
}

start_handy() {
	command -v handy >/dev/null || return 0
	if [ -z "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]; then
		log "no graphical session: Handy will start on next login"
		return 0
	fi
	stop_handy
	log "starting Handy"
	DOTOOL_XKB_LAYOUT=$(xkb_layout) setsid -f handy >/dev/null 2>&1
}

cmd_install() {
	local mods m i done_=()
	select_modules mods "$@"
	preflight
	stop_handy
	for m in "${mods[@]}"; do
		if run "${m}_status"; then
			log "$m: already installed"
			continue
		fi
		log "$m: installing"
		if ! run "${m}_install" || ! run "${m}_status"; then
			err "$m: failed; rolling back this run"
			run "${m}_uninstall" || true
			for ((i = ${#done_[@]} - 1; i >= 0; i--)); do
				log "${done_[i]}: rolling back"
				run "${done_[i]}_uninstall" || true
			done
			exit 1
		fi
		done_+=("$m")
	done
	start_handy
	for m in "${MODULES[@]}"; do
		run "${m}_status" || { log "done"; return 0; }
	done
	log "done. Hold Right Ctrl to dictate (or tap it once to start and again to stop)"
	log "check with: $0 doctor"
}

cmd_uninstall() {
	local mods i failed=()
	select_modules mods "$@"
	preflight
	stop_handy
	# Keeps going if a module fails, to remove as much as possible.
	for ((i = ${#mods[@]} - 1; i >= 0; i--)); do
		log "${mods[i]}: uninstalling"
		run "${mods[i]}_uninstall" || failed+=("${mods[i]}")
	done
	if [ ${#failed[@]} -gt 0 ]; then
		err "could not uninstall: ${failed[*]}"
		exit 1
	fi
	if [ ${#mods[@]} -eq ${#MODULES[@]} ]; then
		rm -rf "$STATE_DIR"
	else
		start_handy
	fi
	log "done"
}

cmd_status() {
	local m
	for m in "${MODULES[@]}"; do
		if run "${m}_status"; then printf '  [x] %s\n' "$m"; else printf '  [ ] %s\n' "$m"; fi
	done
}

case "${1:-}" in
install) shift; cmd_install "$@" ;;
uninstall) shift; cmd_uninstall "$@" ;;
status) cmd_status ;;
doctor) cmd_doctor ;;
-h | --help | help) usage ;;
*) usage; exit 1 ;;
esac
