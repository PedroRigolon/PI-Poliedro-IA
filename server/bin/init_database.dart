import 'package:mongo_dart/mongo_dart.dart';
import 'package:dotenv/dotenv.dart';

/// Script para inicializar o banco de dados MongoDB
/// Cria coleções, índices e validações necessárias
Future<void> main() async {
  print('🔧 Inicializando banco de dados MongoDB...\n');

  // Carrega variáveis de ambiente
  final env = DotEnv()..load(['../.env']);
  
  final connectionString = env['MONGODB_URI']!;
  final dbName = env['DB_NAME'] ?? 'poliedro_ia';

  // Conecta ao MongoDB
  final db = await Db.create(connectionString);
  await db.open();
  print('✅ Conectado ao MongoDB Atlas\n');

  try {
    // Seleciona/cria coleção de usuários
    final usersCollection = db.collection('users');
    
    print('📋 Criando índices na collection "users"...');
    
    // Índice único de email
    await usersCollection.createIndex(
      key: 'email',
      unique: true,
      name: 'email_unique_index',
    );
    print('  ✅ Índice único criado: email');

    // Índice de tipo de usuário
    await usersCollection.createIndex(
      key: 'type',
      name: 'type_index',
    );
    print('  ✅ Índice criado: type');

    // Índice de data de criação (ordem decrescente)
    await usersCollection.createIndex(
      keys: {'createdAt': -1},
      name: 'created_at_index',
    );
    print('  ✅ Índice criado: createdAt');

    print('\n📊 Estatísticas do banco:');
    
    // Conta documentos
    final userCount = await usersCollection.count();
    print('  👥 Total de usuários: $userCount');

    if (userCount > 0) {
      // Conta por tipo
      final pipeline = [
        {
          '\$group': {
            '_id': '\$type',
            'count': {'\$sum': 1}
          }
        }
      ];
      
      final result = await usersCollection.aggregateToStream(pipeline).toList();
      
      print('\n  📈 Usuários por tipo:');
      for (var doc in result) {
        final type = doc['_id'];
        final count = doc['count'];
        final emoji = type == 'professor' ? '👨‍🏫' : '👨‍🎓';
        print('    $emoji $type: $count');
      }
    }

    print('\n🎉 Banco de dados inicializado com sucesso!');
    print('📝 Database: $dbName');
    print('🔗 Coleções criadas:');
    print('  - users (com índices)');
    
  } catch (e) {
    print('❌ Erro ao inicializar banco: $e');
    rethrow;
  } finally {
    await db.close();
    print('\n🔌 Conexão com MongoDB fechada');
  }
}
