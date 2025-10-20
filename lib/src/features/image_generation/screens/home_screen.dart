import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = false;
  final _promptController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: AppTheme.colors.background,
      appBar: AppBar(
        title: Image.asset('assets/images/logo.png', height: 40),
        actions: [
          IconButton(
            icon: Icon(Icons.account_circle),
            onPressed: _showProfileMenu,
          ),
        ],
      ),
      body: Row(
        children: [
          // Menu Lateral
          NavigationRail(
            selectedIndex: 0,
            onDestinationSelected: (index) {
              // TODO: Implementar navegação
            },
            labelType: NavigationRailLabelType.all,
            destinations: [
              NavigationRailDestination(
                icon: Icon(Icons.settings),
                label: Text('Configurações'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.view_in_ar),
                label: Text('Formas'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.build),
                label: Text('Configurações'),
              ),
            ],
          ),

          // Área Principal
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(AppTheme.spacing.large),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Gerar Imagens com IA',
                    style: AppTheme.typography.title,
                  ),
                  SizedBox(height: AppTheme.spacing.medium),

                  // Área de Input
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(AppTheme.spacing.medium),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Descreva a imagem que deseja gerar',
                            style: AppTheme.typography.subtitle,
                          ),
                          SizedBox(height: AppTheme.spacing.medium),
                          TextFormField(
                            controller: _promptController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText:
                                  'Ex: Gere um circuito com resistor e capacitor em série...',
                            ),
                          ),
                          SizedBox(height: AppTheme.spacing.medium),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _handleGenerateImage,
                            child: _isLoading
                                ? CircularProgressIndicator(color: Colors.white)
                                : Text('Gerar Imagem'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: AppTheme.spacing.large),

                  // Área de Visualização
                  Expanded(
                    child: Card(
                      child: Center(
                        child: Text(
                          'A imagem gerada aparecerá aqui',
                          style: AppTheme.typography.subtitle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showProfileMenu() {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width,
        kToolbarHeight,
        0,
        0,
      ),
      items: [
        PopupMenuItem(
          child: Text('Configurações'),
          onTap: () {
            // TODO: Navegar para configurações
          },
        ),
        PopupMenuItem(
          child: Text('Coleção'),
          onTap: () {
            // TODO: Navegar para coleção de imagens
          },
        ),
        PopupMenuItem(
          child: Text('Histórico'),
          onTap: () {
            // TODO: Navegar para histórico
          },
        ),
        PopupMenuItem(
          child: Text('Sair'),
          onTap: () async {
            await context.read<AuthProvider>().logout();
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/login');
            }
          },
        ),
      ],
    );
  }

  Future<void> _handleGenerateImage() async {
    if (_promptController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor, descreva a imagem que deseja gerar'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Implementar integração com a API de IA
      await Future.delayed(Duration(seconds: 2)); // Simulação

      // TODO: Mostrar imagem gerada
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }
}
