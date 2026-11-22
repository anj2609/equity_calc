import 'package:equity_calc/export/workbook.dart';
import 'package:equity_calc/models/calculation.dart';
import 'package:equity_calc/state/app_state.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'workbook has a Combined tab and one tab per share with sheet values',
    () async {
      SharedPreferences.setMockInitialValues({});
      final state = await AppState.load();
      final sample = state.current;
      final copy = Calculation.fromJson(
        sample.toJson()
          ..['id'] = 'b'
          ..['name'] = 'Second share',
        state.settings,
      );
      final calcs = [sample, copy];

      final bytes = buildWorkbook(
        [for (final c in calcs) SheetSource(c, state.resultsFor(c))],
        combined: state.combine(calcs),
        generatedAt: DateTime(2026, 11, 22),
      );
      final book = Excel.decodeBytes(bytes);
      expect(
        book.tables.keys,
        containsAll(['Combined', 'Sample (from sheet)', 'Second share']),
      );

      final sheet = book.tables['Sample (from sheet)']!;
      Data? rowLabelled(String label) {
        for (final row in sheet.rows) {
          final first = row.first?.value;
          if (first is TextCellValue && first.value.text == label) {
            return row[1];
          }
        }
        return null;
      }

      double num(Data? d) => switch (d?.value) {
        DoubleCellValue v => v.value,
        IntCellValue v => v.value.toDouble(),
        _ => double.nan,
      };
      expect(
        num(rowLabelled('Total cash investment incl. all buy charges')),
        closeTo(7978, 0.005),
      );
      expect(
        num(rowLabelled('Net profit / (loss) after tax & all charges')),
        closeTo(-101.96, 0.005),
      );
      expect(
        num(
          rowLabelled('Sell price for target return – CAGR basis (per share)'),
        ),
        closeTo(802.46, 0.005),
      );
    },
  );
}
