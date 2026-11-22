enum FieldKind { text, date, money, quantity, percent }

/// Every per-trade input. Scenarios can override any of these individually.
enum InputField {
  shareName('Share / company name', FieldKind.text),
  symbol('NSE/BSE symbol', FieldKind.text),
  buyDate('Purchase date', FieldKind.date),
  buyPrice('Purchase price per share', FieldKind.money),
  quantity('Quantity (shares)', FieldKind.quantity),
  buyCharges('Purchase brokerage & charges (excl. STT)', FieldKind.money),
  buyStt('Purchase-side STT', FieldKind.money),
  sellDate('Expected / actual selling date', FieldKind.date),
  sellPrice('Selling price per share', FieldKind.money),
  sellBrokerage('Brokerage on sale', FieldKind.money),
  otherSellCharges(
    'Other selling charges (DP, exchange, GST)',
    FieldKind.money,
  ),
  sellStt('Selling-side STT', FieldKind.money),
  exitLoadPct('Exit load', FieldKind.percent),
  stcgRatePct('STCG tax rate (incl. cess)', FieldKind.percent),
  ltcgRatePct('LTCG tax rate (incl. cess)', FieldKind.percent),
  ltcgExemption('LTCG exemption still available this year', FieldKind.money),
  buyTargetPct('Buy target', FieldKind.percent);

  const InputField(this.label, this.kind);

  final String label;
  final FieldKind kind;

  Object encode(Object value) => switch (kind) {
    FieldKind.date => _isoDate(value as DateTime),
    _ => value,
  };

  Object? decode(Object? raw) {
    if (raw == null) return null;
    return switch (kind) {
      FieldKind.text => raw.toString(),
      FieldKind.date => DateTime.tryParse(raw.toString()),
      _ => raw is num ? raw.toDouble() : double.tryParse(raw.toString()),
    };
  }

  static InputField? byName(String name) {
    for (final f in values) {
      if (f.name == name) return f;
    }
    return null;
  }
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
