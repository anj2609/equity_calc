import 'package:flutter/material.dart';

import '../theme.dart';

/// Green for profit, red for loss, neutral for zero / unknown.
Color _toneColor(BuildContext context, double? value) {
  final colors = AppColors.of(context);
  if (value == null || value.abs() < 0.005) {
    return Theme.of(context).colorScheme.outline;
  }
  return value > 0 ? colors.gain : colors.loss;
}

/// Shared pulse for the blinking indicators. Respects the system's
/// "reduce motion" setting by standing still.
mixin _Pulse<T extends StatefulWidget>
    on State<T>, SingleTickerProviderStateMixin<T> {
  late final AnimationController pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  void syncPulse(bool active) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (active && !reduceMotion) {
      if (!pulse.isAnimating) pulse.repeat(reverse: true);
    } else {
      pulse
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }
}

/// A small dot that blinks green on profit and red on loss.
class ProfitDot extends StatefulWidget {
  const ProfitDot({super.key, required this.value, this.size = 10});

  final double? value;
  final double size;

  @override
  State<ProfitDot> createState() => _ProfitDotState();
}

class _ProfitDotState extends State<ProfitDot>
    with SingleTickerProviderStateMixin, _Pulse {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncPulse(widget.value != null && widget.value!.abs() >= 0.005);
  }

  @override
  void didUpdateWidget(ProfitDot old) {
    super.didUpdateWidget(old);
    syncPulse(widget.value != null && widget.value!.abs() >= 0.005);
  }

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(context, widget.value);
    final s = widget.size;
    return Semantics(
      label: widget.value == null
          ? 'No result'
          : (widget.value! >= 0 ? 'Profit' : 'Loss'),
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(pulse.value);
          return SizedBox(
            width: s * 2.2,
            height: s * 2.2,
            child: Center(
              child: Container(
                width: s,
                height: s,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.45 + 0.55 * t),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.55 * t),
                      blurRadius: s * 1.2 * t,
                      spreadRadius: s * 0.35 * t,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A pill showing an up/down arrow and [label], tinted green or red, with a
/// blinking dot. Flashes brighter for a moment whenever [value] changes.
class ProfitBadge extends StatefulWidget {
  const ProfitBadge({
    super.key,
    required this.value,
    required this.label,
    this.compact = false,
  });

  final double? value;
  final String label;
  final bool compact;

  @override
  State<ProfitBadge> createState() => _ProfitBadgeState();
}

class _ProfitBadgeState extends State<ProfitBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
    value: 1,
  );

  @override
  void didUpdateWidget(ProfitBadge old) {
    super.didUpdateWidget(old);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (old.value != widget.value && !reduceMotion) _flash.forward(from: 0);
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.value;
    final color = _toneColor(context, v);
    final theme = Theme.of(context);
    final icon = v == null || v.abs() < 0.005
        ? Icons.remove
        : (v > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded);
    return AnimatedBuilder(
      animation: _flash,
      builder: (context, child) {
        final flash = 1 - Curves.easeOut.transform(_flash.value);
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 8 : 12,
            vertical: widget.compact ? 3 : 6,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12 + 0.25 * flash),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: color.withValues(alpha: 0.35 + 0.5 * flash),
            ),
          ),
          child: child,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ProfitDot(value: v, size: widget.compact ? 6 : 8),
          Icon(icon, size: widget.compact ? 14 : 18, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  (widget.compact
                          ? theme.textTheme.labelMedium
                          : theme.textTheme.titleSmall)
                      ?.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
