import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/calculation.dart';

/// Persists settings and calculations as JSON in shared preferences.
class Storage {
  Storage(this._prefs);

  final SharedPreferences _prefs;

  static const _kSettings = 'settings_v1';
  static const _kCalculations = 'calculations_v1';
  static const _kCurrent = 'current_calculation_v1';

  AppSettings loadSettings() {
    final raw = _prefs.getString(_kSettings);
    if (raw == null) return AppSettings.initial;
    try {
      return AppSettings.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return AppSettings.initial;
    }
  }

  /// Null on first launch (nothing stored yet).
  List<Calculation>? loadCalculations(AppSettings settings) {
    final raw = _prefs.getString(_kCalculations);
    if (raw == null) return null;
    final result = <Calculation>[];
    try {
      for (final item in jsonDecode(raw) as List) {
        try {
          result.add(
            Calculation.fromJson(
              Map<String, dynamic>.from(item as Map),
              settings,
            ),
          );
        } catch (_) {
          // Skip a single corrupt entry rather than losing everything.
        }
      }
    } catch (_) {}
    return result;
  }

  String? loadCurrentId() => _prefs.getString(_kCurrent);

  Future<void> saveSettings(AppSettings settings) =>
      _prefs.setString(_kSettings, jsonEncode(settings.toJson()));

  Future<void> saveCalculations(
    List<Calculation> calculations,
    String currentId,
  ) async {
    await _prefs.setString(
      _kCalculations,
      jsonEncode([for (final c in calculations) c.toJson()]),
    );
    await _prefs.setString(_kCurrent, currentId);
  }
}
