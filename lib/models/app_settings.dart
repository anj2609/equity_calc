import 'package:flutter/material.dart';

import 'charge_rates.dart';
import 'result_row.dart';

/// App-wide preferences. Tax rates and brokerage here seed new calculations;
/// existing calculations keep their own values.
class AppSettings {
  const AppSettings({
    this.stcgBasePct = 20,
    this.ltcgBasePct = 12.5,
    this.surchargePct = 0,
    this.cessPct = 4,
    this.ltcgExemption = 125000,
    this.longTermMonths = 12,
    this.daysInYear = 365,
    this.defaultBuyBrokerage = 30,
    this.defaultSellBrokerage = 40,
    this.defaultTargets = const [10, 25, 50],
    this.defaultAutoCharges = false,
    this.defaultBuyTargetPct = 5,
    this.chargeRates = const ChargeRates(),
    this.hiddenRows = const {},
    this.themeMode = ThemeMode.system,
  });

  final double stcgBasePct;
  final double ltcgBasePct;
  final double surchargePct;
  final double cessPct;
  final double ltcgExemption;
  final int longTermMonths;
  final int daysInYear;
  final double defaultBuyBrokerage;
  final double defaultSellBrokerage;
  final List<double> defaultTargets;
  final bool defaultAutoCharges;
  final double defaultBuyTargetPct;
  final ChargeRates chargeRates;
  final Set<ResultRow> hiddenRows;
  final ThemeMode themeMode;

  static AppSettings get initial =>
      AppSettings(hiddenRows: ResultRow.defaultHidden);

  double _effective(double base) =>
      base * (1 + surchargePct / 100) * (1 + cessPct / 100);
  double get stcgEffectivePct => _effective(stcgBasePct);
  double get ltcgEffectivePct => _effective(ltcgBasePct);

  AppSettings copyWith({
    double? stcgBasePct,
    double? ltcgBasePct,
    double? surchargePct,
    double? cessPct,
    double? ltcgExemption,
    int? longTermMonths,
    int? daysInYear,
    double? defaultBuyBrokerage,
    double? defaultSellBrokerage,
    List<double>? defaultTargets,
    bool? defaultAutoCharges,
    double? defaultBuyTargetPct,
    ChargeRates? chargeRates,
    Set<ResultRow>? hiddenRows,
    ThemeMode? themeMode,
  }) => AppSettings(
    stcgBasePct: stcgBasePct ?? this.stcgBasePct,
    ltcgBasePct: ltcgBasePct ?? this.ltcgBasePct,
    surchargePct: surchargePct ?? this.surchargePct,
    cessPct: cessPct ?? this.cessPct,
    ltcgExemption: ltcgExemption ?? this.ltcgExemption,
    longTermMonths: longTermMonths ?? this.longTermMonths,
    daysInYear: daysInYear ?? this.daysInYear,
    defaultBuyBrokerage: defaultBuyBrokerage ?? this.defaultBuyBrokerage,
    defaultSellBrokerage: defaultSellBrokerage ?? this.defaultSellBrokerage,
    defaultTargets: defaultTargets ?? this.defaultTargets,
    defaultAutoCharges: defaultAutoCharges ?? this.defaultAutoCharges,
    defaultBuyTargetPct: defaultBuyTargetPct ?? this.defaultBuyTargetPct,
    chargeRates: chargeRates ?? this.chargeRates,
    hiddenRows: hiddenRows ?? this.hiddenRows,
    themeMode: themeMode ?? this.themeMode,
  );

  Map<String, Object> toJson() => {
    'stcgBasePct': stcgBasePct,
    'ltcgBasePct': ltcgBasePct,
    'surchargePct': surchargePct,
    'cessPct': cessPct,
    'ltcgExemption': ltcgExemption,
    'longTermMonths': longTermMonths,
    'daysInYear': daysInYear,
    'defaultBuyBrokerage': defaultBuyBrokerage,
    'defaultSellBrokerage': defaultSellBrokerage,
    'defaultTargets': defaultTargets,
    'defaultAutoCharges': defaultAutoCharges,
    'defaultBuyTargetPct': defaultBuyTargetPct,
    'chargeRates': chargeRates.toJson(),
    'hiddenRows': [for (final r in hiddenRows) r.name],
    'themeMode': themeMode.name,
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    final d = AppSettings.initial;
    double n(String k, double fallback) =>
        (j[k] as num?)?.toDouble() ?? fallback;
    int i(String k, int fallback) => (j[k] as num?)?.toInt() ?? fallback;
    final hidden = j['hiddenRows'] is List
        ? {
            for (final name in j['hiddenRows'] as List)
              for (final r in ResultRow.values)
                if (r.name == name) r,
          }
        : d.hiddenRows;
    return AppSettings(
      stcgBasePct: n('stcgBasePct', d.stcgBasePct),
      ltcgBasePct: n('ltcgBasePct', d.ltcgBasePct),
      surchargePct: n('surchargePct', d.surchargePct),
      cessPct: n('cessPct', d.cessPct),
      ltcgExemption: n('ltcgExemption', d.ltcgExemption),
      longTermMonths: i('longTermMonths', d.longTermMonths),
      daysInYear: i('daysInYear', d.daysInYear),
      defaultBuyBrokerage: n('defaultBuyBrokerage', d.defaultBuyBrokerage),
      defaultSellBrokerage: n('defaultSellBrokerage', d.defaultSellBrokerage),
      defaultTargets: j['defaultTargets'] is List
          ? [for (final t in j['defaultTargets'] as List) (t as num).toDouble()]
          : d.defaultTargets,
      defaultAutoCharges:
          (j['defaultAutoCharges'] as bool?) ?? d.defaultAutoCharges,
      defaultBuyTargetPct: n('defaultBuyTargetPct', d.defaultBuyTargetPct),
      chargeRates: j['chargeRates'] is Map
          ? ChargeRates.fromJson(
              Map<String, dynamic>.from(j['chargeRates'] as Map),
            )
          : d.chargeRates,
      hiddenRows: hidden,
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == j['themeMode'],
        orElse: () => d.themeMode,
      ),
    );
  }
}
