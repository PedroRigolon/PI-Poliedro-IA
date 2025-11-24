import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'src/core/theme/app_theme.dart';
import 'src/features/auth/providers/auth_provider.dart';
import 'src/features/auth/screens/login_screen.dart';
import 'src/features/auth/screens/register_screen.dart';
import 'src/features/collection/providers/collection_provider.dart';
import 'src/features/history/providers/history_provider.dart';
import 'src/features/image_generation/screens/home_screen.dart';
import 'src/features/settings/screens/settings_screen.dart';
import 'src/features/collection/screens/collection_screen.dart';
import 'src/features/history/screens/history_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CollectionProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
      ],
      child: const App(),
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Poliedro - Geração de Imagens',
      theme: AppTheme.light,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/collection': (context) => const CollectionScreen(),
        '/history': (context) => const HistoryScreen(),
      },
    );
  }
}
