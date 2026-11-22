import 'package:excel/excel.dart';

import '../engine/calculator.dart';
import '../engine/portfolio.dart';
import '../models/calculation.dart';
import '../models/result_row.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../utils/notes.dart';

/// One calculation to write as its own tab.
class SheetSource {
  const SheetSource(this.calculation, this.results);

  final Calculation calculation;
  final List<ScenarioResult> results;
}

enum _Kind { text, money, number, percent, date, days }

final _navy = ExcelColor.fromHexString('#1F3864');
final _teal = ExcelColor.fromHexString('#3B6978');
final _headerFill = ExcelColor.fromHexString('#E6EAF2');
final _inputFill = ExcelColor.fromHexString('#FFF8E1');
final _shadeFill = ExcelColor.fromHexString('#EEF1F7');
final _gain = ExcelColor.fromHexString('#1B7F3B');
final _loss = ExcelColor.fromHexString('#C62828');

NumFormat _format(_Kind kind) => switch (kind) {
  _Kind.money => NumFormat.custom(formatCode: '"₹"#,##0.00;-"₹"#,##0.00'),
  _Kind.number => NumFormat.custom(formatCode: '#,##0.##'),
  _Kind.percent => NumFormat.custom(formatCode: '0.00%'),
  _Kind.date => NumFormat.custom(formatCode: 'dd-mmm-yyyy'),
  _Kind.days => NumFormat.custom(formatCode: '0'),
  _Kind.text => NumFormat.standard_0,
};

/// Builds an .xlsx laid out like the original spreadsheet: one tab per
/// calculation, plus a "Combined" tab when [combined] is given.
List<int> buildWorkbook(
  List<SheetSource> sources, {
  PortfolioResult? combined,
  required DateTime generatedAt,
}) {
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet()!;
  final used = <String>{};
  var first = true;

  String tabName(String raw) {
    var base = raw.replaceAll(RegExp(r'[\[\]\*\?/\\:]'), ' ').trim();
    if (base.isEmpty) base = 'Calculation';
    if (base.length > 28) base = base.substring(0, 28).trim();
    var name = base;
    for (var n = 2; used.contains(name.toLowerCase()); n++) {
      name = '$base ($n)';
    }
    used.add(name.toLowerCase());
    return name;
  }

  Sheet newSheet(String raw) {
    final name = tabName(raw);
    if (first) {
      first = false;
      excel.rename(defaultSheet, name);
      excel.setDefaultSheet(name);
    }
    return excel[name];
  }

  if (combined != null) {
    _writeCombined(newSheet('Combined'), combined, generatedAt);
  }
  for (final s in sources) {
    _writeCalculation(newSheet(s.calculation.displayName), s, generatedAt);
  }
  return excel.encode()!;
}

class _Writer {
  _Writer(this.sheet);

  final Sheet sheet;
  int row = 0;

  void put(
    int col,
    Object? value, {
    _Kind kind = _Kind.text,
    CellStyle? style,
    ExcelColor? fill,
    bool bold = false,
    ExcelColor? color,
  }) {
    final CellValue? cell = switch (value) {
      null => null,
      DateTime d => DateCellValue(year: d.year, month: d.month, day: d.day),
      int i => IntCellValue(i),
      double d when d.isFinite => DoubleCellValue(d),
      double _ => TextCellValue('—'),
      _ => TextCellValue(value.toString()),
    };
    final isText = value is String || (value is double && !value.isFinite);
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
      cell,
      cellStyle:
          style ??
          CellStyle(
            bold: bold,
            backgroundColorHex: fill ?? ExcelColor.none,
            fontColorHex: color ?? ExcelColor.black,
            horizontalAlign: col == 0 || isText
                ? HorizontalAlign.Left
                : HorizontalAlign.Right,
            numberFormat: isText ? NumFormat.standard_0 : _format(kind),
          ),
    );
  }

  void banner(
    String text,
    int lastCol, {
    required ExcelColor fill,
    int fontSize = 12,
  }) {
    final style = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: fill,
      fontSize: fontSize,
    );
    for (var c = 0; c <= lastCol; c++) {
      put(c, c == 0 ? text : '', style: style);
    }
    row++;
  }

  void line(String text, {bool italic = false}) {
    put(
      0,
      text,
      style: CellStyle(italic: italic, textWrapping: TextWrapping.WrapText),
    );
    row++;
  }
}

