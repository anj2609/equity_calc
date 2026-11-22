import 'input_field.dart';

/// One complete set of trade inputs. Stored as a field map so that scenario
/// overrides can be layered on top generically.
class TradeInputs {
  TradeInputs._(Map<InputField, Object> values)
    : _values = Map.unmodifiable(values);

  factory TradeInputs({
    required String shareName,
    required DateTime buyDate,
    required double buyPrice,
    required double quantity,
    required double buyCharges,
    required double buyStt,
    required DateTime sellDate,
    required double sellPrice,
    required double sellBrokerage,
    required double otherSellCharges,
    required double sellStt,
    required double exitLoadPct,
    required double stcgRatePct,
    required double ltcgRatePct,
    required double ltcgExemption,
    String symbol = '',
    double buyTargetPct = 5,
  }) => TradeInputs._({
    InputField.shareName: shareName,
    InputField.buyDate: dateOnly(buyDate),
    InputField.buyPrice: buyPrice,
    InputField.quantity: quantity,
    InputField.buyCharges: buyCharges,
    InputField.buyStt: buyStt,
    InputField.sellDate: dateOnly(sellDate),
    InputField.sellPrice: sellPrice,
    InputField.sellBrokerage: sellBrokerage,
    InputField.otherSellCharges: otherSellCharges,
    InputField.sellStt: sellStt,
    InputField.exitLoadPct: exitLoadPct,
    InputField.stcgRatePct: stcgRatePct,
    InputField.ltcgRatePct: ltcgRatePct,
    InputField.ltcgExemption: ltcgExemption,
    InputField.symbol: symbol,
    InputField.buyTargetPct: buyTargetPct,
  });

  final Map<InputField, Object> _values;

  String get shareName => _values[InputField.shareName] as String;
  String get symbol => _values[InputField.symbol] as String;
  DateTime get buyDate => _values[InputField.buyDate] as DateTime;
  double get buyPrice => _num(InputField.buyPrice);
  double get quantity => _num(InputField.quantity);
  double get buyCharges => _num(InputField.buyCharges);
  double get buyStt => _num(InputField.buyStt);
  DateTime get sellDate => _values[InputField.sellDate] as DateTime;
  double get sellPrice => _num(InputField.sellPrice);
  double get sellBrokerage => _num(InputField.sellBrokerage);
  double get otherSellCharges => _num(InputField.otherSellCharges);
  double get sellStt => _num(InputField.sellStt);
  double get exitLoadPct => _num(InputField.exitLoadPct);
  double get stcgRatePct => _num(InputField.stcgRatePct);
  double get ltcgRatePct => _num(InputField.ltcgRatePct);
  double get ltcgExemption => _num(InputField.ltcgExemption);
  double get buyTargetPct => _num(InputField.buyTargetPct);

  double _num(InputField f) => _values[f] as double;

  Object valueOf(InputField f) => _values[f]!;

  TradeInputs withValue(InputField f, Object value) =>
      TradeInputs._({..._values, f: _normalise(f, value)});

  TradeInputs withOverrides(Map<InputField, Object> overrides) =>
      overrides.isEmpty
      ? this
      : TradeInputs._({
          ..._values,
          for (final e in overrides.entries) e.key: _normalise(e.key, e.value),
        });

  Map<String, Object> toJson() => {
    for (final e in _values.entries) e.key.name: e.key.encode(e.value),
  };

  /// Missing or malformed fields fall back to [fallback].
  factory TradeInputs.fromJson(
    Map<String, dynamic> json,
    TradeInputs fallback,
  ) {
    final values = Map<InputField, Object>.of(fallback._values);
    for (final f in InputField.values) {
      final v = f.decode(json[f.name]);
      if (v != null) values[f] = _normalise(f, v);
    }
    return TradeInputs._(values);
  }

  static Object _normalise(InputField f, Object value) => switch (f.kind) {
    FieldKind.date => dateOnly(value as DateTime),
    FieldKind.text => value as String,
    _ => (value as num).toDouble(),
  };
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
