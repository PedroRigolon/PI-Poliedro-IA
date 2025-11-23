import 'package:flutter/material.dart';

import '../../collection/data/canvas_snapshot_repository.dart';
import '../../collection/models/canvas_snapshot.dart';

class HistoryProvider extends ChangeNotifier {
  HistoryProvider({CanvasSnapshotRepository? repository})
      : _repository = repository ?? CanvasSnapshotRepository();

  final CanvasSnapshotRepository _repository;
  final List<CanvasSnapshot> _items = [];
  static const int _historyLimit = 80;
  bool _isLoading = false;
  bool _initialized = false;
  Future<void>? _initFuture;

  List<CanvasSnapshot> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading && !_initialized;

  Future<void> initialize() {
    _initFuture ??= _loadItems();
    return _initFuture!;
  }

  Future<void> _ensureLoaded() async {
    if (_initialized) return;
    await initialize();
  }

  Future<void> _loadItems() async {
    _isLoading = true;
    notifyListeners();
    final data = await _repository.load(SnapshotBox.history);
    _items
      ..clear()
      ..addAll(data);
    _initialized = true;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> add(CanvasSnapshot snapshot) async {
    await _ensureLoaded();
    _items.insert(0, snapshot);
    if (_items.length > _historyLimit) {
      _items.removeRange(_historyLimit, _items.length);
    }
    await _repository.saveAll(SnapshotBox.history, _items);
    notifyListeners();
  }

  Future<void> updateMetadata(
    String id, {
    required String title,
    String? notes,
  }) async {
    await _ensureLoaded();
    final index = _items.indexWhere((element) => element.id == id);
    if (index == -1) return;
    _items[index] = _items[index].copyWith(
      title: title,
      notes: notes?.isEmpty == true ? null : notes,
    );
    await _repository.saveAll(SnapshotBox.history, _items);
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await _ensureLoaded();
    _items.removeWhere((element) => element.id == id);
    await _repository.saveAll(SnapshotBox.history, _items);
    notifyListeners();
  }

  Future<void> clear() async {
    await _ensureLoaded();
    _items.clear();
    await _repository.clearBox(SnapshotBox.history);
    notifyListeners();
  }
}
