#!/bin/bash
# KinoLel-App (iOS): Oberflächentests im Simulator (XCUITest, KinoLelUITests):
#  - „Was ist neu“ einmalig nach einem Update (de/en/hu), Start ohne Internet, Download-Liste
#  - mit dem Secret KINOLEL_TEST_PW zusätzlich: Download „Klein“, Wiedergabe ohne Internet, Nachmelden der Position,
#    Löschen, Abmelden. Das Kennwort geht nur über die Testumgebung (TEST_RUNNER_…) an die App, nie in Logs.
# Ergebnis: oberflaeche/ (Protokoll, Ablauf der App, Bildschirmfotos) + Zusammenfassung im Lauf.
set -u
mkdir -p oberflaeche
GERAET=$(xcrun simctl list devices available -j | python3 -c '
import json,sys
d=json.load(sys.stdin)["devices"]
for laufzeit in sorted(d, reverse=True):
    if "iOS" not in laufzeit: continue
    for g in d[laufzeit]:
        if g["name"].startswith("iPhone"):
            print(g["udid"]); sys.exit()')
echo "Simulator: $GERAET"
xcrun simctl boot "$GERAET" 2>/dev/null || true
xcrun simctl bootstatus "$GERAET" -b >/dev/null

xcodebuild test -project KinoLel.xcodeproj -scheme KinoLel -destination "id=$GERAET" -derivedDataPath build/test \
  -resultBundlePath oberflaeche/ergebnis.xcresult CODE_SIGN_IDENTITY="-" > oberflaeche/xcodebuild.log 2>&1
status=$?
grep -E "Test Case|error:|XCTAssert|Skipped|skipped|\*\* TEST" oberflaeche/xcodebuild.log | tail -60

# Ablauf aus Sicht der App (NSLog im Systemprotokoll des Simulators)
xcrun simctl spawn "$GERAET" log show --last 90m --style compact --predicate 'process == "KinoLel"' > oberflaeche/log.txt 2>&1 || true
grep -E "KinoLel-Test:|KinoLel-Offline|KinoLel-Downloads|spiele Download|Player bereit|Player-Fehler|Was ist neu|Nachricht vom Server|Befehl video" \
  oberflaeche/log.txt | sed -E 's/^.*(KinoLel)/\1/' > oberflaeche/ablauf.txt
echo "--- Ablauf der App ---"
cat oberflaeche/ablauf.txt

pruefung=""
if grep -q "KinoLel-Test: angemeldet" oberflaeche/ablauf.txt; then
  for muster in "KinoLel-Downloads: [0-9a-f]+ fertig" \
                "Fernsteuerung: Sitzung fernsteuerbar=true" "Befehl video.play" "spiele Download [0-9a-f]+ aus der Datei" \
                "Befehl video.pause" "Nachricht vom Server über dem Player" "Befehl video.unpause" "Befehl video.seek" \
                "Befehl video.stop" "Fernsteuerung fertig" \
                "spiele Download [0-9a-f]+ offline" "Player bereit" \
                "Position von [0-9a-f]+ gemeldet" "Serverposition [1-9]" "gelöscht" "KinoLel-Test: abgemeldet"; do
    if grep -Eq "$muster" oberflaeche/ablauf.txt; then pruefung+="- OK: \`$muster\`"$'\n'
    else pruefung+="- FEHLT: \`$muster\`"$'\n'; status=1; fi
  done
else
  pruefung="- Download-Test ohne Anmeldung (Secret KINOLEL_TEST_PW fehlt?) – übersprungen"$'\n'
fi
echo "$pruefung"

# Bildschirmfotos aus dem Ergebnis
xcrun xcresulttool export attachments --path oberflaeche/ergebnis.xcresult --output-path oberflaeche/bilder >/dev/null 2>&1 || true
ls oberflaeche/bilder 2>/dev/null | head -40

{
  echo "## Oberflächentests im Simulator"
  grep -E "Test Case .* (passed|failed|skipped)" oberflaeche/xcodebuild.log | sed -E 's/^.*Test Case/- Test Case/'
  echo
  echo "$pruefung"
  echo '```'
  cat oberflaeche/ablauf.txt
  echo '```'
} >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
exit $status
