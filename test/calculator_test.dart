import 'package:equity_calc/engine/calculator.dart';
import 'package:equity_calc/models/charge_rates.dart';
import 'package:equity_calc/models/input_field.dart';
import 'package:equity_calc/models/trade_inputs.dart';
import 'package:flutter_test/flutter_test.dart';

/// The example row from the original spreadsheet.
TradeInputs sheetInputs() => TradeInputs(
  shareName: 'Sample',
  buyDate: DateTime(2026, 11, 20),
  buyPrice: 794.80,
  quantity: 10,
  buyCharges: 30,
  buyStt: 0,
  sellDate: DateTime(2026, 11, 20),
  sellPrice: 792,
  sellBrokerage: 40,
  otherSellCharges: 0,
  sellStt: 0,
  exitLoadPct: 0.05,
  stcgRatePct: 20.8,
  ltcgRatePct: 13,
  ltcgExemption: 125000,
);

void main() {
  const paisa = 0.005;

  group('matches the spreadsheet', () {
    final results = {
      for (final t in [10.0, 25.0, 50.0])
        t: calculate(sheetInputs(), targetReturnPct: t),
    };
    final r = results[10.0]!;

    test('charges, proceeds and profit', () {
      expect(r.grossPurchaseValue, closeTo(7948.00, paisa));
      expect(r.totalInvestment, closeTo(7978.00, paisa));
      expect(r.grossSaleValue, closeTo(7920.00, paisa));
      expect(r.exitLoad, closeTo(3.96, paisa));
      expect(r.totalSellingCosts, closeTo(43.96, paisa));
      expect(r.netSaleProceeds, closeTo(7876.04, paisa));
      expect(r.taxableGain, closeTo(-101.96, paisa));
      expect(r.tax, 0);
      expect(r.netAfterTax, closeTo(7876.04, paisa));
      expect(r.netProfit, closeTo(-101.96, paisa));
    });

    test('returns', () {
      expect(r.netReturn * 100, closeTo(-1.28, paisa));
      expect(r.holdingDays, 1);
      expect(r.isLongTerm, isFalse);
      expect(r.simpleAnnualised * 100, closeTo(-466.48, paisa));
      expect(r.cagr * 100, closeTo(-99.09, paisa));
    });

    test('target sell prices, simple basis', () {
      expect(results[10.0]!.targetPriceSimple, closeTo(802.48, paisa));
      expect(results[25.0]!.targetPriceSimple, closeTo(802.89, paisa));
      expect(results[50.0]!.targetPriceSimple, closeTo(803.58, paisa));
    });

    test('target sell prices, CAGR basis', () {
      expect(results[10.0]!.targetPriceCagr, closeTo(802.46, paisa));
      expect(results[25.0]!.targetPriceCagr, closeTo(802.82, paisa));
      expect(results[50.0]!.targetPriceCagr, closeTo(803.32, paisa));
    });
  });

  test('STT is not deductible and tax applies only to the gain', () {
    final i = TradeInputs(
      shareName: 'X',
      buyDate: DateTime(2026, 1, 1),
      buyPrice: 1000,
      quantity: 100,
      buyCharges: 20,
      buyStt: 100,
      sellDate: DateTime(2026, 7, 1),
      sellPrice: 1100,
      sellBrokerage: 20,
      otherSellCharges: 10,
      sellStt: 110,
      exitLoadPct: 0,
      stcgRatePct: 20.8,
      ltcgRatePct: 13,
      ltcgExemption: 125000,
    );
    final r = calculate(i, targetReturnPct: 10);
    expect(r.totalInvestment, closeTo(100120, 1e-6));
    expect(r.netSaleProceeds, closeTo(109860, 1e-6));
    expect(r.taxableGain, closeTo(9950, 1e-6));
    expect(r.tax, closeTo(2069.6, 1e-6));
    expect(r.netProfit, closeTo(7670.4, 1e-6));
    expect(r.holdingDays, 181);
    expect(r.isLongTerm, isFalse);
  });

  group('long-term holding', () {
    TradeInputs held(DateTime buy, DateTime sell) => sheetInputs()
        .withValue(InputField.buyDate, buy)
        .withValue(InputField.sellDate, sell)
        .withValue(InputField.buyPrice, 100.0)
        .withValue(InputField.sellPrice, 400.0)
        .withValue(InputField.quantity, 1000.0)
        .withValue(InputField.buyCharges, 0.0)
        .withValue(InputField.sellBrokerage, 0.0)
        .withValue(InputField.exitLoadPct, 0.0);

    test('exactly 12 months is still short-term', () {
      final r = calculate(
        held(DateTime(2025, 11, 20), DateTime(2026, 11, 20)),
        targetReturnPct: 10,
      );
      expect(r.isLongTerm, isFalse);
      expect(r.taxRatePct, 20.8);
      expect(r.tax, closeTo(300000 * 0.208, 1e-6));
    });

    test('over 12 months switches to LTCG with exemption', () {
      final r = calculate(
        held(DateTime(2025, 11, 20), DateTime(2026, 11, 21)),
        targetReturnPct: 10,
      );
      expect(r.isLongTerm, isTrue);
      expect(r.taxRatePct, 13);
      expect(r.exemptionUsed, 125000);
      expect(r.tax, closeTo((300000 - 125000) * 0.13, 1e-6));
    });

    test('month-end purchase dates', () {
      expect(
        isLongTermHolding(DateTime(2024, 2, 29), DateTime(2025, 2, 28), 12),
        isFalse,
      );
      expect(
        isLongTermHolding(DateTime(2024, 2, 29), DateTime(2025, 3, 1), 12),
        isTrue,
      );
    });
  });

  test(
    'auto charges: selling at the solved target gives the required profit',
    () {
      final i = sheetInputs()
          .withValue(InputField.sellDate, DateTime(2027, 6, 1))
          .withValue(InputField.exitLoadPct, 0.0);
      const options = CalcOptions(autoCharges: true, rates: ChargeRates());
      final r = calculate(i, targetReturnPct: 25, options: options);

      final b = r.breakdown!;
      expect(b.buyStt, closeTo(7.948, 1e-9));
      expect(b.stampDuty, closeTo(7948 * 0.00015, 1e-9));
      expect(r.buyChargesExclStt, greaterThan(30));

      final years = r.holdingDays / 365;
      final atSimple = calculate(
        i.withValue(InputField.sellPrice, r.targetPriceSimple!),
        targetReturnPct: 25,
        options: options,
      );
      expect(
        atSimple.netProfit,
        closeTo(r.totalInvestment * 0.25 * years, 1e-4),
      );

      final atCagr = calculate(
        i.withValue(InputField.sellPrice, r.targetPriceCagr!),
        targetReturnPct: 25,
        options: options,
      );
      expect(atCagr.cagr, closeTo(0.25, 1e-6));
    },
  );

  group('edge cases', () {
    test('zero quantity does not crash and has no target price', () {
      final r = calculate(
        sheetInputs().withValue(InputField.quantity, 0.0),
        targetReturnPct: 10,
      );
      expect(r.netReturn.isFinite, isTrue);
      expect(r.targetPriceSimple, isNull);
      expect(r.targetPriceCagr, isNull);
    });

    test('sell date before buy date uses a 1-day holding period', () {
      final r = calculate(
        sheetInputs().withValue(InputField.sellDate, DateTime(2026, 11, 1)),
        targetReturnPct: 10,
      );
      expect(r.rawDays, -19);
      expect(r.holdingDays, 1);
    });

    test('total loss reports CAGR of -100%', () {
      final r = calculate(
        sheetInputs().withValue(InputField.sellPrice, 0.0),
        targetReturnPct: 10,
      );
      expect(r.cagr, -1);
    });

    test('negative target return can be below the buy price', () {
      final r = calculate(
        sheetInputs().withValue(InputField.sellDate, DateTime(2027, 11, 20)),
        targetReturnPct: -10,
      );
      expect(r.targetPriceCagr, lessThan(794.80));
    });
  });

  group('buy targets', () {
    test('dip price is the purchase price less the buy target', () {
      final r = calculate(sheetInputs(), targetReturnPct: 10);
      expect(r.buyTargetPct, 5);
      expect(r.dipBuyPrice, closeTo(755.06, paisa));
    });

    test('buying at the max buy price earns exactly the buy target net', () {
      final i = sheetInputs().withValue(InputField.sellPrice, 900.0);
      final r = calculate(i, targetReturnPct: 10);
      final atMax = calculate(
        i.withValue(InputField.buyPrice, r.maxBuyPrice!),
        targetReturnPct: 10,
      );
      expect(atMax.netReturn, closeTo(0.05, 1e-7));
      expect(r.maxBuyPrice, lessThan(900));
    });

    test('max buy price accounts for auto charges', () {
      final i = sheetInputs()
          .withValue(InputField.sellPrice, 900.0)
          .withValue(InputField.buyTargetPct, 8.0);
      const options = CalcOptions(autoCharges: true);
      final r = calculate(i, targetReturnPct: 10, options: options);
      final atMax = calculate(
        i.withValue(InputField.buyPrice, r.maxBuyPrice!),
        targetReturnPct: 10,
        options: options,
      );
      expect(atMax.netReturn, closeTo(0.08, 1e-7));
    });

    test('no max buy price without a selling price', () {
      final r = calculate(
        sheetInputs().withValue(InputField.sellPrice, 0.0),
        targetReturnPct: 10,
      );
      expect(r.maxBuyPrice, isNull);
    });
  });

  test('target buy price reaches the scenario target return', () {
    final i = sheetInputs()
        .withValue(InputField.sellDate, DateTime(2027, 11, 20))
        .withValue(InputField.sellPrice, 900.0);
    final r = calculate(i, targetReturnPct: 10);
    expect(r.holdingDays, 365);
    final atCagr = calculate(
      i.withValue(InputField.buyPrice, r.targetBuyPriceCagr!),
      targetReturnPct: 10,
    );
    expect(atCagr.cagr, closeTo(0.10, 1e-7));
    final atSimple = calculate(
      i.withValue(InputField.buyPrice, r.targetBuyPriceSimple!),
      targetReturnPct: 10,
    );
    expect(atSimple.simpleAnnualised, closeTo(0.10, 1e-7));
    expect(r.targetBuyPriceCagr, lessThan(900));
  });

  test('quick check helpers match the scenario targets', () {
    final i = sheetInputs()
        .withValue(InputField.sellDate, DateTime(2027, 11, 20))
        .withValue(InputField.sellPrice, 900.0);
    final r = calculate(i, targetReturnPct: 18);
    final period = periodReturnForAnnual(i, 18);
    expect(period, closeTo(0.18, 1e-12));
    expect(sellPriceForReturn(i, period), closeTo(r.targetPriceCagr!, 1e-6));
    expect(buyPriceForReturn(i, period), closeTo(r.targetBuyPriceCagr!, 1e-6));
    expect(buyPriceForReturn(i, 0.05), closeTo(r.maxBuyPrice!, 1e-6));
  });

  test('worked example: ₹178, 100 shares, 10 days, 10% a year', () {
    final i = TradeInputs(
      shareName: 'Example',
      buyDate: DateTime(2026, 11, 23),
      buyPrice: 178,
      quantity: 100,
      buyCharges: 30,
      buyStt: 0,
      sellDate: DateTime(2026, 12, 3),
      sellPrice: 178,
      sellBrokerage: 40,
      otherSellCharges: 0,
      sellStt: 0,
      exitLoadPct: 0,
      stcgRatePct: 20.8,
      ltcgRatePct: 13,
      ltcgExemption: 125000,
    );
    final r = calculate(i, targetReturnPct: 10);
    expect(r.holdingDays, 10);
    expect(r.totalInvestment, 17830);
    expect(r.targetPriceSimple, closeTo(179.32, 0.005));
    expect(r.targetPriceCagr, closeTo(179.29, 0.005));
    expect(sellPriceForReturn(i, 0.10), closeTo(201.21, 0.005));
  });
}
