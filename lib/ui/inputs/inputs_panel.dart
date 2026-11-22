import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../engine/calculator.dart';
import '../../models/input_field.dart';
import '../../models/scenario.dart';
import '../../state/app_state.dart';
import '../../utils/format.dart';
import '../theme.dart';
import 'fields.dart';
import 'live_price.dart';

class InputsPanel extends StatelessWidget {
  const InputsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scenario = state.selectedScenario;
    final auto = state.current.autoCharges;
    final inputs = state.scopeInputs;
    final months = state.settings.longTermMonths;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      children: [
        const ScenarioSelector(),
        const SizedBox(height: 12),
        if (scenario == null)
          const ScenariosCard()
        else
          ScenarioHeader(scenario: scenario),
        const SizedBox(height: 12),
        _Section(
          title: 'Trade details',
          icon: Icons.receipt_long_outlined,
          children: [
            const ScopedField(InputField.shareName),
            const LivePriceBox(),
            const ScopedField(InputField.buyDate),
            const ScopedField(InputField.buyPrice),
            const ScopedField(InputField.quantity),
            const ScopedField(InputField.sellDate),
            const _HoldingDaysField(),
            const ScopedField(InputField.sellPrice),
            const ScopedField(
              InputField.buyTargetPct,
              helper:
                  'Results show the price to buy on a dip of this much, and the highest '
                  'price you can pay to still earn this much after charges and tax.',
            ),
            _HoldingInfo(
              rawDays: calendarDays(inputs.buyDate, inputs.sellDate),
              longTerm: isLongTermHolding(
                inputs.buyDate,
                inputs.sellDate,
                months,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Charges',
          icon: Icons.account_balance_wallet_outlined,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-calculate statutory charges'),
              subtitle: const Text(
                'STT, stamp duty, exchange, SEBI, DP and GST from the rates in Settings',
              ),
              value: auto,
              onChanged: state.setAutoCharges,
            ),
            if (!auto) ...const [
              ScopedField(InputField.buyCharges),
              ScopedField(InputField.buyStt, helper: 'Not deductible for tax'),
              ScopedField(InputField.sellBrokerage),
              ScopedField(InputField.otherSellCharges),
              ScopedField(InputField.sellStt, helper: 'Not deductible for tax'),
            ] else
              ..._autoChargeFields(state),
          ],
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Tax & advanced',
          icon: Icons.percent,
          initiallyExpanded: false,
          children: [
            ScopedField(
              InputField.stcgRatePct,
              helper:
                  'Used when held up to $months months. Default 20% + 4% cess = 20.8%',
            ),
            ScopedField(
              InputField.ltcgRatePct,
              helper:
                  'Used when held over $months months. Default 12.5% + 4% cess = 13%',
            ),
            const ScopedField(
              InputField.ltcgExemption,
              helper: '₹1.25 lakh a year across all your long-term gains. Enter what is left, or 0.',
            ),
            const ScopedField(
              InputField.exitLoadPct,
              helper: 'Keep at 0% for listed shares. Exit loads apply to mutual funds.',
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _autoChargeFields(AppState state) {
    final r = state.scopeResult;
    final b = r.breakdown!;
    return [
      const ScopedField(InputField.buyCharges, label: 'Purchase brokerage'),
      ComputedValue(
        label: 'Buy charges: stamp duty, exchange, SEBI, GST',
        value: formatMoney(b.buyChargesExclStt - b.buyBrokerage),
      ),
      ComputedValue(label: 'Purchase-side STT', value: formatMoney(b.buyStt)),
      const ScopedField(InputField.sellBrokerage),
      ComputedValue(
        label: 'Other selling charges: exchange, SEBI, DP, GST',
        value: formatMoney(b.otherSellCharges),
      ),
      ComputedValue(label: 'Selling-side STT', value: formatMoney(b.sellStt)),
    ];
  }
}

/// Shows the days between the purchase and selling dates; typing a number
/// moves the selling date.
class _HoldingDaysField extends StatelessWidget {
  const _HoldingDaysField();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scenario = state.selectedScenario;
    final inputs = state.scopeInputs;
    final overridden = state.isOverridden(InputField.sellDate);
    return NumberInput(
      key: ValueKey('${state.current.id}/${scenario?.id ?? 'all'}/holdingDays'),
      label: 'Holding period (days)',
      value: calendarDays(inputs.buyDate, inputs.sellDate).toDouble(),
      kind: FieldKind.quantity,
      helper: 'Type a number of days to set the selling date from the purchase date.',
      style: scenario == null
          ? FieldStyle.normal
          : overridden
          ? FieldStyle.overridden
          : FieldStyle.inherited,
      onChanged: (v) {
        if (v == null) return;
        final b = inputs.buyDate;
        state.setField(
          InputField.sellDate,
          DateTime(b.year, b.month, b.day + v.round()),
        );
      },
    );
  }
}

class _HoldingInfo extends StatelessWidget {
  const _HoldingInfo({required this.rawDays, required this.longTerm});

  final int rawDays;
  final bool longTerm;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme.bodySmall;
    final String message;
    Color? color;
    if (rawDays < 0) {
      message = 'Selling date is before the purchase date. A 1-day holding period is used.';
      color = colors.loss;
    } else if (rawDays == 0) {
      message = 'Same-day sale. Intraday trades are taxed as business income, not STCG.';
      color = colors.warn;
    } else {
      message =
          'Holding period: $rawDays day${rawDays == 1 ? '' : 's'} · '
          '${longTerm ? 'Long-term (LTCG)' : 'Short-term (STCG)'}';
    }
    return Row(
      children: [
        Icon(Icons.schedule, size: 16, color: color ?? text?.color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(message, style: text?.copyWith(color: color)),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
    this.initiallyExpanded = true,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    // Expanded state lives in AppState rather than PageStorage: a
    // PageStorageKey here would collide with the scroll offsets the text
    // fields inside store under the same identifier.
    final state = context.read<AppState>();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: ValueKey('section-$title'),
        initiallyExpanded: state.isSectionExpanded(
          title,
          fallback: initiallyExpanded,
        ),
        onExpansionChanged: (expanded) =>
            state.setSectionExpanded(title, expanded),
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          for (final (i, child) in children.indexed)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 14),
              child: child,
            ),
        ],
      ),
    );
  }
}

/// "All scenarios | 10% target | 25% target | ... | + Add"
class ScenarioSelector extends StatelessWidget {
  const ScenarioSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final selected = state.selectedScenario?.id;
    final scenarios = state.current.scenarios;
    final dot = AppColors.of(context).overrideDot;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('All scenarios'),
            selected: selected == null,
            onSelected: (_) => state.selectScenario(null),
          ),
          for (final s in scenarios)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.label),
                    if (s.overrides.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Tooltip(
                        message: 'Has its own values',
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: dot,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                selected: selected == s.id,
                onSelected: (_) => state.selectScenario(s.id),
              ),
            ),
          if (scenarios.length < AppState.maxScenarios)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                tooltip: 'Add scenario',
                onPressed: state.addScenario,
              ),
            ),
        ],
      ),
    );
  }
}

