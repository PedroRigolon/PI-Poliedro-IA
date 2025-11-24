import 'dart:convert';
import 'dart:typed_data';

class CanvasSnapshot {
  CanvasSnapshot({
    required this.id,
    required this.createdAt,
    required this.stateJson,
    this.title,
    this.notes,
    this.previewBase64,
    this.isFavorite = false,
  });

  final String id;
  final DateTime createdAt;
  final String stateJson;
  final String? title;
  final String? notes;
  final String? previewBase64;
  final bool isFavorite;

  static const _undefined = Object();

  Uint8List? get previewBytes =>
      previewBase64 == null ? null : base64Decode(previewBase64!);

  CanvasSnapshot copyWith({
    String? id,
    DateTime? createdAt,
    String? stateJson,
    Object? title = _undefined,
    Object? notes = _undefined,
    String? previewBase64,
    bool? isFavorite,
  }) {
    return CanvasSnapshot(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      stateJson: stateJson ?? this.stateJson,
      title: identical(title, _undefined) ? this.title : title as String?,
      notes: identical(notes, _undefined) ? this.notes : notes as String?,
      previewBase64: previewBase64 ?? this.previewBase64,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'state': stateJson,
      'favorite': isFavorite,
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (previewBase64 != null) 'preview': previewBase64,
    };
  }

  factory CanvasSnapshot.fromMap(Map<String, dynamic> map) {
    return CanvasSnapshot(
      id: map['id'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      stateJson: map['state'] as String? ?? '{}',
      title: map['title'] as String?,
      notes: map['notes'] as String?,
      previewBase64: map['preview'] as String?,
      isFavorite: map['favorite'] as bool? ?? false,
    );
  }

  String get resolvedTitle {
    return (title == null || title!.trim().isEmpty)
        ? 'Composição de ${_formatDate(createdAt)}'
        : title!;
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString().padLeft(4, '0');
    return '$day/$month/$year';
  }
}
