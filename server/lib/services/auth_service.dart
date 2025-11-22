import 'package:bcrypt/bcrypt.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class AuthService {
  final String jwtSecret;

  AuthService(this.jwtSecret);

  // Gera hash da senha
  String hashPassword(String password) {
    return BCrypt.hashpw(password, BCrypt.gensalt());
  }

  // Verifica senha
  bool verifyPassword(String password, String hash) {
    return BCrypt.checkpw(password, hash);
  }

  // Gera JWT token
  String generateToken(String email, String userType) {
    final jwt = JWT({
      'email': email,
      'type': userType,
      'iat': DateTime.now().millisecondsSinceEpoch,
      'exp': DateTime.now().add(Duration(days: 7)).millisecondsSinceEpoch,
    });

    return jwt.sign(SecretKey(jwtSecret));
  }

  // Valida JWT token
  Map<String, dynamic>? verifyToken(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(jwtSecret));
      return jwt.payload as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  // Valida email institucional
  bool isValidInstitutionalEmail(String email) {
    return email.endsWith('@sistemapoliedro.com.br') ||
           email.endsWith('@p4ed.com');
  }

  // Determina tipo de usuário baseado no email
  String getUserType(String email) {
    if (email.endsWith('@sistemapoliedro.com.br')) {
      return 'professor';
    } else if (email.endsWith('@p4ed.com')) {
      return 'student';
    }
    return 'student';
  }
}
