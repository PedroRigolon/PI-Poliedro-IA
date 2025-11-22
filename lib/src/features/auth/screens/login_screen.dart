import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spacing.getAuthCardPadding(context),
                vertical: AppTheme.spacing.large,
              ),
              child: Card(
                elevation: 4,
                shadowColor: Colors.black26,
                color: AppTheme.colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.black12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(AppTheme.spacing.large),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      Image.asset('assets/images/logo.png', height: 80),
                      SizedBox(height: AppTheme.spacing.large),

                      // Formulário
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Email',
                              style: AppTheme.typography.label.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: AppTheme.spacing.small),
                            TextFormField(
                              controller: _emailController,
                              style: TextStyle(color: Colors.grey[800]),
                              decoration: InputDecoration(
                                hintText: 'Digite seu email...',
                                hintStyle: TextStyle(color: Colors.grey[800]),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Colors.black12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Colors.black12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Colors.black26),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor, digite seu email';
                                }
                                if (!value.contains(
                                      '@sistemapoliedro.com.br',
                                    ) &&
                                    !value.contains('@p4ed.com')) {
                                  return 'Use seu email institucional';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: AppTheme.spacing.medium),

                            Text(
                              'Senha',
                              style: AppTheme.typography.label.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: AppTheme.spacing.small),
                            TextFormField(
                              controller: _passwordController,
                              style: TextStyle(color: Colors.grey[800]),
                              decoration: InputDecoration(
                                hintText: 'Digite sua senha...',
                                hintStyle: TextStyle(color: Colors.grey[800]),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Colors.black12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Colors.black12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Colors.black26),
                                ),
                              ),
                              obscureText: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor, digite sua senha';
                                }
                                if (value.length < 6) {
                                  return 'A senha deve ter no mínimo 6 caracteres';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: AppTheme.spacing.large),

                            Consumer<AuthProvider>(
                              builder: (context, auth, child) {
                                if (auth.isLoading) {
                                  return Center(
                                    child:
                                        LoadingAnimationWidget.staggeredDotsWave(
                                          color: AppTheme.colors.primary,
                                          size: 40,
                                        ),
                                  );
                                }

                                return ElevatedButton(
                                  onPressed: _handleLogin,
                                  child: Text('Login'),
                                );
                              },
                            ),

                            SizedBox(height: AppTheme.spacing.medium),

                            TextButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/register');
                              },
                              child: Text(
                                'Não possui uma conta? Cadastre-se',
                                style: TextStyle(
                                  color: AppTheme.colors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        await context.read<AuthProvider>().login(
          _emailController.text,
          _passwordController.text,
        );

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
