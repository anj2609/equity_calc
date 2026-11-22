import 'package:equity_calc/engine/calculator.dart';
import 'package:equity_calc/engine/portfolio.dart';
import 'package:equity_calc/models/trade_inputs.dart';
import 'package:flutter_test/flutter_test.dart';

/// A trade with no charges so gains are easy to reason about.
PortfolioItem trade(
  String name,
  double buy,
  double sell, {
  required DateTime from,
  required DateTime to,
}) {
  final inputs = TradeInputs(
    shareName: name,
    buyDate: from,
    buyPrice: buy,
    quantity: 100,
    buyCharges: 0,
    buyStt: 0,
    sellDate: to,
    sellPrice: sell,
    sellBrokerage: 0,
    otherSellCharges: 0,
    sellStt: 0,
    exitLoadPct: 0,
    stcgRatePct: 20.8,
    ltcgRatePct: 13,
    ltcgExemption: 0,
  );
  return PortfolioItem(
    name: name,
    scenarioLabel: 'S1',
    inputs: inputs,
    result: calculate(inputs, targetReturnPct: 10),
  );
}

void main() {
  final jan = DateTime(2026, 1, 1);
  final jul = DateTime(2026, 7, 1);
  final nextYear = DateTime(2027, 3, 1);

  test('short-term loss offsets short-term gain', () {
    final p = combinePortfolio(
      [
        trade('A', 100, 150, from: jan, to: jul),
        trade('B', 100, 80, from: jan, to: jul),
      ],
      stcgRatePct: 20.8,
      ltcgRatePct: 13,
      ltcgExemption: 125000,
    );
    expect(p.grossGain, 3000);
    expect(p.stcgNet, 3000);
    expect(p.tax, closeTo(3000 * 0.208, 1e-9));
    expect(p.standaloneTax, closeTo(5000 * 0.208, 1e-9));
    expect(p.taxSavedBySetOff, closeTo(2000 * 0.208, 1e-9));
    expect(p.netProfit, closeTo(3000 - 3000 * 0.208, 1e-9));
  });

  test('short-term loss offsets long-term gain, exemption used once', () {
    final p = combinePortfolio(
      [
        trade('Long', 100, 3100, from: jan, to: nextYear),
        trade('Short', 1000, 500, from: jan, to: jul),
      ],
      stcgRatePct: 20.8,
      ltcgRatePct: 13,
      ltcgExemption: 125000,
    );
    // LTCG 3,00,000 less STCL 50,000 = 2,50,000; minus 1,25,000 exemption.
    expect(p.stcgNet, 0);
    expect(p.ltcgNet, 250000);
    expect(p.exemptionUsed, 125000);
    expect(p.tax, closeTo(125000 * 0.13, 1e-9));
  });

  test('long-term loss cannot offset short-term gain', () {
    final p = combinePortfolio(
      [
        trade('Short', 100, 200, from: jan, to: jul),
        trade('Long', 1000, 900, from: jan, to: nextYear),
      ],
      stcgRatePct: 20.8,
      ltcgRatePct: 13,
      ltcgExemption: 0,
    );
    expect(p.stcgNet, 10000);
    expect(p.ltcgNet, -10000);
    expect(p.tax, closeTo(10000 * 0.208, 1e-9));
  });

  test('XIRR matches a simple one-year trade', () {
    final p = combinePortfolio(
      [
        trade(
          'A',
          100,
          110,
          from: DateTime(2025, 1, 1),
          to: DateTime(2026, 1, 1),
        ),
      ],
      stcgRatePct: 0,
      ltcgRatePct: 0,
      ltcgExemption: 0,
    );
    expect(p.xirr, closeTo(0.10, 1e-6));
  });
}
