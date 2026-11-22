import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../engine/calculator.dart';
import '../../models/result_row.dart';
import '../../state/app_state.dart';
import '../../utils/format.dart';
import '../../utils/notes.dart';
import '../theme.dart';
import '../inputs/fields.dart';
import '../../models/input_field.dart';
import '../widgets/profit_indicator.dart';

class ResultsPanel extends StatelessWidget {
  const ResultsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final results = state.results;
    final hidden = state.settings.hiddenRows;
    final warnings = _warnings(results);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      children: [
        if (warnings.isNotEmpty) ...[
          _WarningsCard(warnings),
          const SizedBox(height: 12),
        ],
        const _QuickCheckCard(),
        const SizedBox(height: 12),
        _SummaryCards(results),
        const SizedBox(height: 16),
        ScenarioTable(
          title: 'CALCULATED RESULTS',
          results: results,
          rows: [
            for (final r in ResultRow.values)
              if (!hidden.contains(r)) _rowSpec(r),
          ],
        ),
        if (state.current.autoCharges) ...[
          const SizedBox(height: 16),
          ScenarioTable(
            title: 'CHARGE BREAKDOWN (AUTO)',
            results: results,
            rows: _breakdownRows,
          ),
        ],
        const SizedBox(height: 16),
        const _NotesCard(),
      ],
    );
  }
}

List<String> _warnings(List<ScenarioResult> results) {
  final byMessage = <String, List<String>>{};
  void add(String message, ScenarioResult r) =>
      (byMessage[message] ??= []).add('Scenario ${r.index + 1}');
  for (final r in results) {
    final i = r.inputs;
    if (i.buyPrice <= 0 || i.quantity <= 0) {
      add('Enter a purchase price and quantity to see results.', r);
    } else if (i.sellPrice <= 0) {
      add('Enter a selling price to see profit and returns.', r);
    }
    if (r.result.rawDays < 0) {
      add(
        'The selling date is before the purchase date, so a 1-day holding period is used.',
        r,
      );
    } else if (r.result.rawDays == 0) {
      add(
        'Same-day sale: intraday trades are taxed as speculative business income, not STCG. '
        'A 1-day holding period is used, so annualised figures are extreme.',
        r,
      );
    }
  }
  return [
    for (final e in byMessage.entries)
      e.value.length == results.length
          ? e.key
          : '${e.value.join(', ')}: ${e.key}',
  ];
}

class _WarningsCard extends StatelessWidget {
  const _WarningsCard(this.messages);

  final List<String> messages;

