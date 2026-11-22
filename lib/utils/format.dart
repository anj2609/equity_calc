import 'package:intl/intl.dart';

final _money = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);
final _grouped2 = NumberFormat('#,##,##0.00', 'en_IN');
final _date = DateFormat('dd-MMM-yyyy');
final _dateTime = DateFormat('d MMM, h:mm a');

double _clean(double v) => v.abs() < 0.005 ? 0 : v;

/// ₹ with Indian lakh/crore grouping, e.g. ₹1,23,456.50.
String formatMoney(double? v) {
  if (v == null || !v.isFinite) return '—';
  return _money.format(_clean(v));
}

/// [fraction] 0.1234 -> "12.34%".
String formatPercent(double? fraction) {
  if (fraction == null || fraction.isNaN) return '—';
  final pct = fraction * 100;
  if (!pct.isFinite || pct.abs() >= 1e9) {
    return pct > 0 ? '> 1,00,00,00,000%' : '< -1,00,00,00,000%';
  }
  return '${_grouped2.format(_clean(pct))}%';
}

String formatDate(DateTime d) => _date.format(d);

String formatDateTime(DateTime d) => _dateTime.format(d);

/// Up to [maxDecimals], trailing zeros trimmed: 12.50 -> "12.5", 10 -> "10".
String formatPlain(double v, {int maxDecimals = 4}) {
  var s = v.toStringAsFixed(maxDecimals);
  if (s.contains('.')) s = s.replaceFirst(RegExp(r'\.?0+$'), '');
  return s == '-0' ? '0' : s;
}

/// Text shown in an editable money field: grouped, 2 decimals.
String formatMoneyInput(double v) => _grouped2.format(v);

/// Accepts "1,23,456.50", "₹ 794.8", "20.8%". Returns null when empty or invalid.
double? parseNumber(String s) {
  final cleaned = s.replaceAll(RegExp(r'[,₹%\s]'), '');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}
