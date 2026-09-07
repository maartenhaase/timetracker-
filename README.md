# Maarten Time

Een kleine native macOS-tijdtracker voor Maarten, met Final Cut Pro-herkenning.

## Functies

- klanten en projecten
- taken per timer
- start/stop vanuit hoofdvenster en menubalk
- handmatig uren toevoegen
- CSV-export
- lokale JSON-opslag in `~/Library/Application Support/MaartenTimeTracker/`
- Final Cut Pro detecteren via de macOS Accessibility API
- Final Cut-label éénmalig koppelen aan klant/project/taak
- optioneel automatisch wisselen van timer
- Final Cut-activiteit onthouden om vergeten uren later toe te voegen

## Privacy

Er is geen account en geen server. De urenregistratie blijft lokaal op de Mac.
De Accessibility-toestemming wordt alleen gebruikt om zichtbare UI-labels uit Final Cut Pro te lezen.

## Installeren uit GitHub Actions

De workflow `.github/workflows/build-macos.yml` bouwt een universele Release-app voor Apple Silicon en Intel.
Het resultaat heet `Maarten-Time-macOS` en bevat `Maarten-Time.zip`.

De app is ad-hoc ondertekend, niet met een betaald Apple Developer ID. macOS kan daarom bij de eerste start melden dat de ontwikkelaar niet kan worden geverifieerd. Gebruik dan rechtermuisknop op de app > Open.

## Eerste Final Cut-test

1. Start Maarten Time.
2. Open het tabblad Final Cut.
3. Klik op **Vraag toestemming** en sta Maarten Time toe onder Systeeminstellingen > Privacy en beveiliging > Toegankelijkheid.
4. Open Final Cut Pro en klik in de gewenste timeline.
5. Bekijk **Beste herkenning** en **Ruwe labels die Final Cut prijsgeeft**.
6. Koppel een bruikbaar label één keer aan het juiste project en de taak `Montage`.
