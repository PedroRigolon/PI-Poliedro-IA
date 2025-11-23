import 'collection_entry.dart';

class UserCollection {
  const UserCollection({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.sessions,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<CollectionEntry> sessions;

  UserCollection copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<CollectionEntry>? sessions,
  }) {
    return UserCollection(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sessions: sessions ?? this.sessions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'sessions': sessions.map((item) => item.toMap()).toList(),
    };
  }

  factory UserCollection.fromMap(Map<String, dynamic> map) {
    return UserCollection(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      sessions: (map['sessions'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => CollectionEntry.fromMap(
                Map<String, dynamic>.from(item as Map<String, dynamic>),
              ))
          .toList(),
    );
  }
}
