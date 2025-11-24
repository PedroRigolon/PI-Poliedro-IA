import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:dotenv/dotenv.dart';
import 'package:poliedro_server/services/database_service.dart';
import 'package:poliedro_server/routes/auth_routes.dart';

void main() async {
  // Carrega variáveis de ambiente
  final env = DotEnv()..load(['../.env']);
  
  // Inicializa conexão com MongoDB
  final dbService = DatabaseService(
    connectionString: env['MONGODB_URI']!,
    dbName: env['DB_NAME'] ?? 'poliedro_ia',
  );
  
  await dbService.connect();
  print('✅ Conectado ao MongoDB Atlas');

  // Configura rotas
  final router = Router();
  
  // Rotas de autenticação
  router.mount('/api/auth/', AuthRoutes(dbService, env['JWT_SECRET']!).router);
  
  // Rota de health check
  router.get('/health', (Request request) {
    return Response.ok('Server is running');
  });

  // Middleware CORS
  final overrideHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
  };

  final handler = Pipeline()
      .addMiddleware(corsHeaders(headers: overrideHeaders))
      .addMiddleware(logRequests())
      .addHandler(router.call);

  // Inicia servidor
  final port = int.parse(env['SERVER_PORT'] ?? '8080');
  final server = await shelf_io.serve(handler, 'localhost', port);
  
  print('🚀 Servidor rodando em http://${server.address.host}:${server.port}');
  print('📝 Endpoints disponíveis:');
  print('   POST /api/auth/register');
  print('   POST /api/auth/login');
  print('   POST /api/auth/logout');
  print('   POST /api/auth/change-password');
  print('   DELETE /api/auth/account');
  print('   GET  /health');
}