void _writeCalculation(Sheet sheet, SheetSource source, DateTime generatedAt) {
  final calc = source.calculation;
  final results = source.results;
  final w = _Writer(sheet);
  final last = results.length;

  sheet.setColumnWidth(0, 52);
  for (var c = 1; c <= last; c++) {
    sheet.setColumnWidth(c, 24);
  }

  w.banner(
    'Indian Equity Share – Net Profit & Annualised Return Calculator',
    last,
    fill: _navy,
    fontSize: 14,
  );
  w.line(
    '${calc.displayName} · Charges: ${calc.autoCharges ? 'auto-calculated' : 'entered manually'} · '
    'Exported ${formatDate(generatedAt)} from Equity Calc. Values, not formulas.',
    italic: true,
  );
  w.row++;

  w.put(0, 'Scenario / Target Profile', bold: true, fill: _headerFill);
  for (final r in results) {
    w.put(
      r.index + 1,
      'Scenario ${r.index + 1} (${r.scenario.label})',
      bold: true,
      fill: _headerFill,
    );
  }
  w.row++;

  final inputRows = <(String, _Kind, Object? Function(ScenarioResult r))>[
    (
      'Share / company name',
      _Kind.text,
      (r) => r.inputs.shareName.isEmpty ? '' : r.inputs.shareName,
    ),
    ('NSE/BSE symbol', _Kind.text, (r) => r.inputs.symbol),
    ('Purchase date', _Kind.date, (r) => r.inputs.buyDate),
    ('Purchase price per share (₹)', _Kind.money, (r) => r.inputs.buyPrice),
    ('Quantity (shares)', _Kind.number, (r) => r.inputs.quantity),
    (
      'Purchase brokerage & charges (excl. STT) (₹)',
      _Kind.money,
      (r) => r.result.buyChargesExclStt,
    ),
    (
      'Purchase-side STT (non-deductible for tax) (₹)',
      _Kind.money,
      (r) => r.result.buyStt,
    ),
    ('Expected / actual selling date', _Kind.date, (r) => r.inputs.sellDate),
    ('Selling price per share (₹)', _Kind.money, (r) => r.inputs.sellPrice),
    ('Brokerage on sale (₹)', _Kind.money, (r) => r.inputs.sellBrokerage),
    (
      'Other selling charges (DP, exchange, GST) (₹)',
      _Kind.money,
      (r) => r.result.otherSellCharges,
    ),
    (
      'Selling-side STT (non-deductible for tax) (₹)',
      _Kind.money,
      (r) => r.result.sellStt,
    ),
    ('Exit load (%)', _Kind.percent, (r) => r.inputs.exitLoadPct / 100),
    (
      'STCG tax rate (%) (incl. cess)',
      _Kind.percent,
      (r) => r.inputs.stcgRatePct / 100,
    ),
    (
      'LTCG tax rate (%) (incl. cess)',
      _Kind.percent,
      (r) => r.inputs.ltcgRatePct / 100,
    ),
    (
      'LTCG exemption available (₹)',
      _Kind.money,
      (r) => r.inputs.ltcgExemption,
    ),
    (
      'Target annual return (%)',
      _Kind.percent,
      (r) => r.scenario.targetReturnPct / 100,
    ),
    ('Buy target (%)', _Kind.percent, (r) => r.inputs.buyTargetPct / 100),
  ];
  for (final (label, kind, value) in inputRows) {
    w.put(0, label);
    for (final r in results) {
      w.put(r.index + 1, value(r), kind: kind, fill: _inputFill);
    }
    w.row++;
  }

  w.row++;
  w.banner('CALCULATED RESULTS', last, fill: _teal);
  for (final row in ResultRow.values) {
    final fill = row.shaded ? _shadeFill : null;
    w.put(0, row.label, bold: row.bold, fill: fill);
    for (final r in results) {
      final (value, kind, signed) = r.hasInputs
          ? _resultValue(row, r.result)
          : ('—', _Kind.text, false);
      final color = signed && value is num
          ? (value < 0 ? _loss : (value > 0 ? _gain : null))
          : null;
      w.put(
        r.index + 1,
        value,
        kind: kind,
        bold: row.bold,
        fill: fill,
        color: color,
      );
    }
    w.row++;
  }

  w.row++;
  w.banner('IMPORTANT NOTES', last, fill: _teal);
  for (final (i, note) in importantNotes.indexed) {
    w.line('${i + 1}. $note');
  }
}

(Object?, _Kind, bool) _resultValue(
  ResultRow row,
  TradeResult r,
) => switch (row) {
  ResultRow.grossPurchase => (r.grossPurchaseValue, _Kind.money, false),
  ResultRow.buyCharges => (r.buyChargesExclStt, _Kind.money, false),
  ResultRow.buyStt => (r.buyStt, _Kind.money, false),
  ResultRow.totalInvestment => (r.totalInvestment, _Kind.money, false),
  ResultRow.grossSale => (r.grossSaleValue, _Kind.money, false),
  ResultRow.sellBrokerage => (r.sellBrokerage, _Kind.money, false),
  ResultRow.otherSellCharges => (r.otherSellCharges, _Kind.money, false),
  ResultRow.sellStt => (r.sellStt, _Kind.money, false),
  ResultRow.exitLoad => (r.exitLoad, _Kind.money, false),
  ResultRow.totalSellingCosts => (r.totalSellingCosts, _Kind.money, false),
  ResultRow.netSaleProceeds => (r.netSaleProceeds, _Kind.money, false),
  ResultRow.taxableGain => (r.taxableGain, _Kind.money, true),
  ResultRow.taxType => (
    '${r.isLongTerm ? 'LTCG' : 'STCG'} @ ${formatPlain(r.taxRatePct, maxDecimals: 2)}%',
    _Kind.text,
    false,
  ),
  ResultRow.tax => (r.tax, _Kind.money, false),
  ResultRow.netAfterTax => (r.netAfterTax, _Kind.money, false),
  ResultRow.netProfit => (r.netProfit, _Kind.money, true),
  ResultRow.netReturn => (r.netReturn, _Kind.percent, true),
  ResultRow.holdingDays => (r.holdingDays, _Kind.days, false),
  ResultRow.simpleAnnualised => (r.simpleAnnualised, _Kind.percent, true),
  ResultRow.cagr => (r.cagr, _Kind.percent, true),
  ResultRow.targetSimple => (r.targetPriceSimple ?? '—', _Kind.money, false),
  ResultRow.targetCagr => (r.targetPriceCagr ?? '—', _Kind.money, false),
  ResultRow.targetBuySimple => (
    r.targetBuyPriceSimple ?? '—',
    _Kind.money,
    false,
  ),
  ResultRow.targetBuyCagr => (r.targetBuyPriceCagr ?? '—', _Kind.money, false),
  ResultRow.dipBuyPrice => (r.dipBuyPrice ?? '—', _Kind.money, false),
  ResultRow.maxBuyPrice => (r.maxBuyPrice ?? '—', _Kind.money, false),
};

