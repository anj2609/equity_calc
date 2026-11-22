import 'dart:math' as math;

import '../models/charge_rates.dart';
import '../models/input_field.dart';
import '../models/trade_inputs.dart';

class CalcOptions {
  const CalcOptions({
    this.daysInYear = 365,
    this.longTermMonths = 12,
    this.autoCharges = false,
    this.rates = const ChargeRates(),
  });

  final int daysInYear;
  final int longTermMonths;

  /// When true, STT, stamp duty, exchange, SEBI, DP and GST are derived from
  /// [rates] and the manual buy-charges field is treated as brokerage only.
  final bool autoCharges;
  final ChargeRates rates;
}

/// Itemised statutory charges (auto-charges mode only).
class ChargeBreakdown {
  const ChargeBreakdown({
    required this.buyBrokerage,
    required this.stampDuty,
    required this.buyExchange,
    required this.buySebi,
    required this.buyGst,
    required this.buyStt,
    required this.sellBrokerage,
    required this.sellExchange,
    required this.sellSebi,
    required this.dpCharge,
    required this.sellGst,
    required this.sellStt,
  });

  factory ChargeBreakdown.compute({
    required ChargeRates r,
    required double buyValue,
    required double sellValue,
    required double buyBrokerage,
    required double sellBrokerage,
  }) {
    final buyExchange = buyValue * r.exchangeTxnPct / 100;
    final buySebi = buyValue * r.sebiFeePerCrore / 1e7;
    final sellExchange = sellValue * r.exchangeTxnPct / 100;
    final sellSebi = sellValue * r.sebiFeePerCrore / 1e7;
    final dp = sellValue > 0 ? r.dpChargePerSell : 0.0;
    return ChargeBreakdown(
      buyBrokerage: buyBrokerage,
      stampDuty: buyValue * r.stampDutyBuyPct / 100,
      buyExchange: buyExchange,
      buySebi: buySebi,
      buyGst: (buyBrokerage + buyExchange + buySebi) * r.gstPct / 100,
      buyStt: buyValue * r.sttBuyPct / 100,
      sellBrokerage: sellBrokerage,
      sellExchange: sellExchange,
      sellSebi: sellSebi,
      dpCharge: dp,
      sellGst: (sellBrokerage + sellExchange + sellSebi + dp) * r.gstPct / 100,
      sellStt: sellValue * r.sttSellPct / 100,
    );
  }

  final double buyBrokerage, stampDuty, buyExchange, buySebi, buyGst, buyStt;
  final double sellBrokerage,
      sellExchange,
      sellSebi,
      dpCharge,
      sellGst,
      sellStt;

  double get buyChargesExclStt =>
      buyBrokerage + stampDuty + buyExchange + buySebi + buyGst;
  double get otherSellCharges => sellExchange + sellSebi + dpCharge + sellGst;
}

class TradeResult {
  const TradeResult({
    required this.sellPrice,
    required this.grossPurchaseValue,
    required this.buyChargesExclStt,
    required this.buyStt,
    required this.totalInvestment,
    required this.grossSaleValue,
    required this.sellBrokerage,
    required this.otherSellCharges,
    required this.sellStt,
    required this.exitLoad,
    required this.totalSellingCosts,
    required this.netSaleProceeds,
    required this.taxableGain,
    required this.isLongTerm,
    required this.taxRatePct,
    required this.exemptionUsed,
    required this.tax,
    required this.netAfterTax,
    required this.netProfit,
    required this.netReturn,
    required this.rawDays,
    required this.holdingDays,
    required this.simpleAnnualised,
    required this.cagr,
    this.breakdown,
    this.targetReturnPct = 0,
    this.targetPriceSimple,
    this.targetPriceCagr,
    this.buyTargetPct = 0,
    this.dipBuyPrice,
    this.maxBuyPrice,
    this.targetBuyPriceSimple,
    this.targetBuyPriceCagr,
  });

