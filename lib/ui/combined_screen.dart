import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../engine/portfolio.dart';
import '../models/calculation.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import 'export/excel_export.dart';
import 'theme.dart';
import 'widgets/profit_indicator.dart';

/// Overall result of several saved calculations, with losses set off
/// across shares and one chosen scenario per share.
class CombinedScreen extends StatefulWidget {
  const CombinedScreen({super.key, required this.ids});

  final List<String> ids;

  @override
  State<CombinedScreen> createState() => _CombinedScreenState();
}

class _CombinedScreenState extends State<CombinedScreen> {
  final Map<String, int> _scenario = {};

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final calcs = [for (final id in widget.ids) ?state.savedById(id)];
    final p = state.combine(calcs, scenarioIndex: _scenario);
    final skipped = calcs.length - p.items.length;
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final s = state.settings;

    return Scaffold(
      appBar: AppBar(
        title: Text('Combined · ${calcs.length} shares'),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.grid_on_outlined),
              tooltip: 'Export to Excel',
              onPressed: () =>
                  exportToExcel(context, calcs, scenarioIndex: _scenario),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          _HeroCard(p: p),
          if (skipped > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '$skipped calculation${skipped == 1 ? ' is' : 's are'} left out because '
                '${skipped == 1 ? 'it has' : 'they have'} no purchase price or quantity.',
                style: theme.textTheme.bodySmall?.copyWith(color: colors.warn),
              ),
            ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tax with losses set off',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Uses STCG ${formatPlain(s.stcgEffectivePct, maxDecimals: 2)}% and LTCG '
                    '${formatPlain(s.ltcgEffectivePct, maxDecimals: 2)}% from Settings. Short-term losses reduce any gain; '
                    'long-term losses only long-term gains. The LTCG exemption is used once.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  _Line(
                    'Net short-term gain / (loss)',
                    formatMoney(p.stcgNet),
                    signed: p.stcgNet,
                  ),
                  _Line(
                    'Net long-term gain / (loss)',
                    formatMoney(p.ltcgNet),
                    signed: p.ltcgNet,
                  ),
                  _Line('LTCG exemption used', formatMoney(p.exemptionUsed)),
                  _Line('STCG tax', formatMoney(p.stcgTax)),
                  _Line('LTCG tax', formatMoney(p.ltcgTax)),
                  const Divider(height: 20),
                  _Line('Total tax', formatMoney(p.tax), bold: true),
                  _Line(
                    'If each share were taxed alone',
                    formatMoney(p.standaloneTax),
                  ),
                  if (p.taxSavedBySetOff > 0.005)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ProfitBadge(
                        value: p.taxSavedBySetOff,
                        label:
                            'Set-off saves ${formatMoney(p.taxSavedBySetOff)} tax',
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Shares',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          for (final c in calcs) ...[
            _ShareCard(
              calc: c,
              item: p.items.where((i) => i.name == c.displayName).firstOrNull,
              scenarioIndex: _scenario[c.id] ?? 0,
              onScenario: (i) => setState(() => _scenario[c.id] = i),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.p});

  final PortfolioResult p;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final muted = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final tone = colors.signed(p.netProfit);
    return Card(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (tone ?? theme.colorScheme.primary).withValues(alpha: 0.16),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Combined net profit after tax & charges',
                    style: muted,
                  ),
                ),
                ProfitDot(
                  value: p.items.isEmpty ? null : p.netProfit,
                  size: 10,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              p.items.isEmpty ? '—' : formatMoney(p.netProfit),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: tone,
              ),
            ),
            const SizedBox(height: 8),
            if (p.items.isNotEmpty)
              ProfitBadge(
                value: p.netReturn,
                label:
                    '${formatPercent(p.netReturn)} on ${formatMoney(p.invested)}',
              ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                _Stat('Invested', formatMoney(p.invested)),
                _Stat('Net sale proceeds', formatMoney(p.netSaleProceeds)),
                _Stat('Charges incl. STT', formatMoney(p.charges)),
                _Stat('Tax', formatMoney(p.tax)),
                _Stat(
                  'Annualised (XIRR)',
                  formatPercent(p.xirr),
                  color: p.xirr == null ? null : colors.signed(p.xirr!),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareCard extends StatelessWidget {
  const _ShareCard({
    required this.calc,
    required this.item,
    required this.scenarioIndex,
    required this.onScenario,
  });

  final Calculation calc;
  final PortfolioItem? item;
  final int scenarioIndex;
  final ValueChanged<int> onScenario;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final i = item;
    final gain = i?.result.taxableGain;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProfitDot(value: gain),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    calc.displayName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownButton<int>(
                  value: scenarioIndex.clamp(0, calc.scenarios.length - 1),
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final (k, s) in calc.scenarios.indexed)
                      DropdownMenuItem(
                        value: k,
                        child: Text('S${k + 1} · ${s.label}'),
                      ),
                  ],
                  onChanged: (v) => onScenario(v ?? 0),
                ),
              ],
            ),
            if (i == null)
              Text(
                'No purchase price or quantity yet.',
                style: theme.textTheme.bodySmall,
              )
            else ...[
              Text(
                '${i.inputs.quantity.toStringAsFixed(i.inputs.quantity % 1 == 0 ? 0 : 2)} shares · '
                '${formatDate(i.inputs.buyDate)} → ${formatDate(i.inputs.sellDate)} · '
                '${i.result.isLongTerm ? 'LTCG' : 'STCG'}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [
                  _Stat('Invested', formatMoney(i.result.totalInvestment)),
                  _Stat(
                    'Net sale proceeds',
                    formatMoney(i.result.netSaleProceeds),
                  ),
                  _Stat('Tax if alone', formatMoney(i.result.tax)),
                ],
              ),
              const SizedBox(height: 10),
              ProfitBadge(
                value: gain,
                label: 'Gain before tax ${formatMoney(gain)}',
                compact: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.bold = false, this.signed});

  final String label;
  final String value;
  final bool bold;
  final double? signed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: bold ? FontWeight.w700 : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(
            value,
            style: style?.copyWith(
              color: signed == null
                  ? null
                  : AppColors.of(context).signed(signed!),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
