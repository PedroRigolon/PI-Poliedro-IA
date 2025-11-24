import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthService {
  static const String baseUrl = 'http://localhost:8080/api/auth';
  final Dio _dio = Dio();

  Future<UserModel> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '$baseUrl/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final token = data['token'] as String;
        final userType = data['user']['type'] as String;

        final prefs = await SharedPreferences.getInstance();
        await _persistSession(prefs, token: token, email: email, userType: userType);

        return UserModel(
          email: email,
          type: _parseUserType(userType),
        );
      } else {
        throw Exception('Erro ao fazer login');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final error = e.response!.data['error'] ?? 'Erro ao fazer login';
        throw Exception(error);
      }
      throw Exception('Erro de conexão com o servidor');
    }
  }

  Future<UserModel> register(String email, String password) async {
    try {
      final response = await _dio.post(
        '$baseUrl/register',
        data: {
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final token = data['token'] as String;
        final userType = data['user']['type'] as String;

        final prefs = await SharedPreferences.getInstance();
        await _persistSession(prefs, token: token, email: email, userType: userType);

        return UserModel(
          email: email,
          type: _parseUserType(userType),
        );
      } else {
        throw Exception('Erro ao cadastrar usuário');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final error = e.response!.data['error'] ?? 'Erro ao cadastrar usuário';
        throw Exception(error);
      }
      throw Exception('Erro de conexão com o servidor');
    }
  }

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token != null) {
        await _dio.post(
          '$baseUrl/logout',
          options: Options(
            headers: {'Authorization': 'Bearer $token'},
          ),
        );
      }

      await _clearSession(prefs);
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      await _clearSession(prefs);
    }
  }

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final headers = await _buildAuthHeaders();
      await _dio.post(
        '$baseUrl/change-password',
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
        options: Options(headers: headers),
      );
    } on DioException catch (e) {
      final error = e.response?.data['error'] ?? 'Erro ao alterar senha';
      throw Exception(error);
    }
  }

  Future<void> deleteAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      throw Exception('Sessão expirada. Faça login novamente.');
    }

    try {
      await _dio.delete(
        '$baseUrl/account',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      final error = e.response?.data['error'] ?? 'Erro ao excluir conta';
      throw Exception(error);
    } finally {
      await _clearSession(prefs);
    }
  }

  Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email');
    final userType = prefs.getString('user_type');

    if (email != null && userType != null) {
      return UserModel(
        email: email,
        type: _parseUserType(userType),
      );
    }

    return null;
  }

  UserType _parseUserType(String type) {
    switch (type) {
      case 'professor':
        return UserType.professor;
      case 'student':
        return UserType.student;
      case 'admin':
        return UserType.admin;
      default:
        return UserType.student;
    }
  }

  Future<void> _persistSession(
    SharedPreferences prefs, {
    required String token,
    required String email,
    required String userType,
  }) async {
    await prefs.setString('auth_token', token);
    await prefs.setString('user_email', email);
    await prefs.setString('user_type', userType);
  }

  Future<void> _clearSession(SharedPreferences prefs) async {
    await prefs.remove('auth_token');
    await prefs.remove('user_email');
    await prefs.remove('user_type');
  }

  Future<Map<String, String>> _buildAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      throw Exception('Sessão expirada. Faça login novamente.');
    }
    return {'Authorization': 'Bearer $token'};
  }
}