  final double sellPrice;
  final double grossPurchaseValue;
  final double buyChargesExclStt;
  final double buyStt;
  final double totalInvestment;
  final double grossSaleValue;
  final double sellBrokerage;
  final double otherSellCharges;
  final double sellStt;
  final double exitLoad;
  final double totalSellingCosts;
  final double netSaleProceeds;

  /// Capital gain before tax. STT is not deductible, so it is left out.
  final double taxableGain;
  final bool isLongTerm;
  final double taxRatePct;
  final double exemptionUsed;
  final double tax;
  final double netAfterTax;
  final double netProfit;

  /// Fractions, e.g. -0.0128 for -1.28%.
  final double netReturn;
  final double simpleAnnualised;
  final double cagr;

  /// Calendar days between the dates (can be zero or negative).
  final int rawDays;

  /// Days used for annualising: never below 1.
  final int holdingDays;

  final ChargeBreakdown? breakdown;
  final double targetReturnPct;

  /// Sell price per share needed to hit [targetReturnPct]; null if unreachable.
  final double? targetPriceSimple;
  final double? targetPriceCagr;

  final double buyTargetPct;

  /// Purchase price less [buyTargetPct]: where to buy on a dip.
  final double? dipBuyPrice;

  /// Highest purchase price per share that still earns [buyTargetPct] net
  /// (after charges and tax) over the holding period at the selling price.
  final double? maxBuyPrice;

  /// Highest purchase price per share that still reaches [targetReturnPct]
  /// a year when selling at the selling price on the selling date.
  final double? targetBuyPriceSimple;
  final double? targetBuyPriceCagr;

  TradeResult _withTargets(
    double pct,
    double? priceSimple,
    double? priceCagr, {
    required double buyPct,
    double? dip,
    double? maxBuy,
    double? buySimple,
    double? buyCagr,
  }) => TradeResult(
    sellPrice: sellPrice,
    grossPurchaseValue: grossPurchaseValue,
    buyChargesExclStt: buyChargesExclStt,
    buyStt: buyStt,
    totalInvestment: totalInvestment,
    grossSaleValue: grossSaleValue,
    sellBrokerage: sellBrokerage,
    otherSellCharges: otherSellCharges,
    sellStt: sellStt,
    exitLoad: exitLoad,
    totalSellingCosts: totalSellingCosts,
    netSaleProceeds: netSaleProceeds,
    taxableGain: taxableGain,
    isLongTerm: isLongTerm,
    taxRatePct: taxRatePct,
    exemptionUsed: exemptionUsed,
    tax: tax,
    netAfterTax: netAfterTax,
    netProfit: netProfit,
    netReturn: netReturn,
    rawDays: rawDays,
    holdingDays: holdingDays,
    simpleAnnualised: simpleAnnualised,
    cagr: cagr,
    breakdown: breakdown,
    targetReturnPct: pct,
    targetPriceSimple: priceSimple,
    targetPriceCagr: priceCagr,
    buyTargetPct: buyPct,
    dipBuyPrice: dip,
    maxBuyPrice: maxBuy,
    targetBuyPriceSimple: buySimple,
    targetBuyPriceCagr: buyCagr,
  );
}

