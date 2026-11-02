# shellcheck shell=bash
# doctor: checks that dictation works end to end. Read-only, changes nothing.

DOCTOR_FAILS=0

ok() { printf '  ok    %s\n' "$1"; }
warn() { printf '  warn  %s\n        %s\n' "$1" "$2"; }
fail() {
	printf '  FAIL  %s\n        %s\n' "$1" "$2"
	DOCTOR_FAILS=$((DOCTOR_FAILS + 1))
}

doctor_system() {
	local family
	family=$(distro_family)
	if [ -n "$family" ]; then ok "supported distro ($family)"; else fail "unsupported distro" "only Arch, Fedora, Debian, Ubuntu and derivatives"; fi
	case "${XDG_SESSION_TYPE:-}" in
	wayland) ok "Wayland session (${XDG_CURRENT_DESKTOP:-unknown desktop})" ;;
	x11) warn "X11 session" "stt-local targets Wayland; on X11 Handy can use xdotool instead" ;;
	*) warn "no graphical session detected" "run doctor from your desktop session" ;;
	esac
}

doctor_packages() {
	if command -v handy >/dev/null; then ok "Handy installed"; else fail "Handy not installed" "./stt.sh install packages"; fi
	if command -v dotool >/dev/null; then ok "dotool installed"; else fail "dotool not installed" "./stt.sh install packages"; fi
}

doctor_input() {
	if [ -f "$INPUT_RULE" ]; then ok "udev rule"; else fail "udev rule missing" "./stt.sh install input"; fi
	if [ -w /dev/uinput ]; then
		ok "/dev/uinput writable (typing)"
	else
		fail "/dev/uinput not writable" "./stt.sh install input; if it is installed, log out and back in"
	fi
	local dev readable=0 total=0
	for dev in /dev/input/event*; do
		[ -e "$dev" ] || continue
		total=$((total + 1))
		if [ -r "$dev" ]; then readable=$((readable + 1)); fi
	done
	if [ $total -gt 0 ] && [ $readable -eq $total ]; then
		ok "keyboard readable (Right Ctrl shortcut)"
	else
		fail "$((total - readable)) of $total input devices not readable" "./stt.sh install input; if it is installed, log out and back in"
	fi
}

doctor_model() {
	if [ ! -f "$MODEL_PATH" ]; then
		fail "model not downloaded" "./stt.sh install model"
	elif [ "$(stat -c %s "$MODEL_PATH")" -ne "$MODEL_SIZE" ]; then
		fail "model incomplete or damaged" "./stt.sh uninstall model && ./stt.sh install model"
	else
		ok "model $MODEL_FILE"
	fi
}

doctor_config() {
	if [ ! -f "$CONFIG_SETTINGS" ]; then
		fail "Handy has no settings" "./stt.sh install config"
		return
	fi
	local diff
	diff=$(python3 -I -c '
import json, sys
s = json.load(open(sys.argv[1])).get("settings", {})
exp = json.loads(sys.argv[2])
bad = [k for k, v in exp.items() if k != "bindings" and s.get(k) != v]
cur = s.get("bindings", {}).get("transcribe", {}).get("current_binding")
if cur != "ctrl_right":
    bad.append("shortcut=%s" % cur)
print(", ".join(bad))
' "$CONFIG_SETTINGS" "$(config_expected)" 2>&1) || { fail "Handy settings unreadable" "$diff"; return; }
	if [ -z "$diff" ]; then
		ok "Handy settings (model, Right Ctrl, dotool)"
	else
		warn "settings changed in Handy: $diff" "if that was not on purpose: ./stt.sh uninstall config && ./stt.sh install config"
	fi
	local want
	want=$(xkb_layout)
	if grep -qx "DOTOOL_XKB_LAYOUT=$want" "$CONFIG_ENV" 2>/dev/null; then
		ok "dotool keyboard layout: $want"
	else
		fail "dotool keyboard layout not set ($want)" "./stt.sh uninstall config && ./stt.sh install config"
	fi
}

doctor_runtime() {
	local pid layout
	pid=$(pgrep -x handy | head -1 || true)
	if [ -z "$pid" ]; then
		fail "Handy is not running" "start it from the app menu or log in again"
		return
	fi
	ok "Handy running (pid $pid)"
	layout=$(tr '\0' '\n' <"/proc/$pid/environ" 2>/dev/null | sed -n 's/^DOTOOL_XKB_LAYOUT=//p')
	if [ "$layout" = "$(xkb_layout)" ]; then
		ok "Handy uses keyboard layout $layout"
	else
		fail "Handy lacks DOTOOL_XKB_LAYOUT=$(xkb_layout) (accented characters would fail)" "log out and back in, or run ./stt.sh install"
	fi
}

doctor_audio() {
	if ! command -v pactl >/dev/null; then
		warn "cannot check the microphone" "pactl not found"
		return
	fi
	if pactl list short sources 2>/dev/null | grep -qv '\.monitor'; then
		ok "microphone available"
	else
		fail "no microphone found" "connect one or check your sound settings"
	fi
}

cmd_doctor() {
	doctor_system
	doctor_packages
	doctor_input
	doctor_model
	doctor_config
	doctor_runtime
	doctor_audio
	if [ $DOCTOR_FAILS -eq 0 ]; then
		log "all good"
	else
		log "$DOCTOR_FAILS problem(s) found"
		return 1
	fi
}