  @override
  Widget build(BuildContext context) {
    final warn = AppColors.of(context).warn;
    return Card(
      color: warn.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: warn.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            for (final m in messages)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 18, color: warn),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        m,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---- Quick check ---------------------------------------------------------

/// Type any return and see the selling and buying price for it, using the
/// shared trade inputs.
class _QuickCheckCard extends StatefulWidget {
  const _QuickCheckCard();

  @override
  State<_QuickCheckCard> createState() => _QuickCheckCardState();
}

class _QuickCheckCardState extends State<_QuickCheckCard> {
  double _pct = 10;
  bool _perYear = true;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final inputs = state.current.base;
    final options = state.optionsFor(state.current);
    final ready = inputs.buyPrice > 0 && inputs.quantity > 0;
    final days = math.max(1, calendarDays(inputs.buyDate, inputs.sellDate));
    final period = _perYear
        ? periodReturnForAnnual(inputs, _pct, options: options)
        : _pct / 100;
    final sell = ready
        ? sellPriceForReturn(inputs, period, options: options)
        : null;
    final buy = ready && inputs.sellPrice > 0
        ? buyPriceForReturn(inputs, period, options: options)
        : null;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    String vs(double? price, double reference) {
      if (price == null || reference <= 0) return '';
      final diff = (price - reference) / reference;
      return '${diff >= 0 ? '+' : ''}${formatPercent(diff)} vs ${formatMoney(reference)}';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bolt, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Quick check: any return',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 130,
                  child: NumberInput(
                    key: const ValueKey('quick-check-pct'),
                    label: 'Return you want',
                    value: _pct,
                    kind: FieldKind.percent,
                    onChanged: (v) => setState(() => _pct = v ?? 0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: false, label: Text('Total')),
                      ButtonSegment(value: true, label: Text('Per year')),
                    ],
                    selected: {_perYear},
                    onSelectionChanged: (v) =>
                        setState(() => _perYear = v.first),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _perYear
                  ? '${formatPlain(_pct, maxDecimals: 2)}% a year over $days day${days == 1 ? '' : 's'} = '
                        '${formatPercent(period)} net on this trade (compounded).'
                  : '${formatPlain(_pct, maxDecimals: 2)}% net on this trade over $days day${days == 1 ? '' : 's'}.',
              style: muted,
            ),
            const SizedBox(height: 12),
            if (!ready)
              Text('Enter a purchase price and quantity first.', style: muted)
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _QuickResult(
                      label: 'Sell at',
                      price: sell,
                      note: vs(sell, inputs.buyPrice),
                      color: colors.gain,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickResult(
                      label: 'Buy at most',
                      price: buy,
                      note: inputs.sellPrice > 0
                          ? vs(buy, inputs.sellPrice)
                          : 'Enter a selling price',
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Text(
              'After brokerage, charges and tax, using the shared inputs. Sell price keeps your purchase price; '
              'buy price keeps your selling price.',
              style: muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickResult extends StatelessWidget {
  const _QuickResult({
    required this.label,
    required this.price,
    required this.note,
    required this.color,
  });

  final String label;
  final double? price;
  final String note;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          Text(
            formatMoney(price),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          if (note.isNotEmpty) Text(note, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

// ---- Summary cards ---------------------------------------------------------

class _SummaryCards extends StatelessWidget {
  const _SummaryCards(this.results);

  final List<ScenarioResult> results;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final r in results)
              Padding(
                padding: EdgeInsets.only(right: r == results.last ? 0 : 12),
                child: SizedBox(width: 272, child: _SummaryCard(r)),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(this.r);

  final ScenarioResult r;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final res = r.result;
    final muted = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    if (!r.hasInputs) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scenario ${r.index + 1} · ${r.scenario.label}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Text(
                'Enter a purchase price and quantity to see results.',
                style: muted,
              ),
            ],
          ),
        ),
      );
    }
    final tone = colors.signed(res.netProfit);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (tone ?? theme.colorScheme.primary).withValues(alpha: 0.14),
              Colors.transparent,
            ],
            stops: const [0, 0.7],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Scenario ${r.index + 1} · ${r.scenario.label}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (r.scenario.overrides.isNotEmpty)
                  Tooltip(
                    message: 'Has its own values',
                    child: Icon(
                      Icons.tune,
                      size: 16,
                      color: colors.overrideDot,
                    ),
                  ),
                ProfitDot(value: res.netProfit),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              res.netProfit >= 0
                  ? 'Net profit after tax & charges'
                  : 'Net loss after tax & charges',
              style: muted,
            ),
            Text(
              formatMoney(res.netProfit),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: tone,
              ),
            ),
            const SizedBox(height: 8),
            ProfitBadge(
              value: res.netReturn,
              label: '${formatPercent(res.netReturn)} on investment',
              compact: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Stat(
                  'Simple a year',
                  formatPercent(res.simpleAnnualised),
                  colors.signed(res.simpleAnnualised),
                ),
                _Stat('CAGR', formatPercent(res.cagr), colors.signed(res.cagr)),
              ],
            ),
            const Divider(height: 24),
            Text(
              'Sell price for ${formatPlain(r.scenario.targetReturnPct, maxDecimals: 2)}% a year',
              style: muted,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _Stat('Simple basis', formatMoney(res.targetPriceSimple)),
                _Stat('CAGR basis', formatMoney(res.targetPriceCagr)),
              ],
            ),
            const SizedBox(height: 10),
            _GapLine(current: res.sellPrice, target: res.targetPriceCagr),
            const Divider(height: 24),
            Text(
              'Buy price for ${formatPlain(r.scenario.targetReturnPct, maxDecimals: 2)}% a year',
              style: muted,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _Stat('Simple basis', formatMoney(res.targetBuyPriceSimple)),
                _Stat('CAGR basis', formatMoney(res.targetBuyPriceCagr)),
              ],
            ),
            const SizedBox(height: 10),
            _BuyGapLine(
              current: r.inputs.buyPrice,
              target: res.targetBuyPriceCagr,
            ),
            const Divider(height: 24),
            Text(
              'Buy target ${formatPlain(res.buyTargetPct, maxDecimals: 2)}%',
              style: muted,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _Stat('Buy on a dip at', formatMoney(res.dipBuyPrice)),
                _Stat('Highest buy price', formatMoney(res.maxBuyPrice)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, [this.color]);

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compares the purchase price with the highest price that reaches the
/// scenario's target.
class _BuyGapLine extends StatelessWidget {
  const _BuyGapLine({required this.current, required this.target});

  final double current;
  final double? target;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final style = Theme.of(context).textTheme.bodySmall;
    final t = target;
    final (IconData icon, Color color, String text) = switch (t) {
      null => (Icons.block, colors.loss, 'Not reachable at this selling price'),
      _ when current - t <= 0.004 => (
        Icons.check_circle_outline,
        colors.gain,
        'Your purchase price is within this target',
      ),
      _ => (
        Icons.trending_down,
        colors.warn,
        'Buy ${formatMoney(current - t)} lower per share '
            '(−${formatPercent((current - t) / current)})',
      ),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: style?.copyWith(color: color)),
        ),
      ],
    );
  }
}