/// Full calculation for one scenario, including target sell prices.
TradeResult calculate(
  TradeInputs inputs, {
  required double targetReturnPct,
  CalcOptions options = const CalcOptions(),
}) {
  final base = _evaluate(inputs, inputs.sellPrice, options);
  final r = targetReturnPct / 100;
  final yearFraction = base.holdingDays / options.daysInYear;
  final ti = base.totalInvestment;

  double? simple;
  double? cagr;
  if (ti > 0 && inputs.quantity > 0) {
    simple = _solveSellPrice(inputs, ti * r * yearFraction, options);
    if (1 + r >= 0) {
      cagr = _solveSellPrice(
        inputs,
        ti * (math.pow(1 + r, yearFraction) - 1),
        options,
      );
    }
  }
  final buyPct = inputs.buyTargetPct;
  final canBuy = inputs.quantity > 0 && inputs.sellPrice > 0;
  return base._withTargets(
    targetReturnPct,
    simple,
    cagr,
    buyPct: buyPct,
    dip: inputs.buyPrice > 0 ? inputs.buyPrice * (1 - buyPct / 100) : null,
    maxBuy: canBuy ? _solveMaxBuyPrice(inputs, buyPct / 100, options) : null,
    buySimple: canBuy
        ? _solveMaxBuyPrice(inputs, r * yearFraction, options)
        : null,
    buyCagr: canBuy && 1 + r >= 0
        ? _solveMaxBuyPrice(inputs, math.pow(1 + r, yearFraction) - 1, options)
        : null,
  );
}

/// Return over the holding period that equals [annualPct] a year,
/// compounded (CAGR basis). A fraction, e.g. 0.05.
double periodReturnForAnnual(
  TradeInputs inputs,
  double annualPct, {
  CalcOptions options = const CalcOptions(),
}) {
  final days = math.max(1, calendarDays(inputs.buyDate, inputs.sellDate));
  final growth = 1 + annualPct / 100;
  return growth <= 0 ? -1 : math.pow(growth, days / options.daysInYear) - 1;
}

/// Selling price per share that leaves a net return of [periodReturn]
/// (fraction, after charges and tax) at the current purchase price.
double? sellPriceForReturn(
  TradeInputs inputs,
  double periodReturn, {
  CalcOptions options = const CalcOptions(),
}) {
  final ti = _evaluate(inputs, inputs.sellPrice, options).totalInvestment;
  if (ti <= 0 || inputs.quantity <= 0) return null;
  return _solveSellPrice(inputs, ti * periodReturn, options);
}

/// Highest purchase price per share that leaves a net return of
/// [periodReturn] (fraction, after charges and tax) at the selling price.
double? buyPriceForReturn(
  TradeInputs inputs,
  double periodReturn, {
  CalcOptions options = const CalcOptions(),
}) {
  if (inputs.quantity <= 0 || inputs.sellPrice <= 0) return null;
  return _solveMaxBuyPrice(inputs, periodReturn, options);
}