/// Shown on "All scenarios": every scenario's name and target in one place.
class ScenariosCard extends StatelessWidget {
  const ScenariosCard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scenarios = state.current.scenarios;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Scenarios & target returns',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Every scenario uses the values below. To give one scenario a different value '
              '(say, another sell price), select it above and change that field.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            for (final s in scenarios)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ScenarioRow(
                  scenario: s,
                  canDelete: scenarios.length > 1,
                ),
              ),
            if (scenarios.length < AppState.maxScenarios)
              TextButton.icon(
                onPressed: state.addScenario,
                icon: const Icon(Icons.add),
                label: const Text('Add scenario'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScenarioRow extends StatelessWidget {
  const _ScenarioRow({required this.scenario, required this.canDelete});

  final Scenario scenario;
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Row(
      children: [
        Expanded(flex: 3, child: _NameField(scenario: scenario)),
        const SizedBox(width: 8),
        Expanded(flex: 2, child: _TargetField(scenario: scenario)),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Remove scenario',
          onPressed: canDelete ? () => state.removeScenario(scenario.id) : null,
        ),
      ],
    );
  }
}

class _NameField extends StatelessWidget {
  const _NameField({required this.scenario});

  final Scenario scenario;

  @override
  Widget build(BuildContext context) => TextInput(
    key: ValueKey('name-${scenario.id}'),
    label: 'Name',
    value: scenario.customName,
    hint: '${formatPlain(scenario.targetReturnPct, maxDecimals: 2)}% target',
    onChanged: (v) => context.read<AppState>().renameScenario(scenario.id, v),
  );
}

class _TargetField extends StatelessWidget {
  const _TargetField({required this.scenario});

  final Scenario scenario;

  @override
  Widget build(BuildContext context) => NumberInput(
    key: ValueKey('target-${scenario.id}'),
    label: 'Target a year',
    value: scenario.targetReturnPct,
    kind: FieldKind.percent,
    onChanged: (v) => context.read<AppState>().setTarget(scenario.id, v ?? 0),
  );
}

/// Shown when one scenario is selected.
class ScenarioHeader extends StatelessWidget {
  const ScenarioHeader({super.key, required this.scenario});

  final Scenario scenario;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final index = state.current.scenarios.indexWhere(
      (s) => s.id == scenario.id,
    );
    final count = scenario.overrides.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Scenario ${index + 1}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (count > 0)
                  TextButton.icon(
                    onPressed: () => state.clearOverrides(scenario.id),
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: Text('Clear $count change${count == 1 ? '' : 's'}'),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remove scenario',
                  onPressed: state.current.scenarios.length > 1
                      ? () => state.removeScenario(scenario.id)
                      : null,
                ),
              ],
            ),
            Text(
              'Greyed fields use the shared value. Type in any field to change it for this scenario only; '
              'it turns yellow. Tap ↺ to go back to the shared value.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(flex: 3, child: _NameField(scenario: scenario)),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: _TargetField(scenario: scenario)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