class _GapLine extends StatelessWidget {
  const _GapLine({required this.current, required this.target});

  final double current;
  final double? target;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final style = Theme.of(context).textTheme.bodySmall;
    final t = target;
    final (IconData icon, Color? color, String text) = switch (t) {
      null => (
        Icons.block,
        colors.loss,
        'Target not reachable with these inputs',
      ),
      _ when current <= 0 => (
        Icons.info_outline,
        null,
        'Enter a sell price to compare',
      ),
      _ when t - current <= 0.004 => (
        Icons.check_circle_outline,
        colors.gain,
        'Your sell price meets this target',
      ),
      _ => (
        Icons.trending_up,
        colors.warn,
        'Needs ${formatMoney(t - current)} more per share (+${formatPercent((t - current) / current)})',
      ),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: style?.copyWith(color: color)),
        ),
      ],
    );
  }
}

// ---- Comparison table --------------------------------------------------------

class RowSpec {
  const RowSpec(
    this.label,
    this.value, {
    this.bold = false,
    this.shaded = false,
    this.sign,
  });

  final String label;
  final String Function(TradeResult r) value;
  final bool bold;
  final bool shaded;

  /// When set, the value is coloured green/red by the sign of this number.
  final double Function(TradeResult r)? sign;
}

RowSpec _rowSpec(ResultRow row) {
  RowSpec money(double Function(TradeResult r) f, {bool signed = false}) =>
      RowSpec(
        row.label,
        (r) => formatMoney(f(r)),
        bold: row.bold,
        shaded: row.shaded,
        sign: signed ? f : null,
      );
  RowSpec pct(double Function(TradeResult r) f) => RowSpec(
    row.label,
    (r) => formatPercent(f(r)),
    bold: row.bold,
    shaded: row.shaded,
    sign: f,
  );

  return switch (row) {
    ResultRow.grossPurchase => money((r) => r.grossPurchaseValue),
    ResultRow.buyCharges => money((r) => r.buyChargesExclStt),
    ResultRow.buyStt => money((r) => r.buyStt),
    ResultRow.totalInvestment => money((r) => r.totalInvestment),
    ResultRow.grossSale => money((r) => r.grossSaleValue),
    ResultRow.sellBrokerage => money((r) => r.sellBrokerage),
    ResultRow.otherSellCharges => money((r) => r.otherSellCharges),
    ResultRow.sellStt => money((r) => r.sellStt),
    ResultRow.exitLoad => money((r) => r.exitLoad),
    ResultRow.totalSellingCosts => money((r) => r.totalSellingCosts),
    ResultRow.netSaleProceeds => money((r) => r.netSaleProceeds),
    ResultRow.taxableGain => money((r) => r.taxableGain, signed: true),
    ResultRow.taxType => RowSpec(
      row.label,
      (r) =>
          '${r.isLongTerm ? 'LTCG' : 'STCG'} @ ${formatPlain(r.taxRatePct, maxDecimals: 2)}%'
          '${r.exemptionUsed > 0 ? '\n${formatMoney(r.exemptionUsed)} exempt' : ''}',
    ),
    ResultRow.tax => money((r) => r.tax),
    ResultRow.netAfterTax => money((r) => r.netAfterTax),
    ResultRow.netProfit => money((r) => r.netProfit, signed: true),
    ResultRow.netReturn => pct((r) => r.netReturn),
    ResultRow.holdingDays => RowSpec(row.label, (r) => '${r.holdingDays}'),
    ResultRow.simpleAnnualised => pct((r) => r.simpleAnnualised),
    ResultRow.cagr => pct((r) => r.cagr),
    ResultRow.targetSimple => RowSpec(
      row.label,
      (r) => formatMoney(r.targetPriceSimple),
      bold: true,
      shaded: true,
    ),
    ResultRow.targetCagr => RowSpec(
      row.label,
      (r) => formatMoney(r.targetPriceCagr),
      bold: true,
      shaded: true,
    ),
    ResultRow.targetBuySimple => RowSpec(
      row.label,
      (r) => formatMoney(r.targetBuyPriceSimple),
      bold: true,
      shaded: true,
    ),
    ResultRow.targetBuyCagr => RowSpec(
      row.label,
      (r) => formatMoney(r.targetBuyPriceCagr),
      bold: true,
      shaded: true,
    ),
    ResultRow.dipBuyPrice => RowSpec(
      row.label,
      (r) =>
          '${formatMoney(r.dipBuyPrice)}\n${formatPlain(r.buyTargetPct, maxDecimals: 2)}% below',
      bold: true,
    ),
    ResultRow.maxBuyPrice => RowSpec(
      row.label,
      (r) =>
          '${formatMoney(r.maxBuyPrice)}\nfor ${formatPlain(r.buyTargetPct, maxDecimals: 2)}% net',
      bold: true,
    ),
  };
}

