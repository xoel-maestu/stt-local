# shellcheck shell=bash
# config: Handy settings (model, automatic language, Right Ctrl shortcut, dotool
# typing). Merged into existing settings; a backup is kept and restored on uninstall.

CONFIG_SETTINGS="$HANDY_DATA/settings_store.json"
CONFIG_BACKUP="$STATE_DIR/settings_store.json.bak"
CONFIG_MARK="$STATE_DIR/config"
CONFIG_ENV="${XDG_CONFIG_HOME:-$HOME/.config}/environment.d/60-stt-local.conf"

# Settings stt-local sets. 'doctor' compares them with the current ones.
config_expected() {
	cat <<EOF
{
  "onboarding_completed": true,
  "selected_model": "$MODEL_ID",
  "selected_language": "auto",
  "keyboard_implementation": "handy_keys",
  "typing_tool": "dotool",
  "paste_method": "direct",
  "autostart_enabled": true,
  "start_hidden": true,
  "update_checks_enabled": false,
  "bindings": {
    "transcribe": {
      "id": "transcribe",
      "name": "Transcribe",
      "description": "Converts your speech into text.",
      "default_binding": "ctrl+space",
      "current_binding": "ctrl_right"
    }
  }
}
EOF
}

# Keyboard layout for dotool, so accented characters type correctly.
# First entry of the X11 layout list; 'us' when unknown.
xkb_layout() {
	local l
	l=$(localectl status 2>/dev/null | sed -n 's/^ *X11 Layout: *//p' | cut -d, -f1)
	echo "${l:-us}"
}

config_status() {
	[ -f "$CONFIG_MARK" ] && [ -f "$CONFIG_ENV" ] && [ -f "$CONFIG_SETTINGS" ]
}

config_install() {
	mkdir -p "$STATE_DIR" "$HANDY_DATA" "$(dirname "$CONFIG_ENV")"
	if [ -f "$CONFIG_SETTINGS" ] && [ ! -f "$CONFIG_BACKUP" ]; then
		cp "$CONFIG_SETTINGS" "$CONFIG_BACKUP"
	fi
	python3 -I -c '
import json, os, sys

path, expected = sys.argv[1], json.loads(sys.argv[2])
store = {}
if os.path.exists(path):
    with open(path) as f:
        store = json.load(f)
s = store.setdefault("settings", {})
bindings = expected.pop("bindings")
s.update(expected)
s.setdefault("bindings", {}).update(bindings)
tmp = path + ".stt-local.tmp"
with open(tmp, "w") as f:
    json.dump(store, f, indent=2)
os.replace(tmp, path)
' "$CONFIG_SETTINGS" "$(config_expected)"
	printf 'DOTOOL_XKB_LAYOUT=%s\n' "$(xkb_layout)" >"$CONFIG_ENV"
	touch "$CONFIG_MARK"
}

config_uninstall() {
	rm -f "$CONFIG_ENV"
	if [ -f "$CONFIG_BACKUP" ]; then
		mv "$CONFIG_BACKUP" "$CONFIG_SETTINGS"
	elif [ -f "$CONFIG_MARK" ]; then
		rm -f "$CONFIG_SETTINGS"
	fi
	rm -f "$CONFIG_MARK"
}
