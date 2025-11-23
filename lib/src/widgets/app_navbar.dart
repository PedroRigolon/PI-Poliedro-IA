import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/providers/auth_provider.dart';

enum _AccountMenuOption { settings, collection, history, logout }

class AppNavbar extends StatelessWidget implements PreferredSizeWidget {
  const AppNavbar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  Future<void> _handleSelection(
    BuildContext context,
    _AccountMenuOption option,
  ) async {
    switch (option) {
      case _AccountMenuOption.settings:
        Navigator.pushNamed(context, '/settings');
        break;
      case _AccountMenuOption.collection:
        Navigator.pushNamed(context, '/collection');
        break;
      case _AccountMenuOption.history:
        Navigator.pushNamed(context, '/history');
        break;
      case _AccountMenuOption.logout:
        final shouldLogout = await _confirmLogout(context);
        if (shouldLogout) {
          await context.read<AuthProvider>().logout();
          if (context.mounted) {
            Navigator.pushReplacementNamed(context, '/login');
          }
        }
        break;
    }
  }

  static Future<bool> _confirmLogout(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Text('Confirmar saída'),
              content: const Text('Deseja realmente sair da conta?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.colors.primary,
                  ),
                  child: const Text('Sair'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Image.asset('assets/images/logo.png', height: 40),
      actions: [
        PopupMenuButton<_AccountMenuOption>(
          icon: const Icon(Icons.account_circle),
          offset: const Offset(0, kToolbarHeight - 4),
          onSelected: (option) => _handleSelection(context, option),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: _AccountMenuOption.settings,
              child: Text('Configurações'),
            ),
            const PopupMenuItem(
              value: _AccountMenuOption.collection,
              child: Text('Coleção'),
            ),
            const PopupMenuItem(
              value: _AccountMenuOption.history,
              child: Text('Histórico'),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: _AccountMenuOption.logout,
              child: Row(
                children: [
                  Icon(Icons.logout, color: AppTheme.colors.primary, size: 18),
                  const SizedBox(width: 8),
                  const Text('Sair'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