final _breakdownRows = <RowSpec>[
  RowSpec('Purchase brokerage', (r) => formatMoney(r.breakdown!.buyBrokerage)),
  RowSpec('Stamp duty', (r) => formatMoney(r.breakdown!.stampDuty)),
  RowSpec(
    'Exchange charges (buy)',
    (r) => formatMoney(r.breakdown!.buyExchange),
  ),
  RowSpec('SEBI fee (buy)', (r) => formatMoney(r.breakdown!.buySebi)),
  RowSpec('GST (buy)', (r) => formatMoney(r.breakdown!.buyGst)),
  RowSpec('STT (buy)', (r) => formatMoney(r.breakdown!.buyStt)),
  RowSpec(
    'Total buy charges incl. STT',
    (r) => formatMoney(r.buyChargesExclStt + r.buyStt),
    bold: true,
    shaded: true,
  ),
  RowSpec('Brokerage on sale', (r) => formatMoney(r.breakdown!.sellBrokerage)),
  RowSpec(
    'Exchange charges (sell)',
    (r) => formatMoney(r.breakdown!.sellExchange),
  ),
  RowSpec('SEBI fee (sell)', (r) => formatMoney(r.breakdown!.sellSebi)),
  RowSpec('DP charge', (r) => formatMoney(r.breakdown!.dpCharge)),
  RowSpec('GST (sell)', (r) => formatMoney(r.breakdown!.sellGst)),
  RowSpec('STT (sell)', (r) => formatMoney(r.breakdown!.sellStt)),
  RowSpec(
    'Total sell charges incl. STT (excl. exit load)',
    (r) => formatMoney(r.sellBrokerage + r.otherSellCharges + r.sellStt),
    bold: true,
    shaded: true,
  ),
];

