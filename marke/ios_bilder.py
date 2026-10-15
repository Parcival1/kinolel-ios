#!/usr/bin/env python3
"""KinoLel-App (iOS): App-Symbol und Startlogo aus dem KinoLel-Logo (braucht Pillow, z. B. auf CT 103).
Nutzt die Zeichenfunktionen des Windows-Players (kinolel-player/marke/bilder_erzeugen.py).
Aufruf: python3 ios_bilder.py <repo> <pfad/zu/bilder_erzeugen.py> <banner-light.png>"""
import importlib.util
import json
import os
import sys

from PIL import Image

repo, modul, banner = sys.argv[1:4]
spec = importlib.util.spec_from_file_location('be', modul)
be = importlib.util.module_from_spec(spec)
spec.loader.exec_module(be)
marke = {'APP_NAME': 'KinoLel', 'APP_COLOR_ACCENT': '#9aa4ff', 'APP_COLOR_BACKGROUND': '#0b0f18'}
assets = os.path.join(repo, 'KinoLel', 'Assets.xcassets')


def json_schreiben(pfad, daten):
    os.makedirs(os.path.dirname(pfad), exist_ok=True)
    with open(pfad, 'w') as f:
        json.dump(daten, f, indent=2)


INFO = {'author': 'xcode', 'version': 1}
json_schreiben(os.path.join(assets, 'Contents.json'), {'info': INFO})

# App-Symbol: 1024 px, ohne Transparenz, volle Fläche (iOS rundet selbst ab)
symbol = be.hintergrund(1024, 1024, marke['APP_COLOR_BACKGROUND'])
symbol = be.mittig(symbol, be.logo_bild(700, akzent=be.farbe(marke['APP_COLOR_ACCENT'])))
os.makedirs(os.path.join(assets, 'AppIcon.appiconset'), exist_ok=True)
symbol.convert('RGB').save(os.path.join(assets, 'AppIcon.appiconset', 'AppIcon-1024.png'))
json_schreiben(os.path.join(assets, 'AppIcon.appiconset', 'Contents.json'), {
    'images': [{'filename': 'AppIcon-1024.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}],
    'info': INFO})

# Startlogo: Logo über Schriftzug (wie im Ladekreis), weiß, transparent; @1x/@2x/@3x (Basis 100 x 90 pt)
def startlogo(f):
    w, h = 100 * f, 90 * f
    bild = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    logo = be.logo_bild(72 * f, akzent=be.farbe(marke['APP_COLOR_ACCENT']))
    name = be.schriftzug(marke, 21 * f, banner, None)
    oben = (h - logo.height - 10 * f - name.height) // 2
    bild.alpha_composite(logo, ((w - logo.width) // 2, oben))
    bild.alpha_composite(name, ((w - name.width) // 2, oben + logo.height + 10 * f))
    return bild

ordner = os.path.join(assets, 'StartLogo.imageset')
os.makedirs(ordner, exist_ok=True)
bilder = []
for f in (1, 2, 3):
    datei = f'StartLogo@{f}x.png'
    startlogo(f).save(os.path.join(ordner, datei))
    bilder.append({'filename': datei, 'idiom': 'universal', 'scale': f'{f}x'})
json_schreiben(os.path.join(ordner, 'Contents.json'), {'images': bilder, 'info': INFO})

def farbe(name, hexwert):
    h = hexwert.lstrip('#')
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    json_schreiben(os.path.join(assets, f'{name}.colorset', 'Contents.json'), {
        'colors': [{'idiom': 'universal', 'color': {'color-space': 'srgb', 'components': {
            'red': f'{r:.3f}', 'green': f'{g:.3f}', 'blue': f'{b:.3f}', 'alpha': '1.000'}}}],
        'info': INFO})

farbe('Startgrund', marke['APP_COLOR_BACKGROUND'])
farbe('AccentColor', marke['APP_COLOR_ACCENT'])
symbol.convert('RGB').resize((256, 256), Image.LANCZOS).save(os.path.join(repo, 'marke', 'vorschau-symbol.png'))
print('fertig')
