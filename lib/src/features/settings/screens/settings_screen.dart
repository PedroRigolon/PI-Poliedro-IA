import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/app_navbar.dart';
import '../../../widgets/app_notification.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';

enum _SettingsView { account, password }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  _SettingsView _view = _SettingsView.account;
  bool _showPassword = false;
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppTheme.colors.background,
      appBar: const AppNavbar(),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: AppTheme.spacing.large,
          vertical: AppTheme.spacing.medium,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Conta', style: AppTheme.typography.title),
            const SizedBox(height: 4),
            Text(
              'Veja as informações de sua conta.',
              style: AppTheme.typography.paragraph.copyWith(
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 24),
            _buildSegmentedButtons(),
            const SizedBox(height: 24),
            if (_view == _SettingsView.account)
              _AccountPanel(
                user: auth.user,
                password: auth.password,
                showPassword: _showPassword,
                onTogglePassword: () => setState(() {
                  _showPassword = !_showPassword;
                }),
                onLogout: _handleLogout,
                onDelete: _handleDeleteAccount,
              )
            else
              _PasswordPanel(
                formKey: _formKey,
                currentController: _currentPasswordController,
                newController: _newPasswordController,
                confirmController: _confirmPasswordController,
                onSubmit: _handlePasswordChange,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedButtons() {
    return Wrap(
      spacing: AppTheme.spacing.small,
      children: [
        _SegmentButton(
          label: 'Conta',
          selected: _view == _SettingsView.account,
          onTap: () => setState(() => _view = _SettingsView.account),
        ),
        _SegmentButton(
          label: 'Alterar Senha',
          selected: _view == _SettingsView.password,
          onTap: () => setState(() => _view = _SettingsView.password),
        ),
      ],
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Sair da conta'),
            content: const Text('Deseja realmente sair da sua conta?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.colors.primary,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Sair'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    await context.read<AuthProvider>().logout();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Excluir conta'),
            content: const Text(
              'Tem certeza que deseja excluir sua conta? Esta ação não pode ser desfeita.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Excluir conta'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;
    try {
      await context.read<AuthProvider>().deleteAccount();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      showAppNotification(
        context,
        message: 'Conta excluída com sucesso.',
        type: AppNotificationType.success,
      );
    } catch (e) {
      if (!mounted) return;
      showAppNotification(
        context,
        message: e.toString(),
        type: AppNotificationType.danger,
      );
    }
  }

  Future<void> _handlePasswordChange() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await context.read<AuthProvider>().changePassword(
            _currentPasswordController.text,
            _newPasswordController.text,
          );
      if (!mounted) return;
      showAppNotification(
        context,
        message: 'Senha atualizada com sucesso.',
        type: AppNotificationType.success,
      );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      setState(() => _showPassword = false);
    } catch (e) {
      if (!mounted) return;
      showAppNotification(
        context,
        message: e.toString(),
        type: AppNotificationType.danger,
      );
    }
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: selected ? AppTheme.colors.primary : Colors.white,
        foregroundColor: selected ? Colors.white : AppTheme.colors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AppTheme.colors.primary),
        ),
      ),
      child: Text(label),
    );
  }
}

class _AccountPanel extends StatelessWidget {
  const _AccountPanel({
    required this.user,
    required this.password,
    required this.showPassword,
    required this.onTogglePassword,
    required this.onLogout,
    required this.onDelete,
  });

  final UserModel? user;
  final String? password;
  final bool showPassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onLogout;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final sections = _buildSections(context);

    return Container(
      padding: EdgeInsets.all(AppTheme.spacing.large),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 720) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < sections.length; i++) ...[
                  sections[i],
                  if (i < sections.length - 1)
                    Divider(color: Colors.grey[200], height: 24),
                ],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < sections.length; i++) ...[
                Expanded(child: sections[i]),
                if (i < sections.length - 1)
                  SizedBox(width: AppTheme.spacing.medium),
              ],
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildSections(BuildContext context) {
    return [
      _SectionCard(
        title: 'Informações gerais',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoLine(
              label: 'Perfil',
              value: _labelForUserType(user?.type),
            ),
            _InfoLine(
              label: 'Email',
              value: user?.email ?? '---',
            ),
            const SizedBox(height: 12),
            Text('Senha:', style: AppTheme.typography.paragraph),
            const SizedBox(height: 6),
            _PasswordPreview(
              password: password,
              showPassword: showPassword,
              onTogglePassword: onTogglePassword,
            ),
          ],
        ),
      ),
      _SectionCard(
        title: 'Ações',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: FilledButton(
                  onPressed: onLogout,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.colors.primary,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text('Sair da conta'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: OutlinedButton(
                  onPressed: onDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.colors.primary,
                    side: BorderSide(color: AppTheme.colors.primary),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text('Excluir conta'),
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  String _labelForUserType(UserType? type) {
    switch (type) {
      case UserType.professor:
        return 'Professor';
      case UserType.student:
        return 'Aluno';
      case UserType.admin:
        return 'Administrador';
      default:
        return '---';
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(AppTheme.spacing.medium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTheme.typography.subtitle),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style:
                AppTheme.typography.paragraph.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(value),
        ],
      ),
    );
  }
}

class _PasswordPreview extends StatelessWidget {
  const _PasswordPreview({
    required this.password,
    required this.showPassword,
    required this.onTogglePassword,
  });

  final String? password;
  final bool showPassword;
  final VoidCallback onTogglePassword;

  @override
  Widget build(BuildContext context) {
    final hasPassword = password != null && password!.isNotEmpty;
    final masked = hasPassword
        ? List.filled(password!.length, '•').join()
        : 'Senha não disponível';
    final value = showPassword
        ? (password ?? 'Senha não disponível')
        : masked;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]! ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value,
              style: AppTheme.typography.paragraph.copyWith(
                fontSize: 16,
                letterSpacing: showPassword ? 0 : 1.4,
              ),
            ),
          ),
          IconButton(
            onPressed: hasPassword ? onTogglePassword : null,
            icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
            tooltip: hasPassword
                ? (showPassword ? 'Ocultar senha' : 'Mostrar senha')
                : 'Senha não disponível',
          ),
        ],
      ),
    );
  }
}

class _PasswordPanel extends StatelessWidget {
  const _PasswordPanel({
    required this.formKey,
    required this.currentController,
    required this.newController,
    required this.confirmController,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController currentController;
  final TextEditingController newController;
  final TextEditingController confirmController;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: EdgeInsets.all(AppTheme.spacing.large),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Alterar senha', style: AppTheme.typography.subtitle),
                const SizedBox(height: 16),
                _PasswordField(
                  label: 'Senha atual',
                  controller: currentController,
                ),
                const SizedBox(height: 12),
                _PasswordField(
                  label: 'Nova senha',
                  controller: newController,
                ),
                const SizedBox(height: 12),
                _PasswordField(
                  label: 'Confirmar nova senha',
                  controller: confirmController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Confirme sua nova senha';
                    }
                    if (value != newController.text) {
                      return 'As senhas não coincidem';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: onSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.colors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Salvar nova senha'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.label,
    required this.controller,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: true,
      validator: validator ?? _defaultValidator,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]! ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]! ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.colors.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  String? _defaultValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Preencha este campo';
    }
    if (value.length < 6) {
      return 'A senha deve ter pelo menos 6 caracteres';
    }
    return null;
  }
}
