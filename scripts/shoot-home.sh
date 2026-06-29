#!/usr/bin/env bash
# Capture a clean Home screenshot for the per-branch gallery.
# Usage: scripts/shoot-home.sh <label>   ->   docs/shots/<label>.png   (best effort)
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"
cd "$(dirname "$0")/.." || exit 0
LABEL="${1:-home}"
# Render the skin matching the label when it is a known aesthetic.
case "$LABEL" in glass|ocean|paper) export NEXT_PUBLIC_AESTHETIC="$LABEL";; esac
CHROME="/mnt/c/Program Files/Google/Chrome/Application/chrome.exe"
[ -x "$CHROME" ] || { echo "no chrome; skip shot"; exit 0; }

PORT=$(( 3400 + (RANDOM % 300) ))
npm run build >/dev/null 2>&1 || { echo "build failed; skip shot"; exit 0; }
npx next start -p "$PORT" >"/tmp/luminous-shoot-$PORT.log" 2>&1 &
SV=$!
for i in $(seq 1 40); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "http://localhost:$PORT/?shot=1" 2>/dev/null)" = "200" ] && break
  sleep 1
done

WIN="C:\\Users\\yuxua\\AppData\\Local\\Temp\\luminous-$LABEL.png"
WSL="/mnt/c/Users/yuxua/AppData/Local/Temp/luminous-$LABEL.png"
rm -f "$WSL"
"$CHROME" --headless --disable-gpu --hide-scrollbars --force-device-scale-factor=2 \
  --window-size=440,900 --virtual-time-budget=5000 \
  --user-data-dir="C:\\Users\\yuxua\\AppData\\Local\\Temp\\luminous-prof-$LABEL" \
  --screenshot="$WIN" "http://localhost:$PORT/?shot=1" >/dev/null 2>&1

kill -9 "$SV" >/dev/null 2>&1 || true
pkill -9 -f "next start -p $PORT" >/dev/null 2>&1 || true

mkdir -p docs/shots
if [ -f "$WSL" ]; then
  cp "$WSL" "docs/shots/$LABEL.png"
  echo "shot saved: docs/shots/$LABEL.png ($(stat -c%s "docs/shots/$LABEL.png") bytes)"
else
  echo "shot failed for $LABEL"
fi
