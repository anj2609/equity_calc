import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_settings.dart';
import '../models/input_field.dart';
import '../models/result_row.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import 'dialogs.dart';
import 'inputs/fields.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.settings;
    final rates = s.chargeRates;
    final theme = Theme.of(context);
    void set(AppSettings next) => state.updateSettings(next);

    Widget pct(
      String key,
      String label,
      double value,
      void Function(double v) onChanged, {
      String? helper,
    }) => NumberInput(
      key: ValueKey(key),
      label: label,
      value: value,
      kind: FieldKind.percent,
      helper: helper,
      onChanged: (v) => onChanged(v ?? 0),
    );
    Widget money(
      String key,
      String label,
      double value,
      void Function(double v) onChanged, {
      String? helper,
    }) => NumberInput(
      key: ValueKey(key),
      label: label,
      value: value,
      kind: FieldKind.money,
      helper: helper,
      onChanged: (v) => onChanged(v ?? 0),
    );
    Widget pair(Widget a, Widget b) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: 10),
        Expanded(child: b),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 40),
        children: [
          _Group(
            title: 'Tax defaults',
            subtitle: 'Used for new calculations. Defaults follow the rates from Budget 2024; change them if the law changes.',
            children: [
              pair(
                pct(
                  'stcg',
                  'STCG base rate',
                  s.stcgBasePct,
                  (v) => set(s.copyWith(stcgBasePct: v)),
                ),
                pct(
                  'ltcg',
                  'LTCG base rate',
                  s.ltcgBasePct,
                  (v) => set(s.copyWith(ltcgBasePct: v)),
                ),
              ),
              pair(
                pct(
                  'surcharge',
                  'Surcharge',
                  s.surchargePct,
                  (v) => set(s.copyWith(surchargePct: v)),
                  helper: 'Only for high incomes',
                ),
                pct(
                  'cess',
                  'Health & education cess',
                  s.cessPct,
                  (v) => set(s.copyWith(cessPct: v)),
                ),
              ),
              Text(
                'Effective rates: STCG ${formatPlain(s.stcgEffectivePct, maxDecimals: 3)}% · '
                'LTCG ${formatPlain(s.ltcgEffectivePct, maxDecimals: 3)}%',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              pair(
                money(
                  'exemption',
                  'LTCG exemption a year',
                  s.ltcgExemption,
                  (v) => set(s.copyWith(ltcgExemption: v)),
                ),
                NumberInput(
                  key: const ValueKey('months'),
                  label: 'Long-term after (months)',
                  value: s.longTermMonths.toDouble(),
                  kind: FieldKind.quantity,
                  onChanged: (v) => set(
                    s.copyWith(longTermMonths: (v ?? 12).round().clamp(1, 240)),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text(
                    'Apply these tax rates to the open calculation',
                  ),
                  onPressed: () {
                    state.applyTaxDefaultsToCurrent();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Tax rates applied to “${state.current.displayName}”',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          _Group(
            title: 'New calculation defaults',
            children: [
              pair(
                money(
                  'buyBrk',
                  'Purchase brokerage',
                  s.defaultBuyBrokerage,
                  (v) => set(s.copyWith(defaultBuyBrokerage: v)),
                ),
                money(
                  'sellBrk',
                  'Brokerage on sale',
                  s.defaultSellBrokerage,
                  (v) => set(s.copyWith(defaultSellBrokerage: v)),
                ),
              ),
              TextInput(
                key: const ValueKey('targets'),
                label: 'Scenario targets (% a year, comma separated)',
                value: s.defaultTargets
                    .map((t) => formatPlain(t, maxDecimals: 2))
                    .join(', '),
                hint: '10, 25, 50',
                onChanged: (text) {
                  final targets = [
                    for (final part in text.split(',')) ?parseNumber(part),
                  ];
                  if (targets.isNotEmpty) {
                    set(
                      s.copyWith(
                        defaultTargets: targets
                            .take(AppState.maxScenarios)
                            .toList(),
                      ),
                    );
                  }
                },
              ),
              pct(
                'buyTarget',
                'Buy target',
                s.defaultBuyTargetPct,
                (v) => set(s.copyWith(defaultBuyTargetPct: v)),
                helper: 'For the buy-on-dip price and the highest buy price',
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start with auto statutory charges on'),
                value: s.defaultAutoCharges,
                onChanged: (v) => set(s.copyWith(defaultAutoCharges: v)),
              ),
            ],
          ),
          _Group(
            title: 'Auto charge rates',
            subtitle:
                'Used when “Auto-calculate statutory charges” is on. Estimates for equity delivery trades; '
                'check your broker’s contract note.',
            children: [
              pair(
                pct(
                  'sttBuy',
                  'STT on buy',
                  rates.sttBuyPct,
                  (v) => set(
                    s.copyWith(chargeRates: rates.copyWith(sttBuyPct: v)),
                  ),
                ),
                pct(
                  'sttSell',
                  'STT on sell',
                  rates.sttSellPct,
                  (v) => set(
                    s.copyWith(chargeRates: rates.copyWith(sttSellPct: v)),
                  ),
                ),
              ),
              pair(
                pct(
                  'stamp',
                  'Stamp duty on buy',
                  rates.stampDutyBuyPct,
                  (v) => set(
                    s.copyWith(chargeRates: rates.copyWith(stampDutyBuyPct: v)),
                  ),
                ),
                pct(
                  'exch',
                  'Exchange transaction',
                  rates.exchangeTxnPct,
                  (v) => set(
                    s.copyWith(chargeRates: rates.copyWith(exchangeTxnPct: v)),
                  ),
                ),
              ),
              pair(
                money(
                  'sebi',
                  'SEBI fee per crore',
                  rates.sebiFeePerCrore,
                  (v) => set(
                    s.copyWith(chargeRates: rates.copyWith(sebiFeePerCrore: v)),
                  ),
                ),
                money(
                  'dp',
                  'DP charge per sell',
                  rates.dpChargePerSell,
                  (v) => set(
                    s.copyWith(chargeRates: rates.copyWith(dpChargePerSell: v)),
                  ),
                  helper: 'Before GST',
                ),
              ),
              pct(
                'gst',
                'GST on brokerage & fees',
                rates.gstPct,
                (v) => set(s.copyWith(chargeRates: rates.copyWith(gstPct: v))),
              ),
            ],
          ),
          _Group(
            title: 'Results',
            children: [
              NumberInput(
                key: const ValueKey('days'),
                label: 'Days in a year (for annualising)',
                value: s.daysInYear.toDouble(),
                kind: FieldKind.quantity,
                onChanged: (v) => set(
                  s.copyWith(daysInYear: (v ?? 365).round().clamp(1, 1000)),
                ),
              ),
              Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Rows shown in the results table'),
                  subtitle: Text(
                    '${ResultRow.values.length - s.hiddenRows.length} of ${ResultRow.values.length} shown',
                  ),
                  children: [
                    for (final row in ResultRow.values)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: !s.hiddenRows.contains(row),
                        title: Text(row.label),
                        onChanged: (show) => set(
                          s.copyWith(
                            hiddenRows: show == true
                                ? ({...s.hiddenRows}..remove(row))
                                : {...s.hiddenRows, row},
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          _Group(
            title: 'Appearance',
            children: [
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('System'),
                    icon: Icon(Icons.brightness_auto),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode),
                  ),
                ],
                selected: {s.themeMode},
                onSelectionChanged: (v) => set(s.copyWith(themeMode: v.first)),
              ),
            ],
          ),
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.restore),
              label: const Text('Reset all settings to defaults'),
              onPressed: () async {
                final ok = await confirm(
                  context,
                  title: 'Reset settings?',
                  message:
                      'Tax defaults, charge rates, new-calculation defaults and visible rows go back to '
                      'their original values. Your saved calculations are not changed.',
                  action: 'Reset',
                );
                if (ok) state.resetSettings();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children, this.subtitle});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: theme.textTheme.bodySmall),
              ],
              for (final child in children)
                Padding(padding: const EdgeInsets.only(top: 14), child: child),
            ],
          ),
        ),
      ),
    );
  }
}