/// Metric labels in a fixed left column; one column per scenario that
/// scrolls sideways when they don't all fit.
class ScenarioTable extends StatelessWidget {
  const ScenarioTable({
    super.key,
    required this.title,
    required this.results,
    required this.rows,
  });

  final String title;
  final List<ScenarioResult> results;
  final List<RowSpec> rows;

  static const _minColumnWidth = 128.0;
  static const _headerHeight = 62.0;
  static const _rowHeight = 50.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final line = BorderSide(
      color: theme.colorScheme.outlineVariant,
      width: 0.6,
    );

    Widget cell({
      required double height,
      double? width,
      required Widget child,
      Color? background,
      bool right = false,
      bool divider = false,
    }) => Container(
      width: width,
      height: height,
      alignment: right ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: background,
        border: Border(bottom: line, right: divider ? line : BorderSide.none),
      ),
      child: child,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 560;
        final labelWidth = narrow ? 164.0 : 300.0;
        final columnWidth = math.max(
          _minColumnWidth,
          (constraints.maxWidth - labelWidth - 2) / math.max(1, results.length),
        );
        final labelStyle = theme.textTheme.bodySmall?.copyWith(
          fontSize: narrow ? 11.5 : 12.5,
        );
        final valueStyle = theme.textTheme.bodyMedium?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        );
        final headerBg = theme.colorScheme.surfaceContainerHigh;

        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: colors.headerBg,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: labelWidth,
                    child: Column(
                      children: [
                        cell(
                          height: _headerHeight,
                          background: headerBg,
                          divider: true,
                          child: Text(
                            'Metric',
                            style: theme.textTheme.labelLarge,
                          ),
                        ),
                        for (final row in rows)
                          cell(
                            height: _rowHeight,
                            background: row.shaded ? colors.shadedRow : null,
                            divider: true,
                            child: Text(
                              row.label,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: labelStyle?.copyWith(
                                fontWeight: row.bold ? FontWeight.w700 : null,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              for (final r in results)
                                cell(
                                  width: columnWidth,
                                  height: _headerHeight,
                                  background: headerBg,
                                  right: true,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Scenario ${r.index + 1}',
                                        style: theme.textTheme.labelLarge,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        r.scenario.label,
                                        style: theme.textTheme.labelSmall,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          for (final row in rows)
                            Row(
                              children: [
                                for (final r in results)
                                  cell(
                                    width: columnWidth,
                                    height: _rowHeight,
                                    background: row.shaded
                                        ? colors.shadedRow
                                        : null,
                                    right: true,
                                    child: _valueText(
                                      row,
                                      r,
                                      valueStyle,
                                      colors,
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _valueText(
    RowSpec row,
    ScenarioResult r,
    TextStyle? style,
    AppColors colors,
  ) {
    final text = r.hasInputs ? row.value(r.result) : '—';
    return Text(
      text,
      textAlign: TextAlign.right,
      maxLines: 2,
      style: style?.copyWith(
        fontWeight: row.bold ? FontWeight.w700 : null,
        color: row.sign == null || !r.hasInputs
            ? null
            : colors.signed(row.sign!(r.result)),
        fontSize: text.contains('\n') ? 12 : null,
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const ValueKey('notes'),
        leading: const Icon(Icons.info_outline),
        title: const Text(
          'Important notes',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          for (final (i, note) in importantNotes.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 20, child: Text('${i + 1}.', style: style)),
                  Expanded(child: Text(note, style: style)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
