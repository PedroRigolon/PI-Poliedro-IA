import 'dart:io';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:dotenv/dotenv.dart';
import 'package:poliedro_server/services/database_service.dart';
import 'package:poliedro_server/services/auth_service.dart';

void main() async {
  print('🔧 Criando usuário admin...');

  // Carrega variáveis de ambiente
  final env = DotEnv()..load(['../.env']);
  
  final connectionString = env['MONGODB_URI'];
  final dbName = env['DB_NAME'] ?? 'poliedro_ia';
  final jwtSecret = env['JWT_SECRET'];

  if (connectionString == null || jwtSecret == null) {
    print('❌ Erro: Variáveis de ambiente MONGODB_URI ou JWT_SECRET não encontradas.');
    exit(1);
  }

  // Inicializa serviços
  final dbService = DatabaseService(
    connectionString: connectionString,
    dbName: dbName,
  );
  
  final authService = AuthService(jwtSecret);

  try {
    await dbService.connect();
    print('✅ Conectado ao MongoDB');

    final email = 'admin@poliedro.ia';
    final password = 'admin';
    
    // Verifica se já existe
    final existingUser = await dbService.findUserByEmail(email);
    if (existingUser != null) {
      print('⚠️ Usuário admin já existe. Atualizando senha...');
      
      final hashedPassword = authService.hashPassword(password);
      await dbService.usersCollection.update(
        where.eq('email', email),
        modify.set('password', hashedPassword)
              .set('type', 'admin')
              .set('updatedAt', DateTime.now().toIso8601String()),
      );
      print('✅ Senha do admin atualizada com sucesso!');
    } else {
      print('📝 Criando novo usuário admin...');
      
      final hashedPassword = authService.hashPassword(password);
      final Map<String, dynamic> newUser = {
        'email': email,
        'password': hashedPassword,
        'type': 'admin',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await dbService.createUser(newUser);
      print('✅ Usuário admin criado com sucesso!');
    }
    
    print('\n🔑 Credenciais de acesso:');
    print('   Email: $email');
    print('   Senha: $password');

  } catch (e) {
    print('❌ Erro ao criar admin: $e');
  } finally {
    await dbService.close();
    print('🔌 Conexão fechada');
  }
}
