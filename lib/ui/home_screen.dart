import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../utils/format.dart';
import 'dialogs.dart';
import 'export/excel_export.dart';
import 'inputs/inputs_panel.dart';
import 'results/results_panel.dart';
import 'save_flow.dart';
import 'saved_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'widgets/profit_indicator.dart';

enum _MenuAction { newCalc, export, combined, settings }

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _wideBreakpoint = 960.0;

  Future<void> _onMenu(BuildContext context, _MenuAction action) async {
    final state = context.read<AppState>();
    switch (action) {
      case _MenuAction.newCalc:
        if (await resolveUnsaved(context)) state.newCalculation();
      case _MenuAction.export:
        await exportToExcel(context, [state.current]);
      case _MenuAction.combined:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SavedScreen(startSelecting: true),
          ),
        );
      case _MenuAction.settings:
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dirty = context.select<AppState, bool>((s) => s.isDirty);
    // Android back button: offer to save before leaving the app.
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && await resolveUnsaved(context)) SystemNavigator.pop();
      },
      child: _layout(context),
    );
  }

  Widget _layout(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _wideBreakpoint) {
          return Scaffold(
            appBar: _appBar(context),
            body: Row(
              children: [
                SizedBox(
                  width: math.min(500, constraints.maxWidth * 0.42),
                  child: const InputsPanel(),
                ),
                const VerticalDivider(width: 1),
                const Expanded(child: ResultsPanel()),
              ],
            ),
          );
        }
        return DefaultTabController(
          length: 2,
          child: Builder(
            builder: (context) => Scaffold(
              appBar: _appBar(
                context,
                bottom: const TabBar(
                  tabs: [
                    Tab(icon: Icon(Icons.edit_outlined), text: 'Inputs'),
                    Tab(
                      icon: Icon(Icons.table_chart_outlined),
                      text: 'Results',
                    ),
                  ],
                ),
              ),
              body: const TabBarView(children: [InputsPanel(), ResultsPanel()]),
              bottomNavigationBar: const _LiveStrip(),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _appBar(
    BuildContext context, {
    PreferredSizeWidget? bottom,
  }) {
    final state = context.watch<AppState>();
    return AppBar(
      titleSpacing: 16,
      title: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          final name = await promptText(
            context,
            title: 'Rename calculation',
            initial: state.current.displayName,
            hint: 'e.g. Reliance – Diwali buy',
          );
          if (name != null) state.renameCalculation(state.current.id, name);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  state.current.displayName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.edit, size: 16),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Badge(
            isLabelVisible: state.isDirty,
            smallSize: 8,
            child: Icon(
              state.isDirty || !state.isCurrentSaved
                  ? Icons.save_outlined
                  : Icons.check_circle_outline,
            ),
          ),
          tooltip: state.isDirty
              ? 'Save changes'
              : (state.isCurrentSaved ? 'Saved' : 'Save'),
          onPressed: state.isDirty || !state.isCurrentSaved
              ? () => saveWithPrompt(context)
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.folder_open_outlined),
          tooltip: 'Saved calculations',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SavedScreen()),
          ),
        ),
        PopupMenuButton<_MenuAction>(
          tooltip: 'More',
          onSelected: (action) => _onMenu(context, action),
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: _MenuAction.newCalc,
              child: ListTile(
                leading: Icon(Icons.note_add_outlined),
                title: Text('New calculation'),
              ),
            ),
            PopupMenuItem(
              value: _MenuAction.export,
              child: ListTile(
                leading: Icon(Icons.grid_on_outlined),
                title: Text('Export to Excel'),
              ),
            ),
            PopupMenuItem(
              value: _MenuAction.combined,
              child: ListTile(
                leading: Icon(Icons.stacked_line_chart),
                title: Text('Combine shares'),
              ),
            ),
            PopupMenuItem(
              value: _MenuAction.settings,
              child: ListTile(
                leading: Icon(Icons.settings_outlined),
                title: Text('Settings'),
              ),
            ),
          ],
        ),
      ],
      bottom: bottom,
    );
  }
}

/// On phones, keeps each scenario's net profit and target price in view while
/// editing inputs. Tapping it opens the Results tab.
class _LiveStrip extends StatelessWidget {
  const _LiveStrip();

  @override
  Widget build(BuildContext context) {
    final tabs = DefaultTabController.of(context);
    return AnimatedBuilder(
      animation: tabs,
      builder: (context, _) {
        if (tabs.index != 0) return const SizedBox.shrink();
        final results = context.watch<AppState>().results;
        final theme = Theme.of(context);
        final colors = AppColors.of(context);
        return Material(
          color: theme.colorScheme.surfaceContainer,
          child: SafeArea(
            top: false,
            child: InkWell(
              onTap: () => tabs.animateTo(1),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    for (final r in results)
                      Padding(
                        padding: const EdgeInsets.only(right: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              r.scenario.label,
                              style: theme.textTheme.labelSmall,
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ProfitDot(
                                  value: r.hasInputs
                                      ? r.result.netProfit
                                      : null,
                                  size: 7,
                                ),
                                Text(
                                  r.hasInputs
                                      ? formatMoney(r.result.netProfit)
                                      : '—',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: r.hasInputs
                                        ? colors.signed(r.result.netProfit)
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Sell ${r.hasInputs ? formatMoney(r.result.targetPriceCagr) : '—'}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.gain,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Buy ${r.hasInputs ? formatMoney(r.result.targetBuyPriceCagr) : '—'}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
