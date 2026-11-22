# Equity Calc

A Flutter app for Indian equity trades: net profit after charges and tax, annualised returns, and the prices you need to hit a target return. It started as a spreadsheet and reproduces its numbers exactly.

## Features

- **Scenarios**: enter a trade once and compare several target returns (10%, 25%, 50% by default). Any field can be changed for one scenario only.
- **Net profit after everything**: brokerage, STT (not deductible for tax), exchange/SEBI/DP charges, GST, exit load, and capital gains tax.
- **Tax**: STCG (20% + 4% cess) up to 12 months, LTCG (12.5% + 4% cess) after, with the ₹1.25 lakh exemption. All rates editable.
- **Target prices**: selling price and buying price for each scenario's yearly target (simple and CAGR basis), plus a Quick check for any return, total or per year.
- **Buy targets**: buy-on-a-dip price and the highest price that still earns a chosen return.
- **Live prices**: search NSE/BSE symbols and fetch the latest price (Yahoo Finance, may be delayed).
- **Auto charges**: optional calculation of STT, stamp duty, exchange, SEBI, DP and GST from editable rates.
- **Combine shares**: overall profit across several trades, with losses set off under Indian rules and XIRR.
- **Excel export**: `.xlsx` in the original sheet's layout, one tab per share plus a Combined tab.
- **Saving**: nothing is stored until you tap Save; you are asked before unsaved changes are discarded.

## Run

```bash
flutter pub get
flutter run
```

Build an Android APK:

```bash
flutter build apk --release
```

The release build is signed with the debug key, which is fine for installing on your own device. Set up a release keystore before publishing to the Play Store.

## Tests

```bash
flutter test
```

The engine tests check every value from the original spreadsheet, tax set-off across shares, target price solving and the Excel export.

## Project layout

- `lib/engine/`: calculations (`calculator.dart`) and combined view (`portfolio.dart`), pure Dart
- `lib/models/`: inputs, scenarios, calculations, settings
- `lib/state/`: app state and storage
- `lib/services/`: live price lookup
- `lib/export/`: Excel workbook builder
- `lib/ui/`: screens and widgets

## Disclaimer

Estimates only, not tax or investment advice. Charges and tax rules change; check your contract note and current rules.
