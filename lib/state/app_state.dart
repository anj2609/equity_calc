import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/calculator.dart';
import '../engine/portfolio.dart';
import '../models/app_settings.dart';
import '../models/calculation.dart';
import '../models/input_field.dart';
import '../models/scenario.dart';
import '../models/trade_inputs.dart';
import '../services/price_service.dart';
import 'storage.dart';

class ScenarioResult {
  const ScenarioResult(this.index, this.scenario, this.inputs, this.result);

  final int index;
  final Scenario scenario;
  final TradeInputs inputs;
  final TradeResult result;

  /// False until a purchase price and quantity are entered; results are
  /// shown as "—" until then.
  bool get hasInputs => inputs.buyPrice > 0 && inputs.quantity > 0;
}

/// Holds the saved calculations, the one being edited (a working copy that
/// is only stored when the user saves), the selected scenario scope and
/// settings. Settings are stored as soon as they change.
class AppState extends ChangeNotifier {
  AppState._(
    this._storage,
    this._settings,
    this._saved,
    this._current, {
    PriceService? prices,
  }) : _prices = prices ?? PriceService();

  static const maxScenarios = 10;

  static Future<AppState> load({PriceService? prices}) async {
    final storage = Storage(await SharedPreferences.getInstance());
    final settings = storage.loadSettings();
    final saved =
        storage.loadCalculations(settings) ??
        [
          Calculation.sample(
            id: _newId(),
            scenarioIds: [_newId(), _newId(), _newId()],
          ),
        ];
    final currentId = storage.loadCurrentId();
    final current =
        saved.where((c) => c.id == currentId).firstOrNull ??
        (saved.isEmpty ? _blank(settings) : _newestFirst(saved).first);
    return AppState._(storage, settings, saved, current, prices: prices);
  }

  final Storage _storage;
  AppSettings _settings;
  final List<Calculation> _saved;
  Calculation _current;
  bool _dirty = false;
  String? _scenarioId;
  List<ScenarioResult>? _results;

