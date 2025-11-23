import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/app_navbar.dart';
import '../../history/providers/history_provider.dart';
import '../models/canvas_snapshot.dart';
import '../models/collection_entry.dart';
import '../models/user_collection.dart';
import '../providers/collection_provider.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CollectionProvider>().initialize();
      context.read<HistoryProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CollectionProvider>();
    final collections = _applyFilters(provider.collections);

    return Scaffold(
      backgroundColor: AppTheme.colors.background,
      appBar: const AppNavbar(),
      body: Padding(
        padding: EdgeInsets.all(AppTheme.spacing.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(provider.collections.length),
            const SizedBox(height: 24),
            _buildToolbar(),
            const SizedBox(height: 20),
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : collections.isEmpty
                      ? _EmptyCollections(onCreate: _createCollection)
                      : ListView.separated(
                          itemCount: collections.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final collection = collections[index];
                            return _CollectionCard(
                              collection: collection,
                              onAddSession: () => _addSessionFromHistory(collection.id),
                              onRename: () => _renameCollection(collection),
                              onDelete: () => _deleteCollection(collection),
                              onOpenSession: _openSnapshot,
                              onRemoveSession: (entry) =>
                                  _removeSessionFromCollection(collection.id, entry),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Coleções', style: AppTheme.typography.title),
        const SizedBox(height: 6),
        Text(
          total == 0
              ? 'Crie playlists de sessões favoritas a partir do histórico.'
              : '$total coleções para organizar suas sessões favoritas.',
          style: AppTheme.typography.paragraph.copyWith(fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Buscar por nome da coleção',
              prefixIcon: const Icon(Icons.search),
            ),
          ),
        ),
        const SizedBox(width: 16),
        FilledButton.icon(
          onPressed: _createCollection,
          icon: const Icon(Icons.add),
          label: const Text('Criar coleção'),
        ),
      ],
    );
  }

  List<UserCollection> _applyFilters(List<UserCollection> items) {
    if (_searchQuery.isEmpty) return items;
    final query = _searchQuery.toLowerCase();
    return items
        .where((collection) => collection.name.toLowerCase().contains(query))
        .toList();
  }

  Future<void> _createCollection() async {
    final name = await _promptCollectionName();
    if (name == null || !mounted) return;
    await context.read<CollectionProvider>().createCollection(name);
  }

  Future<void> _renameCollection(UserCollection collection) async {
    final name = await _promptCollectionName(initialValue: collection.name);
    if (name == null || !mounted) return;
    await context.read<CollectionProvider>().renameCollection(collection.id, name);
  }

  Future<void> _deleteCollection(UserCollection collection) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Excluir coleção'),
            content: Text('Remover "${collection.name}" e todas as sessões salvas nela?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppTheme.colors.primary),
                child: const Text('Excluir'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    await context.read<CollectionProvider>().deleteCollection(collection.id);
  }

  Future<void> _addSessionFromHistory(String collectionId) async {
    final historyProvider = context.read<HistoryProvider>();
    await historyProvider.initialize();
    if (!mounted) return;
    if (historyProvider.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma sessão registrada ainda.')),
      );
      return;
    }

    final selected = await showModalBottomSheet<CanvasSnapshot>(
      context: context,
      builder: (ctx) => _HistoryPicker(items: historyProvider.items),
    );

    if (selected == null || !mounted) return;

    await context.read<CollectionProvider>().addSession(collectionId, selected);

    if (!mounted) return;
    final updated = context.read<CollectionProvider>().getById(collectionId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sessão adicionada em "${updated?.name ?? 'Coleção'}".')),
    );
  }

  Future<void> _removeSessionFromCollection(
    String collectionId,
    CollectionEntry entry,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Remover sessão'),
            content: const Text('Esta sessão deixará de fazer parte da coleção.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppTheme.colors.primary),
                child: const Text('Remover'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    await context.read<CollectionProvider>().removeSession(collectionId, entry.id);
  }

  Future<void> _openSnapshot(CanvasSnapshot snapshot) async {
    await Navigator.pushNamed(context, '/home', arguments: snapshot);
  }

  Future<String?> _promptCollectionName({String? initialValue}) async {
    final controller = TextEditingController(text: initialValue ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(initialValue == null ? 'Nova coleção' : 'Renomear coleção'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nome da coleção'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              Navigator.of(ctx).pop(value);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.colors.primary,
            ),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return null;
    final trimmed = result.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.collection,
    required this.onAddSession,
    required this.onRename,
    required this.onDelete,
    required this.onOpenSession,
    required this.onRemoveSession,
  });

  final UserCollection collection;
  final VoidCallback onAddSession;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final void Function(CanvasSnapshot snapshot) onOpenSession;
  final void Function(CollectionEntry entry) onRemoveSession;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(
          horizontal: AppTheme.spacing.medium,
          vertical: AppTheme.spacing.small,
        ),
        title: Text(
          collection.name,
          style: AppTheme.typography.subtitle.copyWith(fontSize: 18),
        ),
        subtitle: Text(
          '${collection.sessions.length} sessão${collection.sessions.length == 1 ? '' : 's'}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'rename':
                onRename();
                break;
              case 'delete':
                onDelete();
                break;
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'rename', child: Text('Renomear')), 
            PopupMenuItem(value: 'delete', child: Text('Excluir coleção')),
          ],
        ),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(
                right: AppTheme.spacing.medium,
                bottom: AppTheme.spacing.small,
              ),
              child: FilledButton.icon(
                onPressed: onAddSession,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar sessão'),
              ),
            ),
          ),
          if (collection.sessions.isEmpty)
            Padding(
              padding: EdgeInsets.only(
                left: AppTheme.spacing.medium,
                right: AppTheme.spacing.medium,
                bottom: AppTheme.spacing.medium,
              ),
              child: const Text('Nenhuma sessão adicionada ainda.'),
            )
          else
            Padding(
              padding: EdgeInsets.only(
                left: AppTheme.spacing.medium,
                right: AppTheme.spacing.medium,
                bottom: AppTheme.spacing.medium,
              ),
              child: Column(
                children: collection.sessions
                    .map(
                      (entry) => _CollectionSessionTile(
                        entry: entry,
                        onOpen: () => onOpenSession(entry.snapshot),
                        onRemove: () => onRemoveSession(entry),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _CollectionSessionTile extends StatelessWidget {
  const _CollectionSessionTile({
    required this.entry,
    required this.onOpen,
    required this.onRemove,
  });

  final CollectionEntry entry;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final snapshot = entry.snapshot;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: snapshot.previewBytes != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                snapshot.previewBytes!,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            )
          : const Icon(Icons.image_outlined, size: 32),
      title: Text(snapshot.resolvedTitle),
      subtitle: Text('Adicionada em ${_formatDate(entry.addedAt)}'),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: 'Abrir no canvas',
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new),
          ),
          IconButton(
            tooltip: 'Remover da coleção',
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      onTap: onOpen,
    );
  }
}

class _EmptyCollections extends StatelessWidget {
  const _EmptyCollections({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.collections_bookmark_outlined, size: 72),
          const SizedBox(height: 16),
          Text('Nenhuma coleção ainda', style: AppTheme.typography.subtitle),
          const SizedBox(height: 8),
          const Text(
            'Organize as sessões do histórico em playlists personalizadas.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Criar coleção'),
          ),
        ],
      ),
    );
  }
}

class _HistoryPicker extends StatelessWidget {
  const _HistoryPicker({required this.items});

  final List<CanvasSnapshot> items;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacing.medium),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Escolha uma sessão', style: AppTheme.typography.subtitle),
            const SizedBox(height: 12),
            SizedBox(
              height: 360,
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final snapshot = items[index];
                  return ListTile(
                    leading: snapshot.previewBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              snapshot.previewBytes!,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(Icons.image_outlined),
                    title: Text(snapshot.resolvedTitle),
                    subtitle: Text(_formatDate(snapshot.createdAt)),
                    onTap: () => Navigator.of(context).pop(snapshot),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month/$year às $hour:$minute';
}
