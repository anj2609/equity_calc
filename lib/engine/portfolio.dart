import 'dart:math' as math;

import '../models/trade_inputs.dart';
import 'calculator.dart';

/// One share in a combined view: the scenario chosen for it and its result.
class PortfolioItem {
  const PortfolioItem({
    required this.name,
    required this.scenarioLabel,
    required this.inputs,
    required this.result,
  });

  final String name;
  final String scenarioLabel;
  final TradeInputs inputs;
  final TradeResult result;

  /// Buy charges incl. STT plus all selling costs.
  double get charges =>
      result.buyChargesExclStt + result.buyStt + result.totalSellingCosts;
}

class PortfolioResult {
  const PortfolioResult({
    required this.items,
    required this.invested,
    required this.grossSaleValue,
    required this.netSaleProceeds,
    required this.charges,
    required this.grossGain,
    required this.stcgNet,
    required this.ltcgNet,
    required this.exemptionUsed,
    required this.stcgTax,
    required this.ltcgTax,
    required this.standaloneTax,
    required this.xirr,
  });

  final List<PortfolioItem> items;
  final double invested;
  final double grossSaleValue;
  final double netSaleProceeds;
  final double charges;

  /// Sum of every share's taxable gain or loss, before set-off.
  final double grossGain;

  /// Net short-term and long-term gain after set-off. Negative means a loss
  /// left over to carry forward.
  final double stcgNet;
  final double ltcgNet;
  final double exemptionUsed;
  final double stcgTax;
  final double ltcgTax;

  /// What the tax would be if each share were taxed on its own.
  final double standaloneTax;

  /// Annualised return from the actual buy/sell dates; null if undefined.
  final double? xirr;

  double get tax => stcgTax + ltcgTax;
  double get netProfit => netSaleProceeds - tax - invested;
  double get netReturn => invested > 0 ? netProfit / invested : 0;
  double get taxSavedBySetOff => math.max(0, standaloneTax - tax);
}

/// Combines several trades with Indian set-off rules: short-term losses can
/// reduce short- or long-term gains, long-term losses only long-term gains,
/// and the LTCG exemption is used once across all shares.
PortfolioResult combinePortfolio(
  List<PortfolioItem> items, {
  required double stcgRatePct,
  required double ltcgRatePct,
  required double ltcgExemption,
}) {
  double sum(double Function(PortfolioItem i) f) =>
      items.fold(0.0, (t, i) => t + f(i));

  var st = sum((i) => i.result.isLongTerm ? 0 : i.result.taxableGain);
  var lt = sum((i) => i.result.isLongTerm ? i.result.taxableGain : 0);
  if (st < 0 && lt > 0) {
    final setOff = math.min(-st, lt);
    st += setOff;
    lt -= setOff;
  }
  final exemption = math.min(math.max(lt, 0.0), math.max(ltcgExemption, 0.0));
  final stcgTax = math.max(0.0, st) * stcgRatePct / 100;
  final ltcgTax = math.max(0.0, lt - exemption) * ltcgRatePct / 100;

  return PortfolioResult(
    items: items,
    invested: sum((i) => i.result.totalInvestment),
    grossSaleValue: sum((i) => i.result.grossSaleValue),
    netSaleProceeds: sum((i) => i.result.netSaleProceeds),
    charges: sum((i) => i.charges),
    grossGain: sum((i) => i.result.taxableGain),
    stcgNet: st,
    ltcgNet: lt,
    exemptionUsed: exemption,
    stcgTax: stcgTax,
    ltcgTax: ltcgTax,
    standaloneTax: sum((i) => i.result.tax),
    xirr: _xirr(items, stcgTax + ltcgTax),
  );
}

/// Money out at each purchase, money in at each sale, combined tax paid at
/// the last sale.
double? _xirr(List<PortfolioItem> items, double tax) {
  if (items.isEmpty) return null;
  final flows = <(DateTime, double)>[
    for (final i in items) ...[
      (i.inputs.buyDate, -i.result.totalInvestment),
      (i.inputs.sellDate, i.result.netSaleProceeds),
    ],
  ];
  final first = flows.map((f) => f.$1).reduce((a, b) => a.isBefore(b) ? a : b);
  final last = flows.map((f) => f.$1).reduce((a, b) => a.isAfter(b) ? a : b);
  flows.add((last, -tax));
  if (calendarDays(first, last) < 1) return null;

  double npv(double rate) => flows.fold(
    0.0,
    (t, f) => t + f.$2 / math.pow(1 + rate, calendarDays(first, f.$1) / 365),
  );

  var lo = -0.9999;
  var hi = 1e6;
  final fLo = npv(lo);
  final fHi = npv(hi);
  if (!fLo.isFinite || !fHi.isFinite || fLo.sign == fHi.sign) return null;
  for (var k = 0; k < 300; k++) {
    final mid = (lo + hi) / 2;
    final f = npv(mid);
    if (f.sign == fLo.sign) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return (lo + hi) / 2;
}
