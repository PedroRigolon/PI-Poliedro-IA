import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/app_navbar.dart';
import '../../../widgets/app_notification.dart';
import '../../collection/models/canvas_snapshot.dart';
import '../../collection/providers/collection_provider.dart';
import '../../collection/widgets/collection_picker_sheet.dart';
import '../../collection/widgets/snapshot_metadata_sheet.dart';
import '../providers/history_provider.dart';

enum _HistoryRange { all, week, day }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _searchQuery = '';
  _HistoryRange _range = _HistoryRange.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HistoryProvider>();
    final items = _applyFilters(provider.items);

    return Scaffold(
      backgroundColor: AppTheme.colors.background,
      appBar: const AppNavbar(),
      body: Padding(
        padding: EdgeInsets.all(AppTheme.spacing.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(provider.items.length),
            const SizedBox(height: 24),
            _buildToolbar(provider.isLoading),
            const SizedBox(height: 16),
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                      ? const _EmptyHistory()
                      : _HistoryGrid(
                          items: items,
                          onOpen: _openSnapshot,
                          onSaveToCollection: _saveSnapshotToCollection,
                          onRename: _renameSnapshot,
                          onDelete: _deleteSnapshot,
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
        Text('Histórico', style: AppTheme.typography.title),
        const SizedBox(height: 6),
        Text(
          '$total sessões registradas automaticamente a cada salvamento.',
          style: AppTheme.typography.paragraph.copyWith(fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildToolbar(bool isLoading) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Buscar por título ou descrição',
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(width: 16),
            SegmentedButton<_HistoryRange>(
              segments: const [
                ButtonSegment(
                  value: _HistoryRange.all,
                  label: Text('Sempre'),
                ),
                ButtonSegment(
                  value: _HistoryRange.week,
                  label: Text('7 dias'),
                ),
                ButtonSegment(
                  value: _HistoryRange.day,
                  label: Text('24h'),
                ),
              ],
              selected: <_HistoryRange>{_range},
              onSelectionChanged: (value) => setState(() {
                _range = value.first;
              }),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: isLoading ? null : _clearHistory,
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Limpar histórico'),
          ),
        ),
      ],
    );
  }

  List<CanvasSnapshot> _applyFilters(List<CanvasSnapshot> items) {
    final now = DateTime.now();
    return items.where((snapshot) {
      final matchesSearch = _searchQuery.isEmpty
          ? true
          : snapshot.resolvedTitle
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              (snapshot.notes ?? '').toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  );

      bool matchesRange = true;
      switch (_range) {
        case _HistoryRange.all:
          matchesRange = true;
          break;
        case _HistoryRange.week:
          matchesRange = now.difference(snapshot.createdAt).inDays <= 7;
          break;
        case _HistoryRange.day:
          matchesRange = now.difference(snapshot.createdAt).inHours <= 24;
          break;
      }

      return matchesSearch && matchesRange;
    }).toList();
  }

  Future<void> _openSnapshot(CanvasSnapshot snapshot) async {
    await Navigator.pushNamed(context, '/home', arguments: snapshot);
  }

  Future<void> _saveSnapshotToCollection(CanvasSnapshot snapshot) async {
    final collectionProvider = context.read<CollectionProvider>();
    await collectionProvider.initialize();
    if (!mounted) return;

    final selection = await showCollectionPickerSheet(
      context,
      collections: collectionProvider.collections,
    );

    if (selection == null || !mounted) return;

    var targetCollectionId = selection.collectionId;
    if (selection.pendingName != null) {
      final created =
          await collectionProvider.createCollection(selection.pendingName!);
      targetCollectionId = created.id;
    }

    if (targetCollectionId == null) return;

    await collectionProvider.addSession(targetCollectionId, snapshot);

    if (!mounted) return;
    showAppNotification(
      context,
      message:
          'Sessão adicionada em "${collectionProvider.getById(targetCollectionId)?.name ?? 'Coleção'}".',
      type: AppNotificationType.success,
    );
  }

  Future<void> _renameSnapshot(CanvasSnapshot snapshot) async {
    final meta = await showSnapshotMetadataSheet(
      context,
      initialTitle: snapshot.resolvedTitle,
      initialNotes: snapshot.notes,
      helperText: 'Dê um nome fácil de lembrar para esta sessão.',
      titleLabel: 'Editar sessão',
      actionLabel: 'Salvar',
    );
    if (meta == null || !mounted) return;

    final trimmedTitle = meta.title.trim();
    final resolvedTitle =
        trimmedTitle.isEmpty ? snapshot.resolvedTitle : trimmedTitle;
    final trimmedNotes = meta.notes?.trim();
    final resolvedNotes =
        trimmedNotes?.isEmpty == true ? null : trimmedNotes;

    final historyProvider = context.read<HistoryProvider>();
    await historyProvider.updateMetadata(
      snapshot.id,
      title: resolvedTitle,
      notes: resolvedNotes,
    );

    if (!mounted) return;
    final collectionProvider = context.read<CollectionProvider>();
    final relatedIds = <String>{snapshot.id};
    if (snapshot.id.startsWith('history-')) {
      relatedIds.add(snapshot.id.replaceFirst('history-', ''));
    } else {
      relatedIds.add('history-${snapshot.id}');
    }

    for (final id in relatedIds) {
      await collectionProvider.updateSnapshotMetadata(
        id,
        title: resolvedTitle,
        notes: resolvedNotes,
      );
    }

    if (!mounted) return;
    showAppNotification(
      context,
      message: 'Sessão atualizada com sucesso.',
      type: AppNotificationType.success,
    );
  }

  Future<void> _deleteSnapshot(CanvasSnapshot snapshot) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Excluir registro'),
            content: Text('Remover "${snapshot.resolvedTitle}" do histórico?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.colors.primary,
                ),
                child: const Text('Excluir'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    await context.read<HistoryProvider>().delete(snapshot.id);
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Limpar histórico'),
            content: const Text('Esta ação não pode ser desfeita. Continuar?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.colors.primary,
                ),
                child: const Text('Limpar'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    await context.read<HistoryProvider>().clear();
  }
}

class _HistoryGrid extends StatelessWidget {
  const _HistoryGrid({
    required this.items,
    required this.onOpen,
    required this.onSaveToCollection,
    required this.onRename,
    required this.onDelete,
  });

  final List<CanvasSnapshot> items;
  final void Function(CanvasSnapshot snapshot) onOpen;
  final void Function(CanvasSnapshot snapshot) onSaveToCollection;
  final void Function(CanvasSnapshot snapshot) onRename;
  final void Function(CanvasSnapshot snapshot) onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1400
            ? 4
            : width >= 1100
                ? 3
                : width >= 760
                    ? 2
                    : 1;
        return GridView.builder(
          itemCount: items.length,
          padding: const EdgeInsets.only(bottom: 32),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.25,
          ),
          itemBuilder: (context, index) {
            final snapshot = items[index];
            return _HistoryCard(
              snapshot: snapshot,
              onOpen: () => onOpen(snapshot),
              onSaveToCollection: () => onSaveToCollection(snapshot),
              onRename: () => onRename(snapshot),
              onDelete: () => onDelete(snapshot),
            );
          },
        );
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.snapshot,
    required this.onOpen,
    required this.onSaveToCollection,
    required this.onRename,
    required this.onDelete,
  });

  final CanvasSnapshot snapshot;
  final VoidCallback onOpen;
  final VoidCallback onSaveToCollection;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 21 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: snapshot.previewBytes != null
                    ? Image.memory(snapshot.previewBytes!, fit: BoxFit.cover)
                    : Container(
                        color: Colors.grey[100],
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_outlined, size: 40),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              snapshot.resolvedTitle,
              style: AppTheme.typography.subtitle.copyWith(fontSize: 18),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(snapshot.createdAt),
              style: AppTheme.typography.paragraph.copyWith(fontSize: 13),
            ),
            if ((snapshot.notes ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                snapshot.notes!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.typography.paragraph.copyWith(fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 20),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 4,
              children: [
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
                  tooltip: 'Salvar em coleção',
                  onPressed: onSaveToCollection,
                  icon: const Icon(Icons.bookmark_add_outlined),
                ),
                IconButton(
                  tooltip: 'Excluir',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history_toggle_off, size: 72),
          const SizedBox(height: 16),
          Text('Nenhum registro ainda', style: AppTheme.typography.subtitle),
          const SizedBox(height: 8),
          const Text(
            'Salve composições no canvas para acompanhar o histórico.',
            textAlign: TextAlign.center,
          ),
        ],
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
