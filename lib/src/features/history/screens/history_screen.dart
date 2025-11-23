import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/app_navbar.dart';
import '../../collection/models/canvas_snapshot.dart';
import '../../collection/models/user_collection.dart';
import '../../collection/providers/collection_provider.dart';
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
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final snapshot = items[index];
                            return _HistoryTile(
                              snapshot: snapshot,
                              onOpen: () => _openSnapshot(snapshot),
                              onSaveToCollection: () =>
                                  _saveSnapshotToCollection(snapshot),
                              onRename: () => _renameSnapshot(snapshot),
                              onDelete: () => _deleteSnapshot(snapshot),
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

    final selection = await showModalBottomSheet<_CollectionSelectionResult>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CollectionPickerSheet(
        collections: collectionProvider.collections,
      ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sessão adicionada em "${collectionProvider.getById(targetCollectionId)?.name ?? 'Coleção'}".'),
      ),
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
    await context.read<HistoryProvider>().updateMetadata(
          snapshot.id,
          title: meta.title,
          notes: meta.notes,
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

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
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
    return ListTile(
      contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: AppTheme.spacing.small),
      leading: snapshot.previewBytes != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                snapshot.previewBytes!,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
              ),
            )
          : const Icon(Icons.image_outlined, size: 40),
      title: Text(snapshot.resolvedTitle),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_formatDate(snapshot.createdAt)),
          if ((snapshot.notes ?? '').isNotEmpty)
            Text(
              snapshot.notes!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      trailing: Wrap(
        spacing: 6,
        children: [
          IconButton(
            tooltip: 'Salvar na coleção',
            onPressed: onSaveToCollection,
            icon: const Icon(Icons.bookmark_add_outlined),
          ),
          IconButton(
            tooltip: 'Abrir no canvas',
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'open':
                  onOpen();
                  break;
                case 'save':
                  onSaveToCollection();
                  break;
                case 'rename':
                  onRename();
                  break;
                case 'delete':
                  onDelete();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'open', child: Text('Abrir no canvas')),
              PopupMenuItem(value: 'save', child: Text('Enviar para coleção')),
              PopupMenuItem(value: 'rename', child: Text('Renomear sessão')),
              PopupMenuItem(value: 'delete', child: Text('Excluir')),
            ],
          ),
        ],
      ),
      onTap: onOpen,
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

class _CollectionSelectionResult {
  const _CollectionSelectionResult({this.collectionId, this.pendingName});

  final String? collectionId;
  final String? pendingName;
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Adicionar à coleção', style: AppTheme.typography.subtitle),
            const SizedBox(height: 12),
            if (widget.collections.isEmpty)
              Text(
                'Crie uma nova coleção para guardar esta sessão.',
                style: AppTheme.typography.paragraph,
              )
            else ...[
              SizedBox(
                height: 220,
                child: ListView.separated(
                  itemCount: widget.collections.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final collection = widget.collections[index];
                    return ListTile(
                      title: Text(collection.name),
                      subtitle: Text(
                        '${collection.sessions.length} sessões salvas',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _selectExisting(collection.id),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
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
                      label: const Text('Criar e adicionar'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectExisting(String collectionId) {
    Navigator.of(context).pop(
      _CollectionSelectionResult(collectionId: collectionId),
    );
  }

  void _createAndAdd() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _CollectionSelectionResult(pendingName: _controller.text.trim()),
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
