import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

enum AppNotificationType { success, info, warning, danger }

class _AppNotificationPalette {
  const _AppNotificationPalette({
    required this.accent,
    required this.icon,
    required this.label,
  });

  final Color accent;
  final IconData icon;
  final String label;

  Color get backgroundStart => accent;
  Color get backgroundEnd => Color.lerp(accent, Colors.white, 0.3)!;
  Color get iconBackground => Color.lerp(accent, Colors.white, 0.55)!;
  Color get border => Color.lerp(accent, Colors.black, 0.15)!;
}

OverlayEntry? _activeNotificationEntry;

void showAppNotification(
  BuildContext context, {
  required String message,
  String? title,
  AppNotificationType type = AppNotificationType.info,
  Duration duration = const Duration(seconds: 4),
}) {
  _activeNotificationEntry?..remove();
  _activeNotificationEntry = null;

  final overlay = Overlay.of(context, rootOverlay: true);

  final palette = _palettes[type]!;
  final resolvedTitle = title ?? palette.label;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _AppNotificationBanner(
      palette: palette,
      title: resolvedTitle,
      message: message,
      duration: duration,
      onDismissed: () {
        if (_activeNotificationEntry == entry) {
          _activeNotificationEntry = null;
        }
        entry.remove();
      },
    ),
  );

  _activeNotificationEntry = entry;
  overlay.insert(entry);
}

class _AppNotificationBanner extends StatefulWidget {
  const _AppNotificationBanner({
    required this.palette,
    required this.title,
    required this.message,
    required this.duration,
    required this.onDismissed,
  });

  final _AppNotificationPalette palette;
  final String title;
  final String message;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_AppNotificationBanner> createState() => _AppNotificationBannerState();
}

class _AppNotificationBannerState extends State<_AppNotificationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _controller.forward();
    _timer = Timer(widget.duration, _startDismiss);
  }

  void _startDismiss() {
    if (!_controller.isDismissed) {
      _controller.reverse().then((_) {
        if (mounted) {
          widget.onDismissed();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final gradient = LinearGradient(
      colors: [
        widget.palette.backgroundStart,
        widget.palette.backgroundEnd,
      ],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );
    return Positioned.fill(
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, mediaQuery.viewPadding.top + 16, 16, 0),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.3),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: _controller,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                ),
              ),
              child: FadeTransition(
                opacity: _controller,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: widget.palette.border),
                      boxShadow: [
                        BoxShadow(
                          color: widget.palette.accent.withOpacity(0.18),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: widget.palette.iconBackground,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(widget.palette.icon, color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title,
                                style: AppTheme.typography.subtitle.copyWith(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.message,
                                style: AppTheme.typography.paragraph.copyWith(
                                  fontSize: 15,
                                  color: Colors.white.withOpacity(0.95),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: _startDismiss,
                          borderRadius: BorderRadius.circular(24),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.close, color: Colors.white, size: 18),
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
      ),
    );
  }
}

final Map<AppNotificationType, _AppNotificationPalette> _palettes = {
  AppNotificationType.success: _AppNotificationPalette(
    accent: const Color(0xFF2FB47C),
    icon: Icons.check_circle_outline,
    label: 'Tudo certo',
  ),
  AppNotificationType.info: _AppNotificationPalette(
    accent: AppTheme.colors.primary,
    icon: Icons.info_outline,
    label: 'Informação',
  ),
  AppNotificationType.warning: _AppNotificationPalette(
    accent: const Color(0xFFE8A000),
    icon: Icons.warning_amber_rounded,
    label: 'Atenção',
  ),
  AppNotificationType.danger: _AppNotificationPalette(
    accent: const Color(0xFFD64545),
    icon: Icons.error_outline,
    label: 'Algo deu errado',
  ),
};
