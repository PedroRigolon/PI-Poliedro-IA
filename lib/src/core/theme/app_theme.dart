import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static final colors = _AppColors();
  static final typography = _AppTypography();
  static final spacing = _AppSpacing();

  static ThemeData get light {
    return ThemeData(
      colorScheme: ColorScheme.light(
        primary: colors.primary,
        secondary: colors.secondary,
        background: colors.background,
      ),
      textTheme: _buildTextTheme(),
      inputDecorationTheme: _buildInputDecorationTheme(),
      elevatedButtonTheme: _buildElevatedButtonTheme(),
    );
  }

  static TextTheme _buildTextTheme() {
    return TextTheme(
      displayLarge: typography.title,
      bodyLarge: typography.paragraph,
      labelLarge: typography.label,
      titleMedium: typography.subtitle,
      bodyMedium: typography.button,
    );
  }

  static InputDecorationTheme _buildInputDecorationTheme() {
    return InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: spacing.medium,
        vertical: spacing.small,
      ),
    );
  }

  static ElevatedButtonThemeData _buildElevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        textStyle: typography.button,
        padding: EdgeInsets.symmetric(
          horizontal: spacing.large,
          vertical: spacing.medium,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _AppColors {
  final primary = const Color(0xFFFF1654);
  final secondary = const Color(0xFF00D1FF);
  final background = const Color(0xFFF5F5F5);
  final white = Colors.white;
}

class _AppTypography {
  final title = GoogleFonts.ubuntu(fontSize: 43, fontWeight: FontWeight.bold);

  final paragraph = GoogleFonts.ubuntu(fontSize: 20);

  final label = GoogleFonts.ubuntu(fontSize: 22);

  final button = GoogleFonts.ubuntu(fontSize: 18, fontWeight: FontWeight.w500);

  final input = GoogleFonts.ubuntu(fontSize: 24);

  final subtitle = GoogleFonts.ubuntu(fontSize: 26);
}

class _AppSpacing {
  final double small = 8;
  final double medium = 16;
  final double large = 24;
  final double extraLarge = 32;

  /// Retorna o padding horizontal para cards de autenticação baseado no tamanho da tela
  double getAuthCardPadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Para telas desktop (maior que 1024px), usa 25% da largura da tela em cada lado
    if (screenWidth > 1024) {
      return screenWidth * 0.25; // 50% da tela será ocupada pelo card
    }

    // Para tablets (entre 768px e 1024px), usa 20% da largura da tela em cada lado
    if (screenWidth > 768) {
      return screenWidth * 0.20; // 60% da tela será ocupada pelo card
    }

    // Para telas mobile (menor que 768px), usa padding fixo de 16px
    return 16.0;
  }
}
