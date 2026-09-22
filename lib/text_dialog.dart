import 'package:flutter/material.dart';

class TextInsertDialog extends StatefulWidget {
  const TextInsertDialog({super.key, required this.rtl});
  final bool rtl;
  @override
  State<TextInsertDialog> createState() => _TextInsertDialogState();
}

class _TextInsertDialogState extends State<TextInsertDialog> {
  final _text = TextEditingController();
  @override
  void dispose() { _text.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add text'),
    content: SizedBox(width: 400, child: TextField(
      controller: _text, autofocus: true, maxLines: 5,
      textDirection: widget.rtl ? TextDirection.rtl : TextDirection.ltr,
      decoration: const InputDecoration(
        hintText: 'Type text. Use new lines for long sentences.',
      ),
    )),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: () {
        if (_text.text.trim().isNotEmpty) Navigator.pop(context, _text.text.trim());
      }, child: const Text('Insert')),
    ],
  );
}
