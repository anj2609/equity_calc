import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'dialogs.dart';

/// Saves the open calculation, asking for a name the first time.
/// Returns false if the user cancelled.
Future<bool> saveWithPrompt(BuildContext context) async {
  final state = context.read<AppState>();
  String? name;
  if (!state.isCurrentSaved) {
    name = await promptText(
      context,
      title: 'Save calculation',
      initial: state.current.displayName == 'Untitled calculation'
          ? ''
          : state.current.displayName,
      hint: 'e.g. Reliance – Diwali buy',
    );
    if (name == null) return false;
  }
  await state.saveCurrent(name: name);
  if (context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Saved “${state.current.displayName}”')),
      );
  }
  return true;
}

enum _UnsavedChoice { save, discard }

/// Call before anything that replaces the open calculation. Returns true when
/// it is fine to continue (nothing unsaved, saved now, or discarded on purpose).
Future<bool> resolveUnsaved(BuildContext context) async {
  final state = context.read<AppState>();
  if (!state.isDirty) return true;
  final choice = await showDialog<_UnsavedChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Save changes?'),
      content: Text(
        '“${state.current.displayName}” has changes that are not saved.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _UnsavedChoice.discard),
          child: const Text("Don't save"),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _UnsavedChoice.save),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (!context.mounted) return false;
  return switch (choice) {
    _UnsavedChoice.save => saveWithPrompt(context),
    _UnsavedChoice.discard => true,
    null => false,
  };
}
