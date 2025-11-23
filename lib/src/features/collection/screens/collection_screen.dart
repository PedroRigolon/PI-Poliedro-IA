import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/app_navbar.dart';
import '../../../widgets/app_notification.dart';
import '../../history/providers/history_provider.dart';
import '../models/canvas_snapshot.dart';
import '../models/collection_entry.dart';
import '../models/user_collection.dart';
import '../providers/collection_provider.dart';
import '../widgets/snapshot_metadata_sheet.dart';

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
                      : _CollectionGrid(
                          collections: collections,
                          onAddSession: _addSessionFromHistory,
                          onRenameCollection: _renameCollection,
                          onDeleteCollection: _deleteCollection,
                          onOpenSession: _openSnapshot,
                          onRemoveSession: _removeSessionFromCollection,
                          onRenameSession: _renameCollectionSession,
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
      showAppNotification(
        context,
        message: 'Nenhuma sessão registrada ainda para adicionar.',
        type: AppNotificationType.warning,
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
    if (!mounted) return;
    showAppNotification(
      context,
      message: 'Sessão adicionada em "${updated?.name ?? 'Coleção'}".',
      type: AppNotificationType.success,
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

  Future<void> _renameCollectionSession(
    String collectionId,
    CollectionEntry entry,
  ) async {
    final meta = await showSnapshotMetadataSheet(
      context,
      initialTitle: entry.snapshot.resolvedTitle,
      initialNotes: entry.snapshot.notes,
      titleLabel: 'Renomear sessão',
      actionLabel: 'Salvar',
    );
    if (meta == null || !mounted) return;
    await context.read<CollectionProvider>().renameSession(
          collectionId,
          entry.id,
          title: meta.title,
          notes: meta.notes,
        );
        if (!mounted) return;
        await context.read<HistoryProvider>().updateMetadata(
          entry.snapshot.id,
          title: meta.title,
          notes: meta.notes,
        );
        if (!entry.snapshot.id.startsWith('history-') && mounted) {
      await context.read<HistoryProvider>().updateMetadata(
        'history-${entry.snapshot.id}',
        title: meta.title,
        notes: meta.notes,
          );
        }
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

class _CollectionGrid extends StatelessWidget {
  const _CollectionGrid({
    required this.collections,
    required this.onAddSession,
    required this.onRenameCollection,
    required this.onDeleteCollection,
    required this.onOpenSession,
    required this.onRemoveSession,
    required this.onRenameSession,
  });

  final List<UserCollection> collections;
  final void Function(String collectionId) onAddSession;
  final void Function(UserCollection collection) onRenameCollection;
  final void Function(UserCollection collection) onDeleteCollection;
  final void Function(CanvasSnapshot snapshot) onOpenSession;
  final void Function(String collectionId, CollectionEntry entry) onRemoveSession;
  final void Function(String collectionId, CollectionEntry entry) onRenameSession;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1200
          ? 3
          : width >= 820
            ? 2
            : 1;
        final spacing = 16.0;
        final itemWidth = crossAxisCount == 1
            ? width
            : (width - spacing * (crossAxisCount - 1)) / crossAxisCount;

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: collections.map((collection) {
              return SizedBox(
                width: itemWidth,
                child: _CollectionBoard(
                  collection: collection,
                  onAddSession: () => onAddSession(collection.id),
                  onRename: () => onRenameCollection(collection),
                  onDelete: () => onDeleteCollection(collection),
                  onOpenSession: onOpenSession,
                  onRemoveSession: (entry) => onRemoveSession(collection.id, entry),
                  onRenameSession: (entry) => onRenameSession(collection.id, entry),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _CollectionBoard extends StatelessWidget {
  const _CollectionBoard({
    required this.collection,
    required this.onAddSession,
    required this.onRename,
    required this.onDelete,
    required this.onOpenSession,
    required this.onRemoveSession,
    required this.onRenameSession,
  });

  final UserCollection collection;
  final VoidCallback onAddSession;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final void Function(CanvasSnapshot snapshot) onOpenSession;
  final void Function(CollectionEntry entry) onRemoveSession;
  final void Function(CollectionEntry entry) onRenameSession;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFDF7FA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[200]! ),
        ),
        padding: EdgeInsets.all(AppTheme.spacing.small + 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        collection.name,
                        style: AppTheme.typography.subtitle.copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${collection.sessions.length} sessão${collection.sessions.length == 1 ? '' : 's'}',
                        style: AppTheme.typography.paragraph.copyWith(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Renomear coleção',
                  onPressed: onRename,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Excluir coleção',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: collection.sessions.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhuma sessão ainda. Adicione uma do histórico.',
                        style:
                            AppTheme.typography.paragraph.copyWith(fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: collection.sessions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final entry = collection.sessions[index];
                        return _CollectionSessionCard(
                          entry: entry,
                          onOpen: () => onOpenSession(entry.snapshot),
                          onRemove: () => onRemoveSession(entry),
                          onRename: () => onRenameSession(entry),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onAddSession,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar sessão'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionSessionCard extends StatelessWidget {
  const _CollectionSessionCard({
    required this.entry,
    required this.onOpen,
    required this.onRemove,
    required this.onRename,
  });

  final CollectionEntry entry;
  final VoidCallback onOpen;
  final VoidCallback onRemove;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final snapshot = entry.snapshot;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[200]!),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: snapshot.previewBytes != null
                ? Image.memory(
                    snapshot.previewBytes!,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 64,
                    height: 64,
                    color: Colors.grey[200],
                    alignment: Alignment.center,
                    child: const Icon(Icons.image_outlined),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snapshot.resolvedTitle,
                  style: AppTheme.typography.subtitle.copyWith(fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Adicionada em ${_formatDate(entry.addedAt)}',
                  style: AppTheme.typography.paragraph.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Abrir no canvas',
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new),
          ),
          IconButton(
            tooltip: 'Renomear sessão',
            onPressed: onRename,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Remover da coleção',
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
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