  static final _rng = Random();
  static String _newId() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36) +
      _rng.nextInt(1 << 30).toRadixString(36);

  static Calculation _blank(AppSettings s) => Calculation.fromDefaults(
    s,
    id: _newId(),
    scenarioIds: [for (final _ in s.defaultTargets) _newId()],
  );

  static List<Calculation> _newestFirst(List<Calculation> list) =>
      [...list]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  AppSettings get settings => _settings;
  Calculation get current => _current;

  /// True when the open calculation has changes that have not been saved.
  bool get isDirty => _dirty;

  /// False for a new calculation that has never been saved.
  bool get isCurrentSaved => _saved.any((c) => c.id == _current.id);

  /// Most recently edited first.
  List<Calculation> get calculations => _newestFirst(_saved);

  Calculation? savedById(String id) =>
      _saved.where((c) => c.id == id).firstOrNull;

  CalcOptions optionsFor(Calculation c) => CalcOptions(
    daysInYear: _settings.daysInYear,
    longTermMonths: _settings.longTermMonths,
    autoCharges: c.autoCharges,
    rates: _settings.chargeRates,
  );

  List<ScenarioResult> get results => _results ??= resultsFor(current);

  List<ScenarioResult> resultsFor(Calculation c) {
    final options = optionsFor(c);
    return [
      for (var k = 0; k < c.scenarios.length; k++)
        () {
          final s = c.scenarios[k];
          final inputs = c.effectiveInputs(s);
          return ScenarioResult(
            k,
            s,
            inputs,
            calculate(
              inputs,
              targetReturnPct: s.targetReturnPct,
              options: options,
            ),
          );
        }(),
    ];
  }

  /// Combines several calculations, using the scenario index chosen for each
  /// (default the first). Calculations without a purchase price and quantity
  /// are left out.
  PortfolioResult combine(
    List<Calculation> calcs, {
    Map<String, int> scenarioIndex = const {},
  }) {
    final items = <PortfolioItem>[];
    for (final c in calcs) {
      final rs = resultsFor(c);
      if (rs.isEmpty) continue;
      final r = rs[(scenarioIndex[c.id] ?? 0).clamp(0, rs.length - 1)];
      if (!r.hasInputs) continue;
      items.add(
        PortfolioItem(
          name: c.displayName,
          scenarioLabel: 'Scenario ${r.index + 1} · ${r.scenario.label}',
          inputs: r.inputs,
          result: r.result,
        ),
      );
    }
    return combinePortfolio(
      items,
      stcgRatePct: _settings.stcgEffectivePct,
      ltcgRatePct: _settings.ltcgEffectivePct,
      ltcgExemption: _settings.ltcgExemption,
    );
  }

  // ---- Scope: "All scenarios" (null) or one scenario --------------------

  Scenario? get selectedScenario {
    for (final s in current.scenarios) {
      if (s.id == _scenarioId) return s;
    }
    return null;
  }

  void selectScenario(String? id) {
    _scenarioId = id;
    notifyListeners();
  }

  TradeInputs get scopeInputs {
    final s = selectedScenario;
    return s == null ? current.base : current.effectiveInputs(s);
  }

  /// Result for the inputs currently being edited (used for auto-charge previews).
  TradeResult get scopeResult =>
      calculate(scopeInputs, targetReturnPct: 0, options: optionsFor(current));

  bool isOverridden(InputField f) =>
      selectedScenario?.overrides.containsKey(f) ?? false;

  List<Scenario> scenariosOverriding(InputField f) => [
    for (final s in current.scenarios)
      if (s.overrides.containsKey(f)) s,
  ];

  /// Writes to the shared inputs, or to an override when a scenario is selected.
  void setField(InputField f, Object value) {
    final s = selectedScenario;
    if (s == null) {
      _update(current.copyWith(base: current.base.withValue(f, value)));
    } else {
      _updateScenario(s.withOverride(f, value));
    }
  }

  void resetField(InputField f) {
    final s = selectedScenario;
    if (s != null) _updateScenario(s.withoutOverride(f));
  }

  // ---- Live prices ---------------------------------------------------------

  final PriceService _prices;
  Quote? _quote;
  String? _quoteError;
  bool _fetchingQuote = false;

  PriceService get prices => _prices;
  bool get fetchingQuote => _fetchingQuote;
  String? get quoteError => _quoteError;

  /// The last fetched quote, if it is for the symbol currently in scope.
  Quote? get quote {
    final q = _quote;
    return q != null &&
            q.symbol == PriceService.normaliseSymbol(scopeInputs.symbol)
        ? q
        : null;
  }

  Future<void> fetchQuote() async {
    _fetchingQuote = true;
    _quoteError = null;
    notifyListeners();
    try {
      _quote = await _prices.quote(scopeInputs.symbol);
    } on PriceException catch (e) {
      _quote = null;
      _quoteError = e.message;
    }
    _fetchingQuote = false;
    notifyListeners();
  }

  /// Fills [field] (purchase or selling price) with the fetched price.
  void useQuoteAs(InputField field) {
    final q = quote;
    if (q != null) setField(field, q.price);
  }

  void pickSymbol(SymbolMatch match) {
    setField(InputField.symbol, match.symbol);
    if (scopeInputs.shareName.trim().isEmpty) {
      setField(InputField.shareName, match.name);
    }
    fetchQuote();
  }

  // ---- UI-only state (not saved) -----------------------------------------

  final Map<String, bool> _sectionExpanded = {};

  bool isSectionExpanded(String section, {required bool fallback}) =>
      _sectionExpanded[section] ?? fallback;

  void setSectionExpanded(String section, bool expanded) =>
      _sectionExpanded[section] = expanded;

  // ---- Scenarios --------------------------------------------------------

  void addScenario() {
    final list = current.scenarios;
    if (list.length >= maxScenarios) return;
    final next = list.isEmpty ? 10.0 : list.last.targetReturnPct + 25;
    final s = Scenario(id: _newId(), targetReturnPct: next);
    _scenarioId = null;
    _update(current.copyWith(scenarios: [...list, s]));
  }

  void removeScenario(String id) {
    if (current.scenarios.length <= 1) return;
    if (_scenarioId == id) _scenarioId = null;
    _update(
      current.copyWith(
        scenarios: [
          for (final s in current.scenarios)
            if (s.id != id) s,
        ],
      ),
    );
  }

  void renameScenario(String id, String name) =>
      _updateScenario(_scenario(id).copyWith(customName: name));

  void setTarget(String id, double pct) =>
      _updateScenario(_scenario(id).copyWith(targetReturnPct: pct));

  void clearOverrides(String id) =>
      _updateScenario(_scenario(id).copyWith(overrides: const {}));

  Scenario _scenario(String id) =>
      current.scenarios.firstWhere((s) => s.id == id);

  void _updateScenario(Scenario updated) => _update(
    current.copyWith(
      scenarios: [
        for (final s in current.scenarios) s.id == updated.id ? updated : s,
      ],
    ),
  );

  void setAutoCharges(bool on) => _update(current.copyWith(autoCharges: on));

  /// Re-applies the tax defaults from Settings to the open calculation.
  void applyTaxDefaultsToCurrent() {
    final s = _settings;
    _update(
      current.copyWith(
        base: current.base
            .withValue(
              InputField.stcgRatePct,
              double.parse(s.stcgEffectivePct.toStringAsFixed(4)),
            )
            .withValue(
              InputField.ltcgRatePct,
              double.parse(s.ltcgEffectivePct.toStringAsFixed(4)),
            )
            .withValue(InputField.ltcgExemption, s.ltcgExemption),
      ),
    );
  }

  // ---- Calculations -----------------------------------------------------

  /// Stores the open calculation (adding it to the saved list if new).
  Future<void> saveCurrent({String? name}) async {
    _current = _current.copyWith(name: name, updatedAt: DateTime.now());
    final i = _saved.indexWhere((c) => c.id == _current.id);
    if (i >= 0) {
      _saved[i] = _current;
    } else {
      _saved.add(_current);
    }
    _dirty = false;
    _changed();
    await _persistCalculations();
  }

  /// Renames the open calculation (a pending change until saved) or, from the
  /// saved list, a stored one directly.
  void renameCalculation(String id, String name) {
    if (id == _current.id) {
      _update(_current.copyWith(name: name));
      return;
    }
    final i = _saved.indexWhere((c) => c.id == id);
    if (i < 0) return;
    _saved[i] = _saved[i].copyWith(name: name);
    _changed();
    _persistCalculations();
  }

  /// Callers must resolve unsaved changes first; these discard them.
  void newCalculation() => _open(_blank(_settings));

  void openCalculation(String id) {
    final c = savedById(id);
    if (c != null) _open(c);
  }

  void duplicateCalculation(String id) {
    final src = savedById(id);
    if (src == null) return;
    final copy = src.copyWith(
      id: _newId(),
      name: '${src.displayName} (copy)',
      scenarios: [for (final s in src.scenarios) s.copyWith(id: _newId())],
      updatedAt: DateTime.now(),
    );
    _saved.add(copy);
    _open(copy);
  }

  void deleteCalculation(String id) {
    _saved.removeWhere((c) => c.id == id);
    if (id == _current.id) {
      _open(_saved.isEmpty ? _blank(_settings) : _newestFirst(_saved).first);
    } else {
      _changed();
    }
    _persistCalculations();
  }

  void _open(Calculation c) {
    _current = c;
    _dirty = false;
    _scenarioId = null;
    _quote = null;
    _quoteError = null;
    _changed();
    if (isCurrentSaved) _persistCalculations();
  }

  // ---- Settings (stored immediately) ------------------------------------

  void updateSettings(AppSettings s) {
    _settings = s;
    _changed();
    _storage.saveSettings(s);
  }

  void resetSettings() => updateSettings(
    AppSettings.initial.copyWith(themeMode: _settings.themeMode),
  );

  // ---- Change tracking & persistence -------------------------------------

  void _update(Calculation updated) {
    _current = updated.copyWith(updatedAt: DateTime.now());
    _dirty = true;
    _changed();
  }

  void _changed() {
    _results = null;
    notifyListeners();
  }

  Future<void> _persistCalculations() =>
      _storage.saveCalculations(_saved, _current.id);
}
