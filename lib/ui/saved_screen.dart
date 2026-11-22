import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/calculation.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import 'combined_screen.dart';
import 'dialogs.dart';
import 'export/excel_export.dart';
import 'save_flow.dart';
import 'widgets/profit_indicator.dart';

enum _Action { rename, duplicate, export, delete }

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key, this.startSelecting = false});

  /// Opens straight into "pick shares to combine" mode.
  final bool startSelecting;

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  late bool _selecting = widget.startSelecting;
  final Set<String> _selected = {};

  void _toggle(String id) => setState(
    () => _selected.contains(id) ? _selected.remove(id) : _selected.add(id),
  );

  List<Calculation> _selectedCalcs(AppState state) => [
    for (final c in state.calculations)
      if (_selected.contains(c.id)) c,
  ];

  Future<void> _open(Calculation calc) async {
    final state = context.read<AppState>();
    if (calc.id != state.current.id && !await resolveUnsaved(context)) return;
    state.openCalculation(calc.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final calcs = state.calculations;
    final selected = _selectedCalcs(state);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selecting ? '${_selected.length} selected' : 'Saved calculations',
        ),
        leading: _selecting && !widget.startSelecting
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cancel selection',
                onPressed: () => setState(() {
                  _selecting = false;
                  _selected.clear();
                }),
              )
            : null,
        actions: [
          if (!_selecting && calcs.isNotEmpty)
            TextButton.icon(
              onPressed: () => setState(() => _selecting = true),
              icon: const Icon(Icons.checklist, color: Colors.white),
              label: const Text(
                'Select',
                style: TextStyle(color: Colors.white),
              ),
            ),
          if (_selecting)
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: 'Select all',
              onPressed: () => setState(() {
                _selected.length == calcs.length
                    ? _selected.clear()
                    : _selected.addAll(calcs.map((c) => c.id));
              }),
            ),
        ],
      ),
      floatingActionButton: _selecting
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                if (!await resolveUnsaved(context)) return;
                state.newCalculation();
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.add),
              label: const Text('New calculation'),
            ),
      bottomNavigationBar: _selecting
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Builder(
                        builder: (context) => OutlinedButton.icon(
                          onPressed: selected.isEmpty
                              ? null
                              : () => exportToExcel(context, selected),
                          icon: const Icon(Icons.grid_on_outlined),
                          label: const Text('Export to Excel'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: selected.length < 2
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CombinedScreen(
                                    ids: [for (final c in selected) c.id],
                                  ),
                                ),
                              ),
                        icon: const Icon(Icons.stacked_line_chart),
                        label: Text(
                          selected.length < 2
                              ? 'Pick 2+ to combine'
                              : 'Combine ${selected.length}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: calcs.isEmpty
          ? const Center(
              child: Text(
                'Nothing saved yet. Tap Save on a calculation to keep it here.',
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              itemCount: calcs.length + (_selecting ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                if (_selecting && i == 0) {
                  return Text(
                    'Pick the shares to combine or export together.',
                    style: Theme.of(context).textTheme.bodySmall,
                  );
                }
                final calc = calcs[_selecting ? i - 1 : i];
                return _CalcTile(
                  calc,
                  isCurrent: calc.id == state.current.id,
                  hasUnsavedChanges:
                      calc.id == state.current.id && state.isDirty,
                  selecting: _selecting,
                  selected: _selected.contains(calc.id),
                  onTap: () => _selecting ? _toggle(calc.id) : _open(calc),
                  onLongPress: () => setState(() {
                    _selecting = true;
                    _selected.add(calc.id);
                  }),
                );
              },
            ),
    );
  }
}

class _CalcTile extends StatelessWidget {
  const _CalcTile(
    this.calc, {
    required this.isCurrent,
    required this.hasUnsavedChanges,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final Calculation calc;
  final bool isCurrent;
  final bool hasUnsavedChanges;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  Future<void> _onAction(BuildContext context, _Action action) async {
    final state = context.read<AppState>();
    switch (action) {
      case _Action.rename:
        final name = await promptText(
          context,
          title: 'Rename calculation',
          initial: calc.displayName,
        );
        if (name != null) state.renameCalculation(calc.id, name);
      case _Action.duplicate:
        if (!await resolveUnsaved(context)) return;
        state.duplicateCalculation(calc.id);
        if (context.mounted) Navigator.pop(context);
      case _Action.export:
        await exportToExcel(context, [calc]);
      case _Action.delete:
        final ok = await confirm(
          context,
          title: 'Delete “${calc.displayName}”?',
          message: 'This calculation and its scenarios will be removed. This cannot be undone.',
          action: 'Delete',
        );
        if (ok) state.deleteCalculation(calc.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final results = state.resultsFor(calc);
    final profit = results.isEmpty || !results.first.hasInputs
        ? null
        : results.first.result.netProfit;
    final details = [
      if (calc.name.trim().isNotEmpty && calc.base.shareName.trim().isNotEmpty)
        calc.base.shareName.trim(),
      '${calc.scenarios.length} scenario${calc.scenarios.length == 1 ? '' : 's'}',
      'saved ${formatDate(calc.updatedAt)}',
      if (hasUnsavedChanges) 'unsaved changes',
    ].join(' · ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        selected: selecting ? selected : isCurrent,
        leading: selecting
            ? Checkbox(value: selected, onChanged: (_) => onTap())
            : ProfitDot(value: profit, size: 12),
        title: Text(
          calc.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(details),
            if (profit != null) ...[
              const SizedBox(height: 4),
              ProfitBadge(
                value: profit,
                label: formatMoney(profit),
                compact: true,
              ),
            ],
          ],
        ),
        isThreeLine: profit != null,
        onTap: onTap,
        onLongPress: selecting ? null : onLongPress,
        trailing: selecting
            ? null
            : PopupMenuButton<_Action>(
                tooltip: 'More',
                onSelected: (a) => _onAction(context, a),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: _Action.rename, child: Text('Rename')),
                  PopupMenuItem(
                    value: _Action.duplicate,
                    child: Text('Duplicate'),
                  ),
                  PopupMenuItem(
                    value: _Action.export,
                    child: Text('Export to Excel'),
                  ),
                  PopupMenuItem(value: _Action.delete, child: Text('Delete')),
                ],
              ),
      ),
    );
  }
}
