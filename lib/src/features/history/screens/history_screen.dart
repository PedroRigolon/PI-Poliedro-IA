import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico'),
        backgroundColor: AppTheme.colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: EdgeInsets.all(AppTheme.spacing.medium),
        child: ListView.separated(
          itemCount: 15,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            return ListTile(
              leading: const Icon(Icons.image_outlined),
              title: Text('Registro ${index + 1}', style: AppTheme.typography.paragraph.copyWith(fontSize: 16)),
              subtitle: const Text('Gerado em: 2025-11-06 (placeholder)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            );
          },
        ),
      ),
    );
  }
}