void _writeCombined(Sheet sheet, PortfolioResult p, DateTime generatedAt) {
  final w = _Writer(sheet);
  const headers = [
    'Share',
    'Scenario used',
    'Purchase date',
    'Selling date',
    'Total invested (₹)',
    'Net sale proceeds (₹)',
    'Charges incl. STT (₹)',
    'Gain / (loss) before tax (₹)',
    'Tax if taxed alone (₹)',
  ];
  const last = 8;
  sheet.setColumnWidth(0, 34);
  sheet.setColumnWidth(1, 26);
  for (var c = 2; c <= last; c++) {
    sheet.setColumnWidth(c, 20);
  }

  w.banner(
    'Combined view – ${p.items.length} share${p.items.length == 1 ? '' : 's'}',
    last,
    fill: _navy,
    fontSize: 14,
  );
  w.line(
    'Exported ${formatDate(generatedAt)} from Equity Calc. Losses are set off across shares.',
    italic: true,
  );
  w.row++;

  for (final (c, h) in headers.indexed) {
    w.put(c, h, bold: true, fill: _headerFill);
  }
  w.row++;
  for (final i in p.items) {
    final gain = i.result.taxableGain;
    w.put(0, i.name);
    w.put(1, i.scenarioLabel);
    w.put(2, i.inputs.buyDate, kind: _Kind.date);
    w.put(3, i.inputs.sellDate, kind: _Kind.date);
    w.put(4, i.result.totalInvestment, kind: _Kind.money);
    w.put(5, i.result.netSaleProceeds, kind: _Kind.money);
    w.put(6, i.charges, kind: _Kind.money);
    w.put(7, gain, kind: _Kind.money, color: gain < 0 ? _loss : _gain);
    w.put(8, i.result.tax, kind: _Kind.money);
    w.row++;
  }
  w.put(0, 'Total', bold: true, fill: _shadeFill);
  for (var c = 1; c <= 3; c++) {
    w.put(c, '', fill: _shadeFill);
  }
  w.put(4, p.invested, kind: _Kind.money, bold: true, fill: _shadeFill);
  w.put(5, p.netSaleProceeds, kind: _Kind.money, bold: true, fill: _shadeFill);
  w.put(6, p.charges, kind: _Kind.money, bold: true, fill: _shadeFill);
  w.put(7, p.grossGain, kind: _Kind.money, bold: true, fill: _shadeFill);
  w.put(8, p.standaloneTax, kind: _Kind.money, bold: true, fill: _shadeFill);
  w.row += 2;

  w.banner('COMBINED RESULT (LOSSES SET OFF)', last, fill: _teal);
  final rows = <(String, Object?, _Kind, bool)>[
    (
      'Net short-term gain / (loss) after set-off',
      p.stcgNet,
      _Kind.money,
      true,
    ),
    ('Net long-term gain / (loss) after set-off', p.ltcgNet, _Kind.money, true),
    ('LTCG exemption used', p.exemptionUsed, _Kind.money, false),
    ('STCG tax', p.stcgTax, _Kind.money, false),
    ('LTCG tax', p.ltcgTax, _Kind.money, false),
    ('Total tax', p.tax, _Kind.money, false),
    ('Tax saved by setting off losses', p.taxSavedBySetOff, _Kind.money, false),
    (
      'Net profit / (loss) after tax & all charges',
      p.netProfit,
      _Kind.money,
      true,
    ),
    ('Net return on total invested', p.netReturn, _Kind.percent, true),
    ('Annualised return (XIRR)', p.xirr ?? '—', _Kind.percent, true),
  ];
  for (final (label, value, kind, signed) in rows) {
    final color = signed && value is num
        ? (value < 0 ? _loss : (value > 0 ? _gain : null))
        : null;
    w.put(0, label, bold: signed);
    w.put(1, value, kind: kind, bold: signed, color: color);
    w.row++;
  }
}
