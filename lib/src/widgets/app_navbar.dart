import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/providers/auth_provider.dart';

enum _AccountMenuOption { settings, collection, history, logout }
enum _QuickAction { editor, tutorial, commands }

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
      automaticallyImplyLeading: false,
      backgroundColor: AppTheme.colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            if (ModalRoute.of(context)?.settings.name == '/home') return;
            Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
          },
          child: Image.asset('assets/images/logo.png', height: 40),
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Menu rápido',
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => _showQuickAccessMenu(context),
        ),
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

  Future<void> _showQuickAccessMenu(BuildContext context) async {
    await showDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Stack(
          children: [
            Positioned(
              top: kToolbarHeight + 12,
              right: 12,
              child: Material(
                color: Colors.transparent,
                child: _QuickActionsPanel(
                  onTap: (action) {
                    Navigator.of(dialogContext).pop();
                    _handleQuickAction(context, action);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleQuickAction(BuildContext context, _QuickAction action) {
    switch (action) {
      case _QuickAction.editor:
        if (ModalRoute.of(context)?.settings.name == '/home') return;
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        break;
      case _QuickAction.tutorial:
        _showTutorialDialog(context);
        break;
      case _QuickAction.commands:
        _showCommandsDialog(context);
        break;
    }
  }

  Future<void> _showTutorialDialog(BuildContext context) async {
    const steps = [
      {
        'title': 'Adicionar elementos',
        'description':
            'Escolha uma categoria de formas no painel lateral e arraste qualquer item para o canvas.',
      },
      {
        'title': 'Mover e alinhar',
        'description':
            'Use o mouse para selecionar e o teclado para ajustar: setas movem 1px, Shift + setas movem 10px.',
      },
      {
        'title': 'Gerenciar camadas',
        'description':
            'Abra o painel Camadas para renomear, bloquear ou alternar a visibilidade de cada elemento.',
      },
      {
        'title': 'Salvar e exportar',
        'description':
            'Clique em "Salvar imagem" para gerar o preview, adicionar ao histórico e baixar em PNG/SVG/PDF.',
      },
    ];

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Tutorial rápido'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < steps.length; i++) ...[
                  _TutorialStepTile(
                    index: i + 1,
                    title: steps[i]['title']!,
                    description: steps[i]['description']!,
                  ),
                  if (i != steps.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendi'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCommandsDialog(BuildContext context) async {
    final commands = <_CommandShortcut>[
      _CommandShortcut(
        keys: const ['Delete', 'Backspace'],
        description: 'Remove a seleção atual.',
        icon: Icons.delete_outline,
        color: const Color(0xFFFF7B89),
      ),
      _CommandShortcut(
        keys: const ['Esc'],
        description: 'Limpa qualquer seleção.',
        icon: Icons.layers_clear,
        color: const Color(0xFF9C9DFD),
      ),
      _CommandShortcut(
        keys: const ['Ctrl + D'],
        description: 'Duplica os itens selecionados.',
        icon: Icons.control_point_duplicate,
        color: const Color(0xFF66D2CF),
      ),
      _CommandShortcut(
        keys: const ['Ctrl + C', 'Ctrl + V'],
        description: 'Copia e cola grupos inteiros.',
        icon: Icons.copy_all,
        color: const Color(0xFFFFC36F),
      ),
      _CommandShortcut(
        keys: const ['Ctrl + G'],
        description: 'Agrupa a seleção.',
        icon: Icons.group_work_outlined,
        color: const Color(0xFF8ED081),
      ),
      _CommandShortcut(
        keys: const ['Ctrl + Shift + G'],
        description: 'Desagrupa o conjunto.',
        icon: Icons.group_off,
        color: const Color(0xFF6EC4E8),
      ),
      _CommandShortcut(
        keys: const ['Setas', 'Shift + Setas'],
        description: 'Desloca 1px ou 10px segurando Shift.',
        icon: Icons.open_with,
        color: const Color(0xFFCF94DA),
      ),
      _CommandShortcut(
        keys: const ['Scroll'],
        description: 'Zoom in/out no cursor.',
        icon: Icons.zoom_out_map,
        color: const Color(0xFF6FB2FF),
      ),
      _CommandShortcut(
        keys: const ['Shift + Scroll'],
        description: 'Pan horizontal rápido.',
        icon: Icons.swap_horiz,
        color: const Color(0xFFF4A259),
      ),
      _CommandShortcut(
        keys: const ['Ctrl + Scroll'],
        description: 'Pan vertical preciso.',
        icon: Icons.swap_vert,
        color: const Color(0xFF4DD599),
      ),
      _CommandShortcut(
        keys: const ['Espaço + Arrastar'],
        description: 'Pan livre com o mouse.',
        icon: Icons.pan_tool,
        color: const Color(0xFF7EA8FF),
      ),
      _CommandShortcut(
        keys: const ['Botão do meio'],
        description: 'Clique e arraste para pan contínuo.',
        icon: Icons.mouse,
        color: const Color(0xFFFF8DC7),
      ),
      _CommandShortcut(
        keys: const ['Ctrl + Clique'],
        description: 'Seleciona múltiplos elementos ou grupos.',
        icon: Icons.select_all,
        color: const Color(0xFF00BFA6),
      ),
    ];

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Comandos e atalhos'),
          content: SizedBox(
            width: 520,
            height: 400,
            child: Scrollbar(
              thumbVisibility: true,
              child: ListView.separated(
                itemCount: commands.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, index) => _CommandShortcutTile(
                  entry: commands[index],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }
}

class _QuickActionsPanel extends StatelessWidget {
  const _QuickActionsPanel({required this.onTap});

  final void Function(_QuickAction action) onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QuickActionTile(
            color: AppTheme.colors.primary,
            icon: Icons.edit,
            title: 'Editor',
            subtitle: 'Voltar para a tela de edição.',
            onTap: () => onTap(_QuickAction.editor),
          ),
          const SizedBox(height: 10),
          _QuickActionTile(
            color: const Color(0xFFB0B0B5),
            icon: Icons.play_circle_outline,
            title: 'Tutorial',
            subtitle: 'Veja passo a passo como usar.',
            onTap: () => onTap(_QuickAction.tutorial),
          ),
          const SizedBox(height: 10),
          _QuickActionTile(
            color: const Color(0xFF5B6CFF),
            icon: Icons.keyboard,
            title: 'Comandos',
            subtitle: 'Liste todos os atalhos disponíveis.',
            onTap: () => onTap(_QuickAction.commands),
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.18),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTheme.typography.subtitle.copyWith(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTheme.typography.paragraph.copyWith(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _CommandShortcut {
  const _CommandShortcut({
    required this.keys,
    required this.description,
    required this.icon,
    required this.color,
  });

  final List<String> keys;
  final String description;
  final IconData icon;
  final Color color;
}

class _CommandShortcutTile extends StatelessWidget {
  const _CommandShortcutTile({required this.entry});

  final _CommandShortcut entry;

  @override
  Widget build(BuildContext context) {
    final accent = entry.color;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            accent.withOpacity(0.16),
            accent.withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: accent.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(entry.icon, color: accent, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: entry.keys
                      .map(
                        (key) => _ShortcutKeyChip(
                          label: key.trim(),
                          accent: accent,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 10),
                Text(
                  entry.description,
                  style: AppTheme.typography.paragraph.copyWith(
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutKeyChip extends StatelessWidget {
  const _ShortcutKeyChip({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        label,
        style: AppTheme.typography.subtitle.copyWith(
          fontSize: 13,
          color: accent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TutorialStepTile extends StatelessWidget {
  const _TutorialStepTile({
    required this.index,
    required this.title,
    required this.description,
  });

  final int index;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.colors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$index',
            style: AppTheme.typography.subtitle.copyWith(
              color: AppTheme.colors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTheme.typography.subtitle.copyWith(fontSize: 15.5),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: AppTheme.typography.paragraph.copyWith(fontSize: 13.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
