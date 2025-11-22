import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';

class AuthRoutes {
  final DatabaseService _dbService;
  final AuthService _authService;

  AuthRoutes(DatabaseService dbService, String jwtSecret)
      : _dbService = dbService,
        _authService = AuthService(jwtSecret);

  Router get router {
    final router = Router();

    router.post('/register', _handleRegister);
    router.post('/login', _handleLogin);
    router.post('/logout', _handleLogout);

    return router;
  }

  Future<Response> _handleRegister(Request request) async {
    try {
      final payload = json.decode(await request.readAsString());
      final email = payload['email'] as String?;
      final password = payload['password'] as String?;

      // Validações
      if (email == null || email.isEmpty) {
        return Response(400, body: json.encode({'error': 'Email é obrigatório'}));
      }

      if (password == null || password.isEmpty) {
        return Response(400, body: json.encode({'error': 'Senha é obrigatória'}));
      }

      if (password.length < 6) {
        return Response(400,
            body: json.encode({'error': 'Senha deve ter no mínimo 6 caracteres'}));
      }

      if (!_authService.isValidInstitutionalEmail(email)) {
        return Response(400,
            body: json.encode({
              'error': 'Use seu email institucional (@sistemapoliedro.com.br ou @p4ed.com)'
            }));
      }

      // Verifica se usuário já existe
      final existingUser = await _dbService.findUserByEmail(email);
      if (existingUser != null) {
        return Response(409,
            body: json.encode({'error': 'Usuário já cadastrado com este email'}));
      }

      // Cria novo usuário
      final userType = _authService.getUserType(email);
      final hashedPassword = _authService.hashPassword(password);

      final Map<String, dynamic> newUser = {
        'email': email,
        'password': hashedPassword,
        'type': userType,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await _dbService.createUser(newUser);

      // Gera token
      final token = _authService.generateToken(email, userType);

      return Response.ok(
        json.encode({
          'message': 'Usuário cadastrado com sucesso',
          'user': {
            'email': email,
            'type': userType,
          },
          'token': token,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stackTrace) {
      print('❌ Erro no registro: $e');
      print('Stack trace: $stackTrace');
      return Response.internalServerError(
        body: json.encode({'error': 'Erro ao cadastrar usuário', 'details': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _handleLogin(Request request) async {
    try {
      final payload = json.decode(await request.readAsString());
      final email = payload['email'] as String?;
      final password = payload['password'] as String?;

      // Validações
      if (email == null || email.isEmpty) {
        return Response(400, body: json.encode({'error': 'Email é obrigatório'}));
      }

      if (password == null || password.isEmpty) {
        return Response(400, body: json.encode({'error': 'Senha é obrigatória'}));
      }

      // Busca usuário
      final user = await _dbService.findUserByEmail(email);
      if (user == null) {
        return Response(401,
            body: json.encode({'error': 'Email ou senha incorretos'}));
      }

      // Verifica senha
      final passwordHash = user['password'] as String;
      if (!_authService.verifyPassword(password, passwordHash)) {
        return Response(401,
            body: json.encode({'error': 'Email ou senha incorretos'}));
      }

      // Atualiza último login
      await _dbService.updateUser(email, {
        'lastLogin': DateTime.now().toIso8601String(),
      });

      // Gera token
      final token = _authService.generateToken(email, user['type'] as String);

      return Response.ok(
        json.encode({
          'message': 'Login realizado com sucesso',
          'user': {
            'email': email,
            'type': user['type'],
          },
          'token': token,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stackTrace) {
      print('❌ Erro no login: $e');
      print('Stack trace: $stackTrace');
      return Response.internalServerError(
        body: json.encode({'error': 'Erro ao fazer login', 'details': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _handleLogout(Request request) async {
    // Por enquanto, apenas retorna sucesso
    // Em produção, poderia invalidar o token no banco
    return Response.ok(
      json.encode({'message': 'Logout realizado com sucesso'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
