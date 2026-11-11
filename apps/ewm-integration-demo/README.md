# SAP CAP EWM Integration Demo

Eine kleine, read-only SAP Cloud Application Programming Model (CAP) Demo mit simulierten Wareneingängen. Der Service stellt die Testdaten lokal über OData V4 bereit. Es gibt keine Verbindung zu einem echten SAP-EWM-System und keine BTP-Bereitstellung.

## CAP, CDS und OData V4

- **CAP** ist SAPs Entwicklungsmodell für Geschäftsservices und Datenmodelle.
- **CDS** beschreibt in dieser Anwendung die Wareneingangsdaten und den darauf basierenden Service.
- **OData V4** stellt die Daten als standardisierte HTTP-Schnittstelle mit Filter-, Auswahl- und Begrenzungsoptionen bereit.

Die Anwendung bildet einen vereinfachten SAP-EWM-Wareneingangsprozess ausschließlich mit statischen, simulierten CSV-Daten ab. SQLite läuft lokal im Arbeitsspeicher; es wird kein externer Datenbank- oder Cloud-Service benötigt.

## Voraussetzungen und Installation

- Node.js `>=22.12`
- npm

Im VS Code Terminal:

```bash
cd apps/ewm-integration-demo
npm ci
```

`package-lock.json` hält die geprüften Abhängigkeiten fest. Für eine Installation ohne Lockdatei kann `npm install` verwendet werden.

## Lokal starten

Im VS Code Terminal:

```bash
cd apps/ewm-integration-demo
npm start
```

CAP startet im Entwicklungsmodus, lädt die CSV-Daten in die lokale SQLite-Datenbank und stellt den Service unter `http://localhost:4004/odata/v4/warehouse` bereit. Mit `Ctrl+C` wird der Server beendet.

## OData-Beispiele

Alle Wareneingänge:

```bash
curl 'http://localhost:4004/odata/v4/warehouse/GoodsReceipts'
```

Nur Wareneingänge aus Lager `WH-100`:

```bash
curl --get 'http://localhost:4004/odata/v4/warehouse/GoodsReceipts' \
  --data-urlencode "\$filter=warehouse eq 'WH-100'"
```

Nur Material und Menge zurückgeben:

```bash
curl --get 'http://localhost:4004/odata/v4/warehouse/GoodsReceipts' \
  --data-urlencode '$select=material,quantity'
```

OData behält den Schlüssel `ID` in der Antwort bei, auch wenn er nicht ausdrücklich in `$select` aufgeführt ist.

Auf zwei Datensätze begrenzen:

```bash
curl --get 'http://localhost:4004/odata/v4/warehouse/GoodsReceipts' \
  --data-urlencode '$top=2'
```

Die Collection ist read-only. CAP weist Schreibzugriffe auf `GoodsReceipts` zurück.

## Datenmodell

| Feld | Typ | Bedeutung |
|---|---|---|
| `ID` | UUID | Schlüssel des simulierten Wareneingangs |
| `material` | String(40) | Materialnummer |
| `warehouse` | String(20) | Lagerkennung |
| `quantity` | Integer | Eingegangene Menge |
| `unit` | String(3) | Mengeneinheit |
| `status` | String(20) | Simulierter Bearbeitungsstatus |
| `receivedAt` | Timestamp | Simulierter Eingangszeitpunkt |

Die Seed-Daten liegen in `db/data/ewm-GoodsReceipts.csv`.

## Tests

```bash
npm test
```

Die automatisierten Node.js-Tests starten einen lokalen CAP-Prozess mit SQLite und senden echte HTTP-Anfragen an dessen OData-V4-Endpunkt. Geprüft werden GET, `$filter`, `$select`, `$top` sowie die Ablehnung eines POST-Schreibzugriffs. Der Testprozess wird nach der Ausführung beendet; es bleibt kein Serverprozess laufen.

## Architektur und Integrationsgrenzen

OData V4 bietet eine standardisierte Schnittstelle für SAP- und Non-SAP-Clients. In einer späteren Ausbaustufe könnte SAP Integration Suite Nachrichten aus einem Quellsystem entgegennehmen, transformieren und an einen produktiven CAP-Service weiterleiten. Die Suite und eine solche Verbindung sind hier **nicht** eingerichtet.

**Umgesetzt:** lokales CAP-Modell und Service, OData-V4-Lesezugriff, CSV-Testdaten, SQLite und HTTP-Integrationstests.

**Nicht umgesetzt:** echte SAP-EWM-Integration, BTP-Deployment, produktive Authentifizierung oder Autorisierung, SAP Integration Suite und Azure-Ressourcen.
