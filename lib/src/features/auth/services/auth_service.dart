import '../models/user_model.dart';

class AuthService {
  // TODO: Implementar integração com MongoDB
  Future<UserModel> login(String email, String password) async {
    // Simular delay de rede
    await Future.delayed(const Duration(seconds: 2));

    // TODO: Implementar validação real com MongoDB
    if (!_isValidEmail(email)) {
      throw Exception('Email inválido');
    }

    // Simulação de resposta
    return UserModel(
      email: email,
      type: email.contains('@sistemapoliedro.com.br')
          ? UserType.professor
          : UserType.student,
    );
  }

  Future<UserModel> register(String email, String password) async {
    // Simular delay de rede
    await Future.delayed(const Duration(seconds: 2));

    // TODO: Implementar registro real com MongoDB
    if (!_isValidEmail(email)) {
      throw Exception('Email inválido');
    }

    // Simulação de registro
    return UserModel(
      email: email,
      type: email.contains('@sistemapoliedro.com.br')
          ? UserType.professor
          : UserType.student,
    );
  }

  bool _isValidEmail(String email) {
    return email.contains('@sistemapoliedro.com.br') ||
        email.contains('@p4ed.com');
  }

  Future<void> logout() async {
    // TODO: Implementar logout real (limpar token, etc)
    await Future.delayed(const Duration(seconds: 1));
  }
}
