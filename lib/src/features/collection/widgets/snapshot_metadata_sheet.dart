import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class SnapshotMetadata {
  const SnapshotMetadata({required this.title, this.notes});

  final String title;
  final String? notes;
}

Future<SnapshotMetadata?> showSnapshotMetadataSheet(
  BuildContext context, {
  String? initialTitle,
  String? initialNotes,
  String? helperText,
  String? titleLabel,
  String actionLabel = 'Salvar',
}) {
  return showModalBottomSheet<SnapshotMetadata>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _SnapshotMetadataSheet(
      initialTitle: initialTitle,
      initialNotes: initialNotes,
      helperText: helperText,
      titleLabel: titleLabel,
      actionLabel: actionLabel,
    ),
  );
}

class _SnapshotMetadataSheet extends StatefulWidget {
  const _SnapshotMetadataSheet({
    this.initialTitle,
    this.initialNotes,
    this.helperText,
    this.titleLabel,
    required this.actionLabel,
  });

  final String? initialTitle;
  final String? initialNotes;
  final String? helperText;
  final String? titleLabel;
  final String actionLabel;

  @override
  State<_SnapshotMetadataSheet> createState() => _SnapshotMetadataSheetState();
}

class _SnapshotMetadataSheetState extends State<_SnapshotMetadataSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _notesController = TextEditingController(text: widget.initialNotes ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: AppTheme.spacing.large,
        right: AppTheme.spacing.large,
        top: AppTheme.spacing.large,
        bottom: bottomInset + AppTheme.spacing.large,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.titleLabel ?? 'Detalhes da sessão',
              style: AppTheme.typography.subtitle,
            ),
            if (widget.helperText != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.helperText!,
                style: AppTheme.typography.paragraph.copyWith(fontSize: 14),
              ),
            ],
            const SizedBox(height: 20),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Título'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe um nome para a coleção';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration:
                  const InputDecoration(labelText: 'Descrição (opcional)'),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.colors.primary,
                  ),
                  child: Text(widget.actionLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final notes = _notesController.text.trim();
    Navigator.of(context).pop(
      SnapshotMetadata(
        title: _titleController.text.trim(),
        notes: notes.isEmpty ? null : notes,
      ),
    );
  }
}
