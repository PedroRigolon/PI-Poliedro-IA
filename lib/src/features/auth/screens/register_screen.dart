import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

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
                horizontal: AppTheme.spacing.authCardPadding,
                vertical: AppTheme.spacing.large,
              ),
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(AppTheme.spacing.large),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    Image.asset('assets/images/logo.png', height: 80),
                    SizedBox(height: AppTheme.spacing.large),

                    Text(
                      'Email @sistemapoliedro OU @p4ed',
                      style: AppTheme.typography.subtitle,
                    ),
                    SizedBox(height: AppTheme.spacing.medium),

                    // Formulário
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Email', style: AppTheme.typography.label),
                          SizedBox(height: AppTheme.spacing.small),
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              hintText: 'Digite seu email...',
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, digite seu email';
                              }
                              if (!value.contains('@sistemapoliedro.com.br') &&
                                  !value.contains('@p4ed.com')) {
                                return 'Use seu email institucional';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: AppTheme.spacing.medium),

                          Text('Senha', style: AppTheme.typography.label),
                          SizedBox(height: AppTheme.spacing.small),
                          TextFormField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              hintText: 'Digite sua senha...',
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
                          SizedBox(height: AppTheme.spacing.medium),

                          Text(
                            'Confirmar Senha',
                            style: AppTheme.typography.label,
                          ),
                          SizedBox(height: AppTheme.spacing.small),
                          TextFormField(
                            controller: _confirmPasswordController,
                            decoration: InputDecoration(
                              hintText: 'Repita sua senha...',
                            ),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, confirme sua senha';
                              }
                              if (value != _passwordController.text) {
                                return 'As senhas não coincidem';
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
                                onPressed: _handleRegister,
                                child: Text('Cadastrar-se'),
                              );
                            },
                          ),

                          SizedBox(height: AppTheme.spacing.medium),

                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: Text(
                              'Já possui uma conta? Login',
                              style: TextStyle(color: AppTheme.colors.primary),
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
    )
    );
  }

  Future<void> _handleRegister() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        await context.read<AuthProvider>().register(
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
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
