import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        backgroundColor: AppTheme.colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.all(AppTheme.spacing.medium),
        children: [
          Text(
            'Preferências',
            style: AppTheme.typography.subtitle.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: true,
            onChanged: (_) {},
            title: const Text('Tema escuro (placeholder)'),
          ),
          SwitchListTile(
            value: false,
            onChanged: (_) {},
            title: const Text('Notificações (placeholder)'),
          ),
          const Divider(height: 32),
          Text(
            'Conta',
            style: AppTheme.typography.subtitle.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Sobre o aplicativo'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
