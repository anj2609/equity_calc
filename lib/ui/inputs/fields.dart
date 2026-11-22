import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/input_field.dart';
import '../../state/app_state.dart';
import '../../utils/format.dart';
import '../theme.dart';

/// normal: shared value or a setting. inherited: a scenario showing the
/// shared value. overridden: a scenario's own value.
enum FieldStyle { normal, inherited, overridden }

Color _fill(BuildContext context, FieldStyle style) => switch (style) {
  FieldStyle.normal => AppColors.of(context).inputFill,
  FieldStyle.overridden => AppColors.of(context).overrideFill,
  FieldStyle.inherited => Theme.of(
    context,
  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
};

Widget? _resetButton(VoidCallback? onReset) => onReset == null
    ? null
    : IconButton(
        icon: const Icon(Icons.restart_alt),
        tooltip: 'Use the shared value',
        onPressed: onReset,
      );

/// Numeric field that accepts "1,23,456.50" and reformats when it loses focus.
/// Reports null when cleared.
class NumberInput extends StatefulWidget {
  const NumberInput({
    super.key,
    required this.label,
    required this.value,
    required this.kind,
    required this.onChanged,
    this.helper,
    this.style = FieldStyle.normal,
    this.onReset,
  });

  final String label;
  final double value;
  final FieldKind kind;
  final ValueChanged<double?> onChanged;
  final String? helper;
  final FieldStyle style;
  final VoidCallback? onReset;

  @override
  State<NumberInput> createState() => _NumberInputState();
}

class _NumberInputState extends State<NumberInput> {
  late final _controller = TextEditingController(text: _format(widget.value));
  final _focus = FocusNode();

  String _format(double v) {
    if (v == 0) return '';
    return widget.kind == FieldKind.money
        ? formatMoneyInput(v)
        : formatPlain(v);
  }

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _controller.text = _format(widget.value);
    });
  }

  @override
  void didUpdateWidget(NumberInput old) {
    super.didUpdateWidget(old);
    if (_focus.hasFocus) return;
    final text = _format(widget.value);
    if (text != _controller.text) _controller.text = text;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _controller,
      focusNode: _focus,
      keyboardType: TextInputType.numberWithOptions(
        decimal: widget.kind != FieldKind.quantity,
        signed: widget.kind == FieldKind.percent,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
      ],
      style: widget.style == FieldStyle.inherited
          ? TextStyle(color: scheme.onSurfaceVariant)
          : null,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: '0',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        prefixText: widget.kind == FieldKind.money ? '₹ ' : null,
        suffixText: widget.kind == FieldKind.percent ? '%' : null,
        helperText: widget.helper,
        helperMaxLines: 3,
        fillColor: _fill(context, widget.style),
        suffixIcon: _resetButton(widget.onReset),
      ),
      onChanged: (t) => widget.onChanged(parseNumber(t)),
    );
  }
}

class TextInput extends StatefulWidget {
  const TextInput({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.helper,
    this.style = FieldStyle.normal,
    this.onReset,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? hint;
  final String? helper;
  final FieldStyle style;
  final VoidCallback? onReset;

  @override
  State<TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<TextInput> {
  late final _controller = TextEditingController(text: widget.value);
  final _focus = FocusNode();

  @override
  void didUpdateWidget(TextInput old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _controller,
      focusNode: _focus,
      textCapitalization: TextCapitalization.words,
      style: widget.style == FieldStyle.inherited
          ? TextStyle(color: scheme.onSurfaceVariant)
          : null,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        floatingLabelBehavior: widget.hint == null
            ? null
            : FloatingLabelBehavior.always,
        helperText: widget.helper,
        helperMaxLines: 3,
        fillColor: _fill(context, widget.style),
        suffixIcon: _resetButton(widget.onReset),
      ),
      onChanged: widget.onChanged,
    );
  }
}

class DateInput extends StatelessWidget {
  const DateInput({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.helper,
    this.style = FieldStyle.normal,
    this.onReset,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final String? helper;
  final FieldStyle style;
  final VoidCallback? onReset;

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 3,
          fillColor: _fill(context, style),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ?_resetButton(onReset),
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.calendar_today_outlined, size: 20),
              ),
            ],
          ),
        ),
        child: Text(
          formatDate(value),
          style: style == FieldStyle.inherited
              ? TextStyle(color: scheme.onSurfaceVariant)
              : null,
        ),
      ),
    );
  }
}

/// Read-only value worked out by the app (auto charges).
class ComputedValue extends StatelessWidget {
  const ComputedValue({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.5),
        helperText: 'Calculated automatically',
        suffixIcon: const Icon(Icons.auto_awesome_outlined, size: 18),
      ),
      child: Text(value),
    );
  }
}

/// An input bound to [field] in the current scope: the shared inputs, or the
/// selected scenario (where typing creates an override).
class ScopedField extends StatelessWidget {
  const ScopedField(
    this.field, {
    super.key,
    this.label,
    this.helper,
    this.hint,
  });

  final InputField field;
  final String? label;
  final String? helper;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scenario = state.selectedScenario;
    final overridden = state.isOverridden(field);
    final style = scenario == null
        ? FieldStyle.normal
        : overridden
        ? FieldStyle.overridden
        : FieldStyle.inherited;
    final value = state.scopeInputs.valueOf(field);
    final key = ValueKey(
      '${state.current.id}/${scenario?.id ?? 'all'}/${field.name}',
    );
    final onReset = overridden ? () => state.resetField(field) : null;
    final text = label ?? field.label;

    String? help = helper;
    if (scenario != null) {
      help = overridden ? 'Only for this scenario' : null;
    } else {
      final others = state.scenariosOverriding(field);
      if (others.isNotEmpty) {
        help = [
          ?help,
          'Has its own value in: ${others.map((s) => s.label).join(', ')}',
        ].join('\n');
      }
    }

    switch (field.kind) {
      case FieldKind.text:
        return TextInput(
          key: key,
          label: text,
          value: value as String,
          hint: hint ?? 'Enter share name',
          helper: help,
          style: style,
          onReset: onReset,
          onChanged: (v) => v.isEmpty && scenario != null
              ? state.resetField(field)
              : state.setField(field, v),
        );
      case FieldKind.date:
        return DateInput(
          key: key,
          label: text,
          value: value as DateTime,
          helper: help,
          style: style,
          onReset: onReset,
          onChanged: (d) => state.setField(field, d),
        );
      case FieldKind.money:
      case FieldKind.quantity:
      case FieldKind.percent:
        return NumberInput(
          key: key,
          label: text,
          value: value as double,
          kind: field.kind,
          helper: help,
          style: style,
          onReset: onReset,
          onChanged: (v) {
            if (v != null) {
              state.setField(field, v);
            } else if (scenario != null) {
              state.resetField(field);
            } else {
              state.setField(field, 0.0);
            }
          },
        );
    }
  }
}
