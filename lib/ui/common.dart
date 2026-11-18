import 'package:flutter/material.dart';

void showSnack(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 4)),
    );
}

/// The first letter of a name, for an avatar. "?" when there is none.
String initialOf(String name) {
  final t = name.trim();
  return t.isEmpty ? '?' : t.characters.first.toUpperCase();
}

/// A member's avatar: their initial on the app's accent.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({super.key, required this.name, this.radius = 20});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      child: Text(
        initialOf(name),
        style: TextStyle(fontSize: radius * 0.9, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Asks for a circle's name. Returns the cleaned name, or null.
Future<String?> askCircleName(
  BuildContext context, {
  required String title,
  required String label,
  required String hint,
  required String required,
  required String confirm,
  required String cancel,
  String initial = '',
}) => showDialog<String>(
  context: context,
  builder: (_) => _CircleNameDialog(
    title: title,
    label: label,
    hint: hint,
    required: required,
    confirm: confirm,
    cancel: cancel,
    initial: initial,
  ),
);

class _CircleNameDialog extends StatefulWidget {
  const _CircleNameDialog({
    required this.title,
    required this.label,
    required this.hint,
    required this.required,
    required this.confirm,
    required this.cancel,
    required this.initial,
  });

  final String title;
  final String label;
  final String hint;
  final String required;
  final String confirm;
  final String cancel;
  final String initial;

  @override
  State<_CircleNameDialog> createState() => _CircleNameDialogState();
}

class _CircleNameDialogState extends State<_CircleNameDialog> {
  late final _name = TextEditingController(text: widget.initial);
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    Navigator.of(context).pop(_name.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _form,
        child: TextFormField(
          controller: _name,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
          ),
          validator: (v) => (v ?? '').trim().isEmpty ? widget.required : null,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancel),
        ),
        TextButton(onPressed: _submit, child: Text(widget.confirm)),
      ],
    );
  }
}
