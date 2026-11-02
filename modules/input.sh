# shellcheck shell=bash
# input: keyboard access (Right Ctrl shortcut) and /dev/uinput (typing the text).
# A udev 'uaccess' rule grants it to the user of the active local session only,
# without adding anyone to the input group.

INPUT_RULE=/etc/udev/rules.d/70-stt-local.rules
INPUT_MODLOAD=/etc/modules-load.d/stt-local.conf

input_rule() {
	cat <<'EOF'
# stt-local: keyboard and uinput access for the active session user
KERNEL=="uinput", OPTIONS+="static_node=uinput", TAG+="uaccess"
SUBSYSTEM=="input", KERNEL=="event*", TAG+="uaccess"
EOF
}

input_status() {
	[ -f "$INPUT_RULE" ] && [ -f "$INPUT_MODLOAD" ] && [ -w /dev/uinput ]
}

input_install() {
	local tmp
	tmp=$(mktemp)
	input_rule >"$tmp"
	sudo install -Dm644 "$tmp" "$INPUT_RULE"
	echo uinput >"$tmp"
	sudo install -Dm644 "$tmp" "$INPUT_MODLOAD"
	rm -f "$tmp"
	sudo modprobe uinput
	sudo udevadm control --reload
	sudo udevadm trigger --subsystem-match=input --subsystem-match=misc
	sudo udevadm settle
	[ -w /dev/uinput ] || { err "no access to /dev/uinput (is this an active local session?)"; return 1; }
}

input_uninstall() {
	sudo rm -f "$INPUT_RULE" "$INPUT_MODLOAD"
	sudo udevadm control --reload
	sudo udevadm trigger --subsystem-match=input --subsystem-match=misc
}
