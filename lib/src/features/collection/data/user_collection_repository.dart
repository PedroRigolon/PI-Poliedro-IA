import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_collection.dart';

class UserCollectionRepository {
  static const String _storageKey = 'user_collections_v1';

  Future<List<UserCollection>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_storageKey);
    if (encoded == null || encoded.isEmpty) {
      return <UserCollection>[];
    }
    final List<dynamic> raw = jsonDecode(encoded) as List<dynamic>;
    return raw
        .map((item) => UserCollection.fromMap(
              Map<String, dynamic>.from(item as Map<String, dynamic>),
            ))
        .toList();
  }

  Future<void> saveAll(List<UserCollection> data) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(data.map((item) => item.toMap()).toList());
    await prefs.setString(_storageKey, payload);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
