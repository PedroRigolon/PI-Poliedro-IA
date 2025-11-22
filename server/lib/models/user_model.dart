import 'package:mongo_dart/mongo_dart.dart';

/// Modelo de usuário para MongoDB
class UserModel {
  final ObjectId? id;
  final String email;
  final String password; // Hash bcrypt
  final String type; // 'professor' ou 'student'
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLogin;

  UserModel({
    this.id,
    required this.email,
    required this.password,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    this.lastLogin,
  });

  /// Converte documento MongoDB para UserModel
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['_id'] as ObjectId?,
      email: map['email'] as String,
      password: map['password'] as String,
      type: map['type'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      lastLogin: map['lastLogin'] != null
          ? DateTime.parse(map['lastLogin'] as String)
          : null,
    );
  }

  /// Converte UserModel para documento MongoDB
  Map<String, dynamic> toMap() {
    return {
      if (id != null) '_id': id,
      'email': email,
      'password': password,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (lastLogin != null) 'lastLogin': lastLogin!.toIso8601String(),
    };
  }

  /// Cria cópia com campos atualizados
  UserModel copyWith({
    ObjectId? id,
    String? email,
    String? password,
    String? type,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLogin,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      password: password ?? this.password,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
}