int calendarDays(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// Long-term once held for more than [months] months.
bool isLongTermHolding(DateTime buy, DateTime sell, int months) {
  final m = buy.month - 1 + months;
  final year = buy.year + m ~/ 12;
  final month = m % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  final threshold = DateTime(year, month, math.min(buy.day, lastDay));
  return dateOnly(sell).isAfter(threshold);
}

TradeResult _evaluate(TradeInputs i, double sellPrice, CalcOptions o) {
  final gpv = i.buyPrice * i.quantity;
  final gsv = sellPrice * i.quantity;

  ChargeBreakdown? breakdown;
  double buyCharges, buyStt, otherSell, sellStt;
  if (o.autoCharges) {
    breakdown = ChargeBreakdown.compute(
      r: o.rates,
      buyValue: gpv,
      sellValue: gsv,
      buyBrokerage: i.buyCharges,
      sellBrokerage: i.sellBrokerage,
    );
    buyCharges = breakdown.buyChargesExclStt;
    buyStt = breakdown.buyStt;
    otherSell = breakdown.otherSellCharges;
    sellStt = breakdown.sellStt;
  } else {
    buyCharges = i.buyCharges;
    buyStt = i.buyStt;
    otherSell = i.otherSellCharges;
    sellStt = i.sellStt;
  }

  final exitLoad = gsv * i.exitLoadPct / 100;
  final totalInvestment = gpv + buyCharges + buyStt;
  final totalSellingCosts = i.sellBrokerage + otherSell + sellStt + exitLoad;
  final netSaleProceeds = gsv - totalSellingCosts;
  final gain =
      (gsv - i.sellBrokerage - otherSell - exitLoad) - (gpv + buyCharges);

  final rawDays = calendarDays(i.buyDate, i.sellDate);
  final days = math.max(1, rawDays);
  final longTerm = isLongTermHolding(i.buyDate, i.sellDate, o.longTermMonths);
  final exemptionUsed = longTerm
      ? math.min(math.max(gain, 0.0), math.max(i.ltcgExemption, 0.0))
      : 0.0;
  final ratePct = longTerm ? i.ltcgRatePct : i.stcgRatePct;
  final tax = math.max(0.0, (gain - exemptionUsed) * ratePct / 100);

  final netAfterTax = netSaleProceeds - tax;
  final netProfit = netAfterTax - totalInvestment;
  final netReturn = totalInvestment > 0 ? netProfit / totalInvestment : 0.0;
  final growth = 1 + netReturn;

  return TradeResult(
    sellPrice: sellPrice,
    grossPurchaseValue: gpv,
    buyChargesExclStt: buyCharges,
    buyStt: buyStt,
    totalInvestment: totalInvestment,
    grossSaleValue: gsv,
    sellBrokerage: i.sellBrokerage,
    otherSellCharges: otherSell,
    sellStt: sellStt,
    exitLoad: exitLoad,
    totalSellingCosts: totalSellingCosts,
    netSaleProceeds: netSaleProceeds,
    taxableGain: gain,
    isLongTerm: longTerm,
    taxRatePct: ratePct,
    exemptionUsed: exemptionUsed,
    tax: tax,
    netAfterTax: netAfterTax,
    netProfit: netProfit,
    netReturn: netReturn,
    rawDays: rawDays,
    holdingDays: days,
    simpleAnnualised: netReturn * o.daysInYear / days,
    cagr: growth <= 0 ? -1.0 : math.pow(growth, o.daysInYear / days) - 1,
    breakdown: breakdown,
  );
}

/// Lowest sell price per share whose net profit (after charges and tax)
/// reaches [requiredProfit]. Net profit rises with sell price, so bisection
/// works for any charge model, including price-dependent auto charges.
double? _solveSellPrice(TradeInputs i, double requiredProfit, CalcOptions o) {
  double profitAt(double price) => _evaluate(i, price, o).netProfit;

  if (!requiredProfit.isFinite) return null;
  var lo = 0.0;
  if (profitAt(lo) >= requiredProfit) return 0;
  var hi = math.max(1.0, math.max(i.buyPrice, i.sellPrice)) * 2;
  var doublings = 0;
  while (profitAt(hi) < requiredProfit) {
    lo = hi;
    hi *= 2;
    if (++doublings > 60) return null;
  }
  for (var k = 0; k < 200 && hi - lo > 1e-9; k++) {
    final mid = (lo + hi) / 2;
    if (profitAt(mid) < requiredProfit) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return hi;
}

/// Highest buy price per share whose net return (after charges and tax) is
/// at least [requiredReturn]. Net return falls as the buy price rises.
double? _solveMaxBuyPrice(TradeInputs i, double requiredReturn, CalcOptions o) {
  double returnAt(double price) => _evaluate(
    i.withValue(InputField.buyPrice, price),
    i.sellPrice,
    o,
  ).netReturn;

  if (!requiredReturn.isFinite || requiredReturn <= -1) return null;
  var lo = i.sellPrice * 1e-6;
  if (returnAt(lo) < requiredReturn) return null;
  var hi = i.sellPrice;
  var doublings = 0;
  while (returnAt(hi) >= requiredReturn) {
    lo = hi;
    hi *= 2;
    if (++doublings > 60) return null;
  }
  for (var k = 0; k < 200 && hi - lo > 1e-9; k++) {
    final mid = (lo + hi) / 2;
    if (returnAt(mid) >= requiredReturn) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return lo;
}
