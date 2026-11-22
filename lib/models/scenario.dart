import '../utils/format.dart';
import 'input_field.dart';

/// A target-return profile. Uses the calculation's shared inputs except for
/// fields listed in [overrides].
class Scenario {
  const Scenario({
    required this.id,
    required this.targetReturnPct,
    this.customName = '',
    this.overrides = const {},
  });

  final String id;
  final String customName;
  final double targetReturnPct;
  final Map<InputField, Object> overrides;

  String get label => customName.trim().isNotEmpty
      ? customName.trim()
      : '${formatPlain(targetReturnPct, maxDecimals: 2)}% target';

  Scenario copyWith({
    String? id,
    String? customName,
    double? targetReturnPct,
    Map<InputField, Object>? overrides,
  }) => Scenario(
    id: id ?? this.id,
    customName: customName ?? this.customName,
    targetReturnPct: targetReturnPct ?? this.targetReturnPct,
    overrides: overrides ?? this.overrides,
  );

  Scenario withOverride(InputField f, Object value) =>
      copyWith(overrides: {...overrides, f: value});

  Scenario withoutOverride(InputField f) =>
      copyWith(overrides: {...overrides}..remove(f));

  Map<String, Object> toJson() => {
    'id': id,
    'customName': customName,
    'targetReturnPct': targetReturnPct,
    'overrides': {
      for (final e in overrides.entries) e.key.name: e.key.encode(e.value),
    },
  };

  factory Scenario.fromJson(Map<String, dynamic> j) {
    final overrides = <InputField, Object>{};
    final raw = (j['overrides'] as Map?) ?? const {};
    for (final e in raw.entries) {
      final f = InputField.byName(e.key.toString());
      final v = f?.decode(e.value);
      if (f != null && v != null) overrides[f] = v;
    }
    return Scenario(
      id: j['id'] as String,
      customName: (j['customName'] as String?) ?? '',
      targetReturnPct: (j['targetReturnPct'] as num?)?.toDouble() ?? 10,
      overrides: overrides,
    );
  }
}
