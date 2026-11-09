# Kiesel

Kiesel ist eine Mac-App, die Geld nach dem Budget-Prinzip von YNAB verwaltet: Jeder Euro bekommt eine Aufgabe.
Sie soll YNAB und MoneyMoney ablösen, ein Budget für den ganzen Haushalt über iCloud teilen und Umsätze deutscher Banken direkt abrufen, auch über HBCI/FinTS.

Konzept und Ausbaustufen: [docs/konzept.md](docs/konzept.md).

## Aufbau

- `Sources/KieselCore`: Geld (ganze Cent), Monate, Datenmodell, Budgetregeln (`BudgetEngine`). Keine UI.
- `Sources/KieselApp`: SwiftUI-Oberfläche für macOS 14+ (Seitenleiste mit Konten, Budgettabelle, Monatsübersicht, Buchungslisten).
- `tools/`: Icon (`make-icon.swift`) und App-Bundle (`build-app.sh`).
- `Tests/KieselCoreTests`: Tests der Budgetregeln (Swift Testing).

## Starten

```sh
tools/build-app.sh      # baut build/Kiesel.app mit Icon
open build/Kiesel.app
```

Zum Entwickeln geht auch `swift run Kiesel` oder `open Package.swift` in Xcode (Schema Kiesel, ⌘R).
Die App zeigt im Moment Beispieldaten, gespeichert wird noch nichts.

## Testen

```sh
swift test
KIESEL_SNAPSHOT=/tmp swift run Kiesel   # rendert die Hauptansichten als PNG
```

`KIESEL_APPEARANCE=dark` rendert die Snapshots im dunklen Modus.

## Lizenz

GPL-3.0, siehe [LICENSE](LICENSE).
