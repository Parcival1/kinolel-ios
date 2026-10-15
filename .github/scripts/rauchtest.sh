#!/bin/bash
# KinoLel-App (iOS): Rauchtest im Simulator – installieren, starten, Bildschirmfotos (Startbild, Anmeldung
# von kinolel.de), Ungarisch, App in den Hintergrund und zurück.
set -x
APP=$1
mkdir -p rauchtest
GERAET=$(xcrun simctl list devices available -j | python3 -c '
import json,sys
d=json.load(sys.stdin)["devices"]
for laufzeit in sorted(d, reverse=True):
    if "iOS" not in laufzeit: continue
    for g in d[laufzeit]:
        if g["name"].startswith("iPhone"):
            print(g["udid"]); sys.exit()')
echo "Simulator: $GERAET"
xcrun simctl boot "$GERAET"
xcrun simctl bootstatus "$GERAET" -b
xcrun simctl install "$GERAET" "$APP"
xcrun simctl launch "$GERAET" de.kinolel.app
sleep 3;  xcrun simctl io "$GERAET" screenshot rauchtest/01-start-3s.png
sleep 27; xcrun simctl io "$GERAET" screenshot rauchtest/02-nach-30s.png
# Hintergrund (Startbildschirm) und zurück: App muss weiterlaufen und die Seite behalten
xcrun simctl launch "$GERAET" com.apple.Preferences
sleep 5; xcrun simctl launch "$GERAET" de.kinolel.app
sleep 5; xcrun simctl io "$GERAET" screenshot rauchtest/03-zurueck-aus-hintergrund.png
# Ungarisch
xcrun simctl terminate "$GERAET" de.kinolel.app
xcrun simctl launch "$GERAET" de.kinolel.app -AppleLanguages "(hu)" -AppleLocale hu_HU
sleep 30; xcrun simctl io "$GERAET" screenshot rauchtest/04-ungarisch-30s.png
xcrun simctl spawn "$GERAET" log show --last 5m --predicate 'process == "KinoLel"' --style compact > rauchtest/log.txt 2>&1 || true
ls -la rauchtest
exit 0
