#!/usr/bin/env bash
set -euo pipefail

# Zegary — instalator (Omarchy: Hyprland + Quickshell)
# Instaluje wtyczkę zegara LCD + wskaźnika baterii w lewym górnym rogu pulpitu.

BASE_URL="https://raw.githubusercontent.com/marmuto/zegary/main"
PLUGIN_ID="mrcn.desktop-clock"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
FONT_DIR="$HOME/.local/share/fonts/DSEG"
SHELL_JSON="$HOME/.config/omarchy/shell.json"

echo "==> Zegary: instalacja…"

# 1. Wtyczka
mkdir -p "$PLUGIN_DIR"
curl -fsSL "$BASE_URL/plugin/manifest.json" -o "$PLUGIN_DIR/manifest.json"
curl -fsSL "$BASE_URL/plugin/Panel.qml"     -o "$PLUGIN_DIR/Panel.qml"
echo "    wtyczka zapisana w $PLUGIN_DIR"

# 2. Czcionka LCD
mkdir -p "$FONT_DIR"
curl -fsSL "$BASE_URL/fonts/DSEG7Classic-Regular.ttf" -o "$FONT_DIR/DSEG7Classic-Regular.ttf"
curl -fsSL "$BASE_URL/fonts/DSEG7Classic-Bold.ttf"    -o "$FONT_DIR/DSEG7Classic-Bold.ttf"
if command -v fc-cache >/dev/null 2>&1; then
  fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || fc-cache -f >/dev/null 2>&1 || true
fi
echo "    czcionki zapisane w $FONT_DIR"

# 3. Rejestracja w shell.json (z kopią zapasową)
if [ ! -f "$SHELL_JSON" ]; then
  echo "!! Brak $SHELL_JSON — pomijam rejestrację wtyczki."
else
  cp "$SHELL_JSON" "$SHELL_JSON.bak.$(date +%s)"
  python3 - "$SHELL_JSON" "$PLUGIN_ID" <<'PY'
import json, sys
path, plugin_id = sys.argv[1], sys.argv[2]
with open(path) as f:
    data = json.load(f)
plugins = data.setdefault("plugins", [])
if not any(isinstance(p, dict) and p.get("id") == plugin_id for p in plugins):
    plugins.append({"id": plugin_id})
    with open(path, "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print("    dodano wpis do shell.json")
else:
    print("    wpis w shell.json już istnieje")
PY
fi

# 4. Restart shella
if command -v omarchy >/dev/null 2>&1; then
  omarchy restart shell >/dev/null 2>&1 || true
fi

echo "==> Gotowe. Zegar i bateria pojawiły się w lewym górnym rogu pulpitu."
