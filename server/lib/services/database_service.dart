import 'package:mongo_dart/mongo_dart.dart';

class DatabaseService {
  final String connectionString;
  final String dbName;
  late Db _db;
  
  DatabaseService({
    required this.connectionString,
    required this.dbName,
  });

  Future<void> connect() async {
    _db = await Db.create(connectionString);
    await _db.open();
  }

  Db get database => _db;

  DbCollection get usersCollection => _db.collection('users');

  Future<void> close() async {
    await _db.close();
  }

  // Busca usuário por email
  Future<Map<String, dynamic>?> findUserByEmail(String email) async {
    return await usersCollection.findOne(where.eq('email', email));
  }

  // Cria novo usuário
  Future<void> createUser(Map<String, dynamic> user) async {
    await usersCollection.insertOne(user);
  }

  // Atualiza usuário com campos arbitrários
  Future<void> updateUser(String email, Map<String, dynamic> updates) async {
    final modifier = modify.set('updatedAt', DateTime.now().toIso8601String());
    updates.forEach((key, value) {
      if (value == null) {
        modifier.unset(key);
      } else {
        modifier.set(key, value);
      }
    });

    await usersCollection.updateOne(where.eq('email', email), modifier);
  }

  Future<void> deleteUser(String email) async {
    await usersCollection.deleteOne(where.eq('email', email));
  }
}
