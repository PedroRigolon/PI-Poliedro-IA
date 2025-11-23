import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/canvas_snapshot.dart';

enum SnapshotBox { collection, history }

class CanvasSnapshotRepository {
  static const Map<SnapshotBox, String> _storageKeys = {
    SnapshotBox.collection: 'canvas_collection_snapshots',
    SnapshotBox.history: 'canvas_history_snapshots',
  };

  Future<List<CanvasSnapshot>> load(SnapshotBox box) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getStringList(_storageKeys[box]!) ?? <String>[];
    return encoded
        .map((item) => CanvasSnapshot.fromMap(
              jsonDecode(item) as Map<String, dynamic>,
            ))
        .toList();
  }

  Future<void> saveAll(SnapshotBox box, List<CanvasSnapshot> snapshots) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = snapshots.map((e) => jsonEncode(e.toMap())).toList();
    await prefs.setStringList(_storageKeys[box]!, payload);
  }

  Future<void> clearBox(SnapshotBox box) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKeys[box]!);
  }
}
