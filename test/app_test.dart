import 'package:equity_calc/utils/format.dart';
import 'package:equity_calc/models/input_field.dart';
import 'package:equity_calc/engine/calculator.dart';
import 'package:equity_calc/main.dart';
import 'package:equity_calc/services/price_service.dart';
import 'package:equity_calc/state/app_state.dart';
import 'package:equity_calc/ui/inputs/inputs_panel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'price_service_test.dart' show fakeYahoo;

Future<AppState> _pumpApp(
  WidgetTester tester, {
  Size size = const Size(400, 900),
  PriceService? prices,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // The profit/loss indicators pulse forever unless reduce-motion is on.
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  SharedPreferences.setMockInitialValues({});
  final state = (await tester.runAsync(() => AppState.load(prices: prices)))!;
  await tester.pumpWidget(
    ChangeNotifierProvider.value(value: state, child: const EquityCalcApp()),
  );
  await tester.pumpAndSettle();
  return state;
}

void main() {
  testWidgets('first launch shows the sheet sample with matching results', (
    tester,
  ) async {
    // Tall enough that the whole results table is built without scrolling.
    await _pumpApp(tester, size: const Size(400, 3200));
    expect(find.text('Sample (from sheet)'), findsOneWidget);

    await tester.tap(find.text('Results'));
    await tester.pumpAndSettle();
    expect(find.text('-₹101.96'), findsWidgets);
    expect(find.text('-466.48%'), findsWidgets);
    expect(find.text('₹802.46'), findsWidgets);

    expect(find.text('₹7,978.00'), findsWidgets);
    expect(find.text('₹803.58'), findsWidgets);
  });

  testWidgets('a scenario override changes only that scenario', (tester) async {
    final state = await _pumpApp(tester);
    final chip = find.widgetWithText(ChoiceChip, '25% target');
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();

    final sellPrice = find.widgetWithText(TextField, 'Selling price per share');
    await tester.enterText(sellPrice, '850');
    await tester.pumpAndSettle();

    final results = state.results;
    expect(results[0].result.sellPrice, 792);
    expect(results[1].result.sellPrice, 850);
    expect(results[2].result.sellPrice, 792);
    expect(find.text('Only for this scenario'), findsOneWidget);

    await tester.tap(find.byTooltip('Use the shared value'));
    await tester.pumpAndSettle();
    expect(state.results[1].result.sellPrice, 792);

    // Let the debounced auto-save run.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('opening a collapsed section with fields works on iOS', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await _pumpApp(tester);
    final tax = find.text('Tax & advanced');
    final inputsList = find
        .descendant(
          of: find.byType(InputsPanel),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(tax, 300, scrollable: inputsList);
    await tester.pumpAndSettle();
    await tester.tap(tax);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(TextField, 'Exit load'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('fetching a price fills the purchase price', (tester) async {
    final state = await _pumpApp(
      tester,
      prices: PriceService(client: fakeYahoo()),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'NSE/BSE symbol'),
      'RELIANCE.NS',
    );
    await tester.pump();
    await tester.runAsync(state.fetchQuote);
    await tester.pumpAndSettle();
    expect(find.text('₹1,377.50'), findsOneWidget);

    await tester.ensureVisible(find.text('Use as purchase price'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use as purchase price'));
    await tester.pumpAndSettle();
    expect(state.current.base.buyPrice, 1377.5);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('changes are only stored after confirming', (tester) async {
    final state = await _pumpApp(tester);
    final original = state.current.base.sellPrice;
    await tester.enterText(
      find.widgetWithText(TextField, 'Selling price per share'),
      '900',
    );
    await tester.pump();
    expect(state.isDirty, isTrue);
    expect(state.savedById(state.current.id)!.base.sellPrice, original);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New calculation'));
    await tester.pumpAndSettle();
    expect(find.text('Save changes?'), findsOneWidget);

    await tester.tap(find.text("Don't save"));
    await tester.pumpAndSettle();
    expect(state.isDirty, isFalse);
    expect(state.calculations.single.base.sellPrice, original);
    expect(state.current.displayName, 'Untitled calculation');
  });

  testWidgets('saving a new calculation through the name prompt works', (
    tester,
  ) async {
    final state = await _pumpApp(tester);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New calculation'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Infosys plan');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      state.calculations.map((c) => c.displayName),
      contains('Infosys plan'),
    );
    expect(state.isDirty, isFalse);
  });

  testWidgets('typing holding days moves the selling date', (tester) async {
    final state = await _pumpApp(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Holding period (days)'),
      '400',
    );
    await tester.pump();
    expect(state.current.base.sellDate, DateTime(2027, 12, 25));
    expect(state.results.first.result.holdingDays, 400);
    expect(state.results.first.result.isLongTerm, isTrue);
  });

  testWidgets('quick check shows prices for any return', (tester) async {
    final state = await _pumpApp(tester, size: const Size(400, 3200));
    state.setField(InputField.sellDate, DateTime(2027, 11, 20));
    state.setField(InputField.sellPrice, 900.0);
    await tester.tap(find.text('Results'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Return you want'),
      '18',
    );
    await tester.pump();
    final expected = state.results.first.inputs;
    final sell = sellPriceForReturn(
      expected,
      periodReturnForAnnual(expected, 18),
    );
    expect(find.text(formatMoney(sell)), findsWidgets);

    await tester.tap(find.text('Total'));
    await tester.pump();
    expect(
      find.text(formatMoney(sellPriceForReturn(expected, 0.18))),
      findsWidgets,
    );
  });

  testWidgets('wide layout shows inputs and results side by side', (
    tester,
  ) async {
    await _pumpApp(tester, size: const Size(1400, 2400));
    expect(find.byType(TabBar), findsNothing);
    expect(find.text('CALCULATED RESULTS'), findsOneWidget);
    expect(find.text('Trade details'), findsOneWidget);
  });
}
