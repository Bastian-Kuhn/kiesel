# Kiesel: Konzept

Stand 2026-11-09. Ziel: YNAB und MoneyMoney ablösen. Kern ist das Budget-Prinzip
von YNAB, dazu der direkte Abruf deutscher Banken über HBCI/FinTS.

Entschieden (2026-11-09): **native Mac-App**, kein Webdienst. Ein
**Haushalt mit mehreren Personen** teilt ein Budget. Abgleich über iCloud,
kein eigener Server.

## 1. Technik

- **SwiftUI, macOS 14+.** Aufbau wie die Cairn-iOS-App
  (SwiftUI, SwiftData, Observation). Eine iPhone/iPad-App kann den Kern später
  mitnutzen.
- **`KieselCore`** (Swift-Paket): Geld, Monate, Datenmodell und die
  Budgetregeln als reine Funktionen über Werttypen. Keine UI, keine
  Persistenz, vollständig mit `swift test` geprüft.
- **`KieselApp`**: die Mac-Oberfläche.
- Geldbeträge immer als **ganze Cent (`Int`)**, nie `Double`.
- Monatsgrenzen in der Zeitzone Europe/Berlin, unabhängig von der Einstellung
  des Macs.

### Haushalt über iCloud

- Lokaler Speicher ist die Quelle der Wahrheit, alles geht offline.
- Teilen im Haushalt über **CloudKit mit geteilter Zone**: der Haushalt ist
  eine Zone, die anderen Personen werden per iCloud-Freigabe eingeladen. Jede
  Person braucht eine Apple-ID.
- SwiftData synchronisiert von sich aus nur in die private Datenbank, nicht in
  geteilte Zonen (Stand meines Wissens, vor dem Bau prüfen). Deshalb:
  **CKSyncEngine** (macOS 14+) mit eigenem Mapping auf die Werttypen aus
  `KieselCore`, oder Core Data mit `NSPersistentCloudKitContainer`, das
  geteilte Stores kann. Entscheidung in Stufe 2.
- Konflikte: Buchungen und Zuweisungen sind eigene Datensätze, gleichzeitiges
  Arbeiten an verschiedenen Buchungen kollidiert nicht. Zuweisung einer
  Kategorie im selben Monat: letzte Änderung gewinnt.
- Für iCloud und Signierung braucht das Xcode-Projekt ein Apple-Developer-Team.

## 2. Budget-Prinzip (YNAB)

Umgesetzt in `BudgetEngine`, mit Tests:

- **Jeder Euro bekommt eine Aufgabe.** Eingänge landen in „Zu verteilen“. Von
  dort weist man Geld Kategorien zu, bis „Zu verteilen“ null ist. Zuweisungen
  in künftige Monate mindern „Zu verteilen“ schon jetzt.
- Pro Monat und Kategorie: **zugewiesen**, **Aktivität**, **verfügbar** =
  Übertrag + zugewiesen + Aktivität.
- Positives „verfügbar“ rollt in den Folgemonat. Überzogenes Bargeld rollt
  nicht: die Kategorie startet bei null, das Minus wird im Folgemonat von „Zu
  verteilen“ abgezogen.
- **Trackingkonten** (Depot, Kredit) zählen nur ins Vermögen. **Umbuchungen**
  zwischen Budgetkonten sind budgetneutral.
- **Splits**: eine Buchung auf mehrere Kategorien.
- **Ohne Kategorie**: frisch importierte Buchungen, als Aufgabe angezeigt.

Noch offen:

- **Kreditkarten:** eine Ausgabe auf der Karte verschiebt das Geld aus der
  Kategorie in die Zahlungskategorie der Karte.
- **Ziele** je Kategorie: monatlicher Betrag, Zielsumme bis Datum, Polster.
- **Abgleich:** Saldo der Bank gegen Saldo in Kiesel, Differenz als
  Ausgleichsbuchung, abgeglichene Buchungen gesperrt.
- **Regeln:** Muster auf Gegenpartei/Verwendungszweck → Kategorie, aus
  manueller Zuordnung gelernt.

## 3. Banken: HBCI/FinTS

- Eine Swift-Bibliothek für FinTS mit geprüfter Lizenz habe ich nicht gefunden
  (HBCI4Swift aus Pecunia ist nicht geprüft).
- Plan: **python-fints** (LGPL-3.0, FinTS 3.0, PIN/TAN, PSD2 mit
  entkoppelter Freigabe wie pushTAN/App-Freigabe, chipTAN/photoTAN als
  Challenge) als **Hilfsprozess**, mitgeliefert in der App (eigenständiges
  Python im Bundle). Die App spricht mit ihm über JSON auf stdin/stdout:
  Abruf starten, TAN-Challenge zurück, TAN oder Freigabe hin, Umsätze und
  Salden zurück. LGPL ist so ohne Änderung der Bibliothek unproblematisch.
- Später kann ein eigener FinTS-Client in Swift den Hilfsprozess ersetzen,
  das Protokoll zur App bleibt gleich.
- **FinTS-Produktregistrierung** bei der Deutschen Kreditwirtschaft ist
  Pflicht, ohne Produkt-Id lehnen viele Banken ab. Kostenlos, beantragt der
  Inhaber.
- **PIN nie speichern**, nur pro Abruf abfragen (optional im Schlüsselbund,
  wenn ausdrücklich gewünscht). Bankzugänge sind pro Person, nicht pro
  Haushalt: Umsätze werden geteilt, Zugangsdaten nicht.
- Dubletten über eine Import-Id aus den Bankdaten.
- Banken ohne FinTS: CSV- und CAMT-Import.

## 4. Umstieg

- **YNAB:** Export (Budget- und Register-CSV) mit Kategorien, Zuweisungen pro
  Monat und Buchungen.
- **MoneyMoney:** CSV/XML-Export.

## 5. Ausbaustufen

1. **Erledigt:** `KieselCore` mit Budgetregeln, Zielen pro Monat und Tests.
   Mac-Oberfläche mit Seitenleiste (Konten, Salden), Budgettabelle (Gruppen,
   Fortschrittsbalken, Status, Filter), Monatsübersicht und Buchungslisten,
   mit Beispieldaten. Icon und `Kiesel.app`-Bundle (`tools/build-app.sh`).
2. Xcode-Projekt mit Signierung, lokaler Speicher, Haushalt über iCloud.
3. Konten und Buchungen in der Oberfläche, CSV- und YNAB-Import, Regeln.
4. FinTS-Hilfsprozess mit TAN-Freigabe, Abgleich.
5. Kreditkarten, Ziele, Berichte (Ausgaben nach Kategorie, Vermögen).
6. iPhone/iPad.

## Lizenz

Open Source unter **GPL-3.0**, öffentlich auf GitHub.
Verträgt sich mit python-fints (LGPL-3.0). HBCI4Swift (GPL-2.0) ginge nur,
wenn seine Dateien „or any later version“ erlauben; vor einem Einsatz prüfen.

## Offen

- Apple-Developer-Team für Signierung und iCloud-Container.
- FinTS-Produktregistrierung beantragen.
