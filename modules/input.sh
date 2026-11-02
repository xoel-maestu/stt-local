# shellcheck shell=bash
# input: keyboard access (Right Ctrl shortcut) and /dev/uinput (typing the text).
# A udev 'uaccess' rule grants it to the user of the active local session only,
# without adding anyone to the input group.

# uaccess tags must be set before 73-seat-late.rules, so this sorts before 73.
INPUT_RULE=/etc/udev/rules.d/70-stt-local.rules
# Packaged rules such as dotool's 80-dotool.rules set /dev/uinput to 0620, which
# masks the session ACL down to write-only. Handy opens it read-write, so this
# rule sorts after them and keeps group read-write (the ACL mask).
INPUT_MODE_RULE=/etc/udev/rules.d/90-stt-local-uinput.rules
INPUT_MODLOAD=/etc/modules-load.d/stt-local.conf

input_rule() {
	cat <<'EOF'
# stt-local: keyboard and uinput access for the active session user
KERNEL=="uinput", OPTIONS+="static_node=uinput", TAG+="uaccess"
SUBSYSTEM=="input", KERNEL=="event*", TAG+="uaccess"
EOF
}

input_mode_rule() {
	cat <<'EOF'
# stt-local: keep /dev/uinput read-write for the session ACL (see 70-stt-local.rules)
KERNEL=="uinput", MODE="0660"
EOF
}

input_status() {
	[ -f "$INPUT_RULE" ] && [ -f "$INPUT_MODE_RULE" ] && [ -f "$INPUT_MODLOAD" ] &&
		[ -r /dev/uinput ] && [ -w /dev/uinput ]
}

input_install() {
	local tmp
	tmp=$(mktemp)
	input_rule >"$tmp"
	sudo install -Dm644 "$tmp" "$INPUT_RULE"
	input_mode_rule >"$tmp"
	sudo install -Dm644 "$tmp" "$INPUT_MODE_RULE"
	echo uinput >"$tmp"
	sudo install -Dm644 "$tmp" "$INPUT_MODLOAD"
	rm -f "$tmp"
	sudo modprobe uinput
	sudo udevadm control --reload
	sudo udevadm trigger --subsystem-match=input --subsystem-match=misc
	sudo udevadm settle
	if ! [ -r /dev/uinput ] || ! [ -w /dev/uinput ]; then
		err "no read-write access to /dev/uinput (is this an active local session?)"
		return 1
	fi
}

input_uninstall() {
	sudo rm -f "$INPUT_RULE" "$INPUT_MODE_RULE" "$INPUT_MODLOAD"
	sudo udevadm control --reload
	sudo udevadm trigger --subsystem-match=input --subsystem-match=misc
}
