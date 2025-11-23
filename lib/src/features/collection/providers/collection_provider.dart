import 'package:flutter/material.dart';

import '../data/user_collection_repository.dart';
import '../models/canvas_snapshot.dart';
import '../models/collection_entry.dart';
import '../models/user_collection.dart';

class CollectionProvider extends ChangeNotifier {
  CollectionProvider({UserCollectionRepository? repository})
      : _repository = repository ?? UserCollectionRepository();

  final UserCollectionRepository _repository;
  final List<UserCollection> _collections = [];
  bool _isLoading = false;
  bool _initialized = false;
  Future<void>? _initFuture;

  List<UserCollection> get collections => List.unmodifiable(_collections);
  bool get isLoading => _isLoading && !_initialized;

  Future<void> initialize() {
    _initFuture ??= _loadCollections();
    return _initFuture!;
  }

  Future<void> _ensureLoaded() async {
    if (_initialized) return;
    await initialize();
  }

  Future<void> _loadCollections() async {
    _isLoading = true;
    notifyListeners();
    final data = await _repository.loadAll();
    _collections
      ..clear()
      ..addAll(data);
    _initialized = true;
    _isLoading = false;
    notifyListeners();
  }

  UserCollection? getById(String id) {
    if (!_initialized) return null;
    try {
      return _collections.firstWhere((element) => element.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<UserCollection> createCollection(String name) async {
    await _ensureLoaded();
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Collection name is required');
    }
    final now = DateTime.now();
    final collection = UserCollection(
      id: now.microsecondsSinceEpoch.toString(),
      name: trimmed,
      createdAt: now,
      updatedAt: now,
      sessions: const <CollectionEntry>[],
    );
    _collections.insert(0, collection);
    await _persist();
    notifyListeners();
    return collection;
  }

  Future<void> renameCollection(String id, String name) async {
    await _ensureLoaded();
    final index = _collections.indexWhere((element) => element.id == id);
    if (index == -1) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final now = DateTime.now();
    _collections[index] = _collections[index].copyWith(
      name: trimmed,
      updatedAt: now,
    );
    await _persist();
    notifyListeners();
  }

  Future<void> deleteCollection(String id) async {
    await _ensureLoaded();
    _collections.removeWhere((element) => element.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> addSession(String collectionId, CanvasSnapshot snapshot) async {
    await _ensureLoaded();
    final index = _collections.indexWhere((element) => element.id == collectionId);
    if (index == -1) return;
    final entry = CollectionEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      snapshot: snapshot,
      addedAt: DateTime.now(),
    );
    final current = _collections[index];
    _collections[index] = current.copyWith(
      sessions: [entry, ...current.sessions],
      updatedAt: DateTime.now(),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> removeSession(String collectionId, String entryId) async {
    await _ensureLoaded();
    final index = _collections.indexWhere((element) => element.id == collectionId);
    if (index == -1) return;
    final current = _collections[index];
    final updatedSessions = List<CollectionEntry>.from(current.sessions)
      ..removeWhere((element) => element.id == entryId);
    _collections[index] = current.copyWith(
      sessions: updatedSessions,
      updatedAt: DateTime.now(),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> renameSession(
    String collectionId,
    String entryId, {
    required String title,
    String? notes,
  }) async {
    await _ensureLoaded();
    final collectionIndex =
        _collections.indexWhere((element) => element.id == collectionId);
    if (collectionIndex == -1) return;
    final collection = _collections[collectionIndex];
    try {
      final entry =
          collection.sessions.firstWhere((element) => element.id == entryId);
      await updateSnapshotMetadata(
        entry.snapshot.id,
        title: title,
        notes: notes,
      );
    } catch (_) {
      return;
    }
  }

  Future<void> updateSnapshotMetadata(
    String snapshotId, {
    required String title,
    String? notes,
  }) async {
    await _ensureLoaded();
    final sanitizedNotes = notes?.trim();
    final resolvedNotes = sanitizedNotes?.isEmpty == true ? null : sanitizedNotes;
    bool modified = false;

    for (var i = 0; i < _collections.length; i++) {
      final collection = _collections[i];
      bool collectionChanged = false;
      final updatedSessions = <CollectionEntry>[];

      for (final entry in collection.sessions) {
        if (entry.snapshot.id == snapshotId) {
          collectionChanged = true;
          modified = true;
          updatedSessions.add(
            entry.copyWith(
              snapshot: entry.snapshot.copyWith(
                title: title,
                notes: resolvedNotes,
              ),
            ),
          );
        } else {
          updatedSessions.add(entry);
        }
      }

      if (collectionChanged) {
        _collections[i] = collection.copyWith(
          sessions: updatedSessions,
          updatedAt: DateTime.now(),
        );
      }
    }

    if (modified) {
      await _persist();
      notifyListeners();
    }
  }

  Future<void> clearAll() async {
    await _ensureLoaded();
    _collections.clear();
    await _repository.clear();
    notifyListeners();
  }

  Future<void> _persist() async {
    await _repository.saveAll(_collections);
  }
}
