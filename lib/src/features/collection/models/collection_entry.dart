import 'canvas_snapshot.dart';

class CollectionEntry {
  const CollectionEntry({
    required this.id,
    required this.snapshot,
    required this.addedAt,
  });

  final String id;
  final CanvasSnapshot snapshot;
  final DateTime addedAt;

  CollectionEntry copyWith({
    String? id,
    CanvasSnapshot? snapshot,
    DateTime? addedAt,
  }) {
    return CollectionEntry(
      id: id ?? this.id,
      snapshot: snapshot ?? this.snapshot,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'addedAt': addedAt.toIso8601String(),
      'snapshot': snapshot.toMap(),
    };
  }

  factory CollectionEntry.fromMap(Map<String, dynamic> map) {
    return CollectionEntry(
      id: map['id'] as String,
      addedAt: DateTime.parse(map['addedAt'] as String),
      snapshot: CanvasSnapshot.fromMap(
        Map<String, dynamic>.from(
          map['snapshot'] as Map<String, dynamic>,
        ),
      ),
    );
  }
}
