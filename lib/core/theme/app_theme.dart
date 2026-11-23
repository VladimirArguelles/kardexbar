import 'package:flutter/material.dart';

/// Tema oscuro de alto contraste optimizado para el entorno operativo de barra.
class AppTheme {
  // Paleta de Fondos de Alto Contraste
  static const Color background = Color(0xFF00162B); // Midnight canvas
  static const Color surface = Color(0xFF02283F); // Card and bar panel
  static const Color surfaceVariant = Color(0xFF053450); // Elevated panels
  static const Color surfaceHighlight = Color(0xFF0A4468); // Top brightness
  static const Color borderLight = Color(0xFF0E4A70); // High visibility borders

  // Acentos de Operación y Marca
  static const Color primaryAmber = Color(0xFFFFB703); // Dorado Barra
  static const Color primaryOrange = Color(0xFFFB8500); // Naranja Neón
  static const Color secondaryCyan = Color(0xFF27A0D7); // Cian Brillante
  static const Color successMint = Color(0xFF06D6A0); // Verde Stock Óptimo
  static const Color warningAmber = Color(0xFFFFB703); // Ámbar Stock Mínimo
  static const Color errorCoral = Color(0xFFEF476F); // Rojo Merma / Crítico
  static const Color infoViolet = Color(0xFF8338EC); // Púrpura

  // Textos y Lectura
  static const Color textPrimary = Color(0xFFF8FAFC); // Blanco óptico
  static const Color textSecondary = Color(0xFFBCD3E5); // Azul hielo secundario
  static const Color textMuted = Color(0xFF7E9EB8); // Texto atenuado

  /// ThemeData principal optimizado para tabletas y smartphones en barra
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primaryAmber,
      colorScheme: const ColorScheme.dark(
        primary: primaryAmber,
        onPrimary: Color(0xFF00162B),
        secondary: secondaryCyan,
        onSecondary: Color(0xFF00162B),
        surface: surface,
        onSurface: textPrimary,
        error: errorCoral,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderLight, width: 1.2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderLight, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderLight, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: secondaryCyan, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryAmber,
          foregroundColor: const Color(0xFF00162B),
          elevation: 2,
          minimumSize: const Size(88, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: borderLight, width: 1.5),
          minimumSize: const Size(88, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(color: borderLight, thickness: 1),
    );
  }
}
