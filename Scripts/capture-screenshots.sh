#!/bin/bash
# Store-Screenshots für alle Gerätefamilien und Sprachen.
#
# Die Zustände werden über Debug-Startargumente hergestellt (-prefill,
# -with-notes, -show-hint), nicht durch Tippen — sonst wären es hunderte
# Einzelschritte pro Sprache. Siehe AppModel.stageForScreenshot.
#
#   ./Scripts/capture-screenshots.sh [Zielordner]
#
# Voraussetzung: Xcode, die Simulatoren unten, und für den Mac ein Bildschirm
# mit 2× Auflösung (das Fenster wird mit 1800×1440 aufgenommen und zentriert auf
# eine deckende 2880×1800-Leinwand gesetzt).
set -euo pipefail

OUT="${1:-$HOME/Developer/Sudoku-Screenshots}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LANGS=(de en it)
IPHONE="iPhone 17 Pro Max"      # 6,9" → 1320 × 2868
IPAD="iPad Pro 13-inch (M5)"    # 13"  → 2064 × 2752
TV="Apple TV 4K (3rd generation)"

mkdir -p "$OUT"
DERIVED="$ROOT/build/screenshots"

echo "→ baue"
xcodebuild -project "$ROOT/App/Sudoku.xcodeproj" -scheme Sudoku \
  -destination "platform=iOS Simulator,name=$IPHONE" -configuration Debug \
  -derivedDataPath "$DERIVED" build >/dev/null
xcodebuild -project "$ROOT/App/Sudoku.xcodeproj" -scheme Sudoku \
  -destination "platform=tvOS Simulator,name=$TV" -configuration Debug \
  -derivedDataPath "$DERIVED" build >/dev/null
xcodebuild -project "$ROOT/App/Sudoku.xcodeproj" -scheme Sudoku \
  -destination 'platform=macOS' -configuration Debug \
  -derivedDataPath "$DERIVED" build >/dev/null

udid_for() { xcrun simctl list devices available | grep -F "$1 (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'; }

capture_simulator() {  # $1 Gerätename, $2 Präfix, $3 App-Pfad, $4 "mit-punkte"
  local udid; udid="$(udid_for "$1")"
  [ -z "$udid" ] && { echo "  Simulator fehlt: $1"; return; }
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || true
  xcrun simctl install "$udid" "$3"
  xcrun simctl status_bar "$udid" override --time 9:41 --batteryState charged \
    --batteryLevel 100 --wifiBars 3 2>/dev/null || true

  local motifs=(1-brett 2-hinweis 3-stufen)
  [ "$4" = "mit-punkte" ] && motifs+=(4-punkte)

  for lang in "${LANGS[@]}"; do
    for motif in "${motifs[@]}"; do
      local args=(-skip-onboarding)
      case "$motif" in
        1-brett)   args+=(-open-game hard -prefill 22 -with-notes) ;;
        2-hinweis) args+=(-open-game hard -prefill 22 -with-notes -show-hint) ;;
        3-stufen)  ;;
        4-punkte)  args+=(-open-game hard -prefill 81) ;;
      esac
      xcrun simctl terminate "$udid" com.hellweger.sudoku.app 2>/dev/null || true
      sleep 1
      xcrun simctl launch "$udid" com.hellweger.sudoku.app \
        -AppleLanguages "($lang)" -AppleLocale "$lang" "${args[@]}" >/dev/null
      sleep 6
      xcrun simctl io "$udid" screenshot "$OUT/$2-$lang-$motif.png" >/dev/null 2>&1
    done
  done
  xcrun simctl shutdown "$udid" 2>/dev/null || true
}

echo "→ iPhone"; capture_simulator "$IPHONE" iphone69 "$DERIVED/Build/Products/Debug-iphonesimulator/Sudoku.app" mit-punkte
echo "→ iPad";   capture_simulator "$IPAD"   ipad13   "$DERIVED/Build/Products/Debug-iphonesimulator/Sudoku.app" mit-punkte
echo "→ Apple TV"; echo "   (braucht ein offenes Simulator-Fenster, sonst gibt es keinen Bildpuffer)"
open -a Simulator; sleep 10
capture_simulator "$TV" appletv "$DERIVED/Build/Products/Debug-appletvsimulator/Sudoku.app" ohne

echo "→ Mac"
MACAPP="$DERIVED/Build/Products/Debug/Sudoku.app"
for lang in "${LANGS[@]}"; do
  for motif in 1-brett 2-hinweis 3-stufen 4-punkte; do
    args=(-skip-onboarding)
    case "$motif" in
      1-brett)   args+=(-open-game hard -prefill 22 -with-notes) ;;
      2-hinweis) args+=(-open-game hard -prefill 22 -with-notes -show-hint) ;;
      3-stufen)  ;;
      4-punkte)  args+=(-open-game hard -prefill 81) ;;
    esac
    pkill -x Sudoku 2>/dev/null || true; sleep 3
    open "$MACAPP" --args -AppleLanguages "($lang)" -AppleLocale "$lang" "${args[@]}"
    sleep 9
    id="$(swift "$ROOT/Scripts/window-id.swift" Sudoku | head -1 | cut -d' ' -f1)"
    [ -z "$id" ] && { echo "   kein Fenster für $lang/$motif"; continue; }
    screencapture -o -l "$id" /tmp/sudoku-mac-raw.png
    swift "$ROOT/Scripts/compose-screenshot.swift" \
      /tmp/sudoku-mac-raw.png "$OUT/mac-$lang-$motif.png" 2880 1800 >/dev/null
  done
done
pkill -x Sudoku 2>/dev/null || true

echo "→ Alphakanal entfernen (App Store Connect weist Bilder mit Alpha zurück)"
swift "$ROOT/Scripts/compose-screenshot.swift" --flatten "$OUT"/*.png

echo
echo "Fertig: $(ls "$OUT"/*.png | wc -l | tr -d ' ') Bilder in $OUT"
