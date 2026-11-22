import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../export/workbook.dart';
import '../../models/calculation.dart';
import '../../state/app_state.dart';

const _xlsxMime =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// Builds an .xlsx for [calcs] (plus a Combined tab when there is more than
/// one) and opens the share sheet so it can be saved or sent.
Future<void> exportToExcel(
  BuildContext context,
  List<Calculation> calcs, {
  Map<String, int> scenarioIndex = const {},
}) async {
  final state = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);
  final box = context.findRenderObject() as RenderBox?;
  final origin = box != null && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : null;
  final now = DateTime.now();

  try {
    final bytes = Uint8List.fromList(
      buildWorkbook(
        [for (final c in calcs) SheetSource(c, state.resultsFor(c))],
        combined: calcs.length > 1
            ? state.combine(calcs, scenarioIndex: scenarioIndex)
            : null,
        generatedAt: now,
      ),
    );
    final base = calcs.length == 1
        ? calcs.first.displayName
        : 'Combined ${calcs.length} shares';
    final fileName =
        'EquityCalc_${base.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}_${DateFormat('yyyyMMdd_HHmm').format(now)}.xlsx';

    final XFile file;
    if (kIsWeb) {
      file = XFile.fromData(bytes, name: fileName, mimeType: _xlsxMime);
    } else {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/$fileName';
      await File(path).writeAsBytes(bytes, flush: true);
      file = XFile(path, mimeType: _xlsxMime, name: fileName);
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [file],
        fileNameOverrides: [fileName],
        subject: base,
        sharePositionOrigin: origin,
      ),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Could not export: $e')));
  }
}
