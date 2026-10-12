#!/usr/bin/env bash
# Install handy-herdr CLIs and point Handy at the paste script (macOS).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"

mkdir -p "$BIN_DIR" "$HOME/.config/herdr"

for name in handy-to-herdr handy-target; do
  chmod +x "${REPO_DIR}/bin/${name}"
  ln -sfn "${REPO_DIR}/bin/${name}" "${BIN_DIR}/${name}"
  echo "linked ${BIN_DIR}/${name}"
done

if [[ ! -f "$HOME/.config/herdr/handy-mode" ]]; then
  printf 'herdr\n' >"$HOME/.config/herdr/handy-mode"
  echo "default mode: herdr (run handy-target to change)"
fi

HANDY_SETTINGS="${HOME}/Library/Application Support/com.pais.handy/settings_store.json"
if [[ -f "$HANDY_SETTINGS" ]]; then
  # Quit Handy first so it doesn't overwrite settings on exit
  if pgrep -xq Handy 2>/dev/null || pgrep -xq handy 2>/dev/null; then
    echo "note: quit Handy, then re-run install.sh if settings don't stick"
  fi
  /usr/bin/python3 - "$HANDY_SETTINGS" "${BIN_DIR}/handy-to-herdr" <<'PY'
import json, sys
from pathlib import Path
path, script = Path(sys.argv[1]), sys.argv[2]
data = json.loads(path.read_text())
settings = data.setdefault("settings", {})
settings["paste_method"] = "external_script"
settings["external_script_path"] = script
path.write_text(json.dumps(data, indent=2) + "\n")
print(f"configured Handy → {script}")
PY
else
  echo "Handy settings not found — set External Script manually to:"
  echo "  ${BIN_DIR}/handy-to-herdr"
fi

case ":$PATH:" in
  *":${BIN_DIR}:"*) ;;
  *)
    echo "add to PATH: export PATH=\"${BIN_DIR}:\$PATH\""
    ;;
esac

echo
echo "Next: reopen Handy, run: handy-target"
