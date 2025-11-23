import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/user_collection.dart';

class CollectionSelectionResult {
  const CollectionSelectionResult({this.collectionId, this.pendingName});

  final String? collectionId;
  final String? pendingName;
}

Future<CollectionSelectionResult?> showCollectionPickerSheet(
  BuildContext context, {
  required List<UserCollection> collections,
}) {
  return showModalBottomSheet<CollectionSelectionResult>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _CollectionPickerSheet(collections: collections),
  );
}

class _CollectionPickerSheet extends StatefulWidget {
  const _CollectionPickerSheet({required this.collections});

  final List<UserCollection> collections;

  @override
  State<_CollectionPickerSheet> createState() => _CollectionPickerSheetState();
}

class _CollectionPickerSheetState extends State<_CollectionPickerSheet> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppTheme.spacing.large,
          AppTheme.spacing.large,
          AppTheme.spacing.large,
          AppTheme.spacing.large + bottomInset,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Adicionar à coleção', style: AppTheme.typography.subtitle),
              const SizedBox(height: 12),
              if (widget.collections.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Crie uma coleção para guardar esta sessão.',
                    style: AppTheme.typography.paragraph,
                  ),
                )
              else
                SizedBox(
                  height: 220,
                  child: ListView.separated(
                    itemCount: widget.collections.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final collection = widget.collections[index];
                      final count = collection.sessions.length;
                      return ListTile(
                        title: Text(collection.name),
                        subtitle: Text(
                          count == 0
                              ? 'Nenhuma sessão'
                              : '$count sessão${count == 1 ? '' : 's'}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _selectExisting(collection.id),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Criar nova coleção', style: AppTheme.typography.paragraph),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        labelText: 'Nome da coleção',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Informe um nome para continuar';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _createAndAdd,
                        icon: const Icon(Icons.add),
                        label: const Text('Criar e usar'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectExisting(String id) {
    Navigator.of(context).pop(CollectionSelectionResult(collectionId: id));
  }

  void _createAndAdd() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      CollectionSelectionResult(pendingName: _controller.text.trim()),
    );
  }
}
