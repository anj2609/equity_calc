import 'app_settings.dart';
import 'scenario.dart';
import 'trade_inputs.dart';

/// One saved calculation: shared trade inputs plus its scenarios.
class Calculation {
  const Calculation({
    required this.id,
    required this.name,
    required this.base,
    required this.scenarios,
    required this.autoCharges,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final TradeInputs base;
  final List<Scenario> scenarios;
  final bool autoCharges;
  final DateTime updatedAt;

  String get displayName {
    if (name.trim().isNotEmpty) return name.trim();
    if (base.shareName.trim().isNotEmpty) return base.shareName.trim();
    return 'Untitled calculation';
  }

  TradeInputs effectiveInputs(Scenario s) => base.withOverrides(s.overrides);

  Calculation copyWith({
    String? id,
    String? name,
    TradeInputs? base,
    List<Scenario>? scenarios,
    bool? autoCharges,
    DateTime? updatedAt,
  }) => Calculation(
    id: id ?? this.id,
    name: name ?? this.name,
    base: base ?? this.base,
    scenarios: scenarios ?? this.scenarios,
    autoCharges: autoCharges ?? this.autoCharges,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// A blank calculation seeded from the user's defaults: bought today,
  /// selling in a year.
  factory Calculation.fromDefaults(
    AppSettings s, {
    required String id,
    required List<String> scenarioIds,
  }) {
    final today = DateTime.now();
    return Calculation(
      id: id,
      name: '',
      base: defaultInputs(s, today),
      scenarios: [
        for (var k = 0; k < s.defaultTargets.length; k++)
          Scenario(id: scenarioIds[k], targetReturnPct: s.defaultTargets[k]),
      ],
      autoCharges: s.defaultAutoCharges,
      updatedAt: today,
    );
  }

  /// The example from the original spreadsheet, preloaded on first launch.
  factory Calculation.sample({
    required String id,
    required List<String> scenarioIds,
  }) {
    final date = DateTime(2026, 11, 20);
    return Calculation(
      id: id,
      name: 'Sample (from sheet)',
      base: TradeInputs(
        shareName: '',
        buyDate: date,
        buyPrice: 794.80,
        quantity: 10,
        buyCharges: 30,
        buyStt: 0,
        sellDate: date,
        sellPrice: 792,
        sellBrokerage: 40,
        otherSellCharges: 0,
        sellStt: 0,
        exitLoadPct: 0.05,
        stcgRatePct: 20.8,
        ltcgRatePct: 13,
        ltcgExemption: 125000,
      ),
      scenarios: [
        Scenario(id: scenarioIds[0], targetReturnPct: 10),
        Scenario(id: scenarioIds[1], targetReturnPct: 25),
        Scenario(id: scenarioIds[2], targetReturnPct: 50),
      ],
      autoCharges: false,
      updatedAt: DateTime.now(),
    );
  }

  static TradeInputs defaultInputs(AppSettings s, DateTime today) =>
      TradeInputs(
        shareName: '',
        buyDate: today,
        buyPrice: 0,
        quantity: 0,
        buyCharges: s.defaultBuyBrokerage,
        buyStt: 0,
        sellDate: DateTime(today.year + 1, today.month, today.day),
        sellPrice: 0,
        sellBrokerage: s.defaultSellBrokerage,
        otherSellCharges: 0,
        sellStt: 0,
        exitLoadPct: 0,
        stcgRatePct: double.parse(s.stcgEffectivePct.toStringAsFixed(4)),
        ltcgRatePct: double.parse(s.ltcgEffectivePct.toStringAsFixed(4)),
        ltcgExemption: s.ltcgExemption,
        buyTargetPct: s.defaultBuyTargetPct,
      );

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'base': base.toJson(),
    'scenarios': [for (final s in scenarios) s.toJson()],
    'autoCharges': autoCharges,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Calculation.fromJson(Map<String, dynamic> j, AppSettings s) =>
      Calculation(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? '',
        base: TradeInputs.fromJson(
          Map<String, dynamic>.from(j['base'] as Map),
          defaultInputs(s, DateTime.now()),
        ),
        scenarios: [
          for (final raw in (j['scenarios'] as List? ?? const []))
            Scenario.fromJson(Map<String, dynamic>.from(raw as Map)),
        ],
        autoCharges: (j['autoCharges'] as bool?) ?? false,
        updatedAt:
            DateTime.tryParse(j['updatedAt']?.toString() ?? '') ??
            DateTime.now(),
      );
}
