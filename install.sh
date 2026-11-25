#!/usr/bin/env bash
# Install or uninstall agy-statusline. Idempotent; backs up settings.json before editing.
set -e
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$HOME/.local/bin/agy-statusline.sh"
SETTINGS="$HOME/.gemini/antigravity-cli/settings.json"

if [ "$1" = "--uninstall" ]; then
  python3 - "$SETTINGS" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d['statusLine'] = {"type": "", "command": "", "enabled": False}
json.dump(d, open(p, 'w'), indent=2)
print("statusLine disabled in", p)
PY
  rm -f "$BIN"
  echo "Removed $BIN"
  exit 0
fi

mkdir -p "$HOME/.local/bin"
cp "$SRC_DIR/agy-statusline.sh" "$BIN"
chmod +x "$BIN"
mkdir -p "$HOME/.gemini/antigravity-cli"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
cp "$SETTINGS" "$SETTINGS.bak-agy-statusline"
python3 - "$SETTINGS" "$BIN" <<'PY'
import json, sys
p, binp = sys.argv[1], sys.argv[2]
d = json.load(open(p))
d['statusLine'] = {"type": "command", "command": binp, "enabled": True}
json.dump(d, open(p, 'w'), indent=2)
print("statusLine configured in", p)
PY
echo "Installed $BIN (backup: $SETTINGS.bak-agy-statusline)"
echo "Restart any running 'agy' session to see the new status line."
