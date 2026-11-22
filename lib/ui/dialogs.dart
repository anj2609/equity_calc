import 'package:flutter/material.dart';

Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String initial,
  String? hint,
  String action = 'Save',
}) => showDialog<String>(
  context: context,
  builder: (_) =>
      _PromptDialog(title: title, initial: initial, hint: hint, action: action),
);

/// Owns its text controller so it is disposed only after the dialog's exit
/// animation has finished with it.
class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    required this.initial,
    required this.action,
    this.hint,
  });

  final String title;
  final String initial;
  final String? hint;
  final String action;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(hintText: widget.hint),
      onSubmitted: (v) => Navigator.pop(context, v),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: Text(widget.action),
      ),
    ],
  );
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return result ?? false;
}
